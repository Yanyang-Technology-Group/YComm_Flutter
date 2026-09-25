import 'core/design/apple_app.dart';
import 'core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/design/apple_chrome.dart';
import 'core/design/apple_nav.dart';
import 'core/design/apple_theme.dart';
import 'core/design/design_style.dart';
import 'core/network/api_client.dart';
import 'core/network/community_api.dart';
import 'core/network/realtime_service.dart';
import 'core/state/session.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/window/desktop_settings.dart';
import 'core/window/desktop_shell.dart';
import 'core/window/title_bar.dart';
import 'features/downloads/downloads_page.dart';
import 'features/forum/forum_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/profile/profile_page.dart';
import 'features/shell/desktop_title_bar.dart';
import 'features/update/update_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.initialize();
  // 桌面端：初始化窗口（自绘标题栏）、通知，以及标题栏跟随主题。
  await setupDesktopShell();
  await initializeDesktopWindow();
  runApp(const ProviderScope(child: YCommApp()));
}

class YCommApp extends ConsumerStatefulWidget {
  const YCommApp({super.key});
  @override
  ConsumerState<YCommApp> createState() => _YCommAppState();
}

class _YCommAppState extends ConsumerState<YCommApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(themeControllerProvider.notifier).load();
      ref.read(desktopSettingsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeControllerProvider);
    // 两种风格共用同一套主题色，只是呈现语言不同。
    final apple = theme.style == DesignStyle.apple;
    ThemeData themeFor(Brightness brightness) => apple
        ? buildAppleTheme(theme.colour, brightness)
        : buildTheme(theme.colour, brightness);
    if (apple) {
      final brightness = switch (theme.mode) {
        ThemeModePreference.auto => MediaQuery.platformBrightnessOf(context),
        ThemeModePreference.light => Brightness.light,
        ThemeModePreference.dark => Brightness.dark,
      };
      return AppleApp(
        navigatorKey: _navigatorKey,
        theme: themeFor(brightness),
        builder: (context, child) => isDesktopShell
            ? DesktopWindowFrame(child: child)
            : child ?? const SizedBox.shrink(),
        home: const AppShell(),
      );
    }
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: '晏阳社区',
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      themeMode: switch (theme.mode) {
        ThemeModePreference.auto => ThemeMode.system,
        ThemeModePreference.light => ThemeMode.light,
        ThemeModePreference.dark => ThemeMode.dark,
      },
      theme: themeFor(Brightness.light),
      darkTheme: themeFor(Brightness.dark),
      // 尊重系统「减少动画」：关掉时主题切换不做插值，直接换。
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 250),
      // 在 Navigator 外为标题栏保留独立空间，所有路由都显示在标题栏下方。
      // 外框的 Overlay 为标题栏按钮提供 Tooltip 所需的祖先。
      builder: (context, child) => isDesktopShell
          ? DesktopWindowFrame(child: child)
          : child ?? const SizedBox.shrink(),
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin,
        WindowListener {
  int index = 0, syncGeneration = 0;
  final visited = <int>{0};
  bool active = true;

  /// 上次同步给系统标题栏的外观签名，避免每帧都打平台通道。
  String? titleBarSignature;
  late final AnimationController animation;
  late final RealtimeService realtime;
  static const pages = [
    ForumPage(),
    DownloadsPage(),
    NotificationsPage(),
    ProfilePage(),
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    realtime = RealtimeService(
      onNotificationChanged: () =>
          ref.read(notificationsProvider.notifier).refresh(),
      onSessionInvalid: () => ref.read(sessionProvider.notifier).refresh(),
    );
    ref.listenManual(sessionProvider, (previous, next) {
      if (previous?.value?['id'] != next.value?['id']) sync();
    }, fireImmediately: true);
    if (isDesktopShell) {
      try {
        windowManager.addListener(this);
      } catch (error) {
        // 测试环境没有原生端，注册失败不影响界面。
        debugPrint('注册窗口监听失败：$error');
      }
      // 托盘开关一变就同步后台行为（关窗是隐藏还是退出）。
      ref.listenManual(
        desktopSettingsProvider,
        (_, next) => applyDesktopSettings(next),
        fireImmediately: true,
      );
      // 未读数增加时弹右下角系统通知。不加 fireImmediately：
      // 启动时的存量未读不该立刻弹一堆通知。
      ref.listenManual(notificationsProvider, (previous, next) {
        final before = unreadOf(previous?.value);
        final after = unreadOf(next.value);
        if (after > before) notifyUnread(after);
      });
    }
    // 启动后自动检查一次更新；6 小时内重复启动不会再打接口，
    // 发现新版本且用户没点过「不再提醒」才弹窗。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) autoCheckForUpdates(context, ref);
    });
  }

  Future<void> sync() async {
    final ticket = ++syncGeneration;
    realtime.dispose();
    if (!active || ref.read(sessionProvider).value == null) return;
    final client = ref.read(communityProvider).client;
    final headers = await client.socketHeaders();
    if (!mounted || ticket != syncGeneration || !active) return;
    final uri = Uri.parse(client.dio.options.baseUrl);
    realtime.connect(
      uri.replace(
        scheme: uri.scheme == 'https' ? 'wss' : 'ws',
        path: '${uri.path}/ws',
      ),
      headers: headers,
    );
  }

  /// 未读总数，供系统通知判断「是不是变多了」。
  int unreadOf(List<Json>? groups) => (groups ?? const <Json>[]).fold<int>(
    0,
    (sum, g) => sum + ((g['unreadCount'] as num?)?.toInt() ?? 0),
  );

  /// 设置变化时同步后台行为：托盘开关决定关窗是隐藏还是退出。
  ///
  /// 整段包 try/catch：桌面插件在测试环境（没有原生端）会抛
  /// MissingPluginException，不该影响界面。
  Future<void> applyDesktopSettings(DesktopSettings settings) async {
    if (!isDesktopShell) {
      return;
    }
    try {
      await preventWindowClose(settings.tray);
      if (settings.tray) {
        await enableTray(
          onShowWindow: showMainWindow,
          onCheckUpdate: () => checkForUpdates(context, ref),
          onExit: () async {
            await disableTray();
            await destroyWindow();
          },
        );
      } else {
        await disableTray();
      }
    } catch (error) {
      debugPrint('同步桌面设置失败：$error');
    }
  }

  /// 右下角系统通知。
  Future<void> notifyUnread(int count) async {
    if (!isDesktopShell || !ref.read(desktopSettingsProvider).notifications) {
      return;
    }
    await showDesktopNotification(
      title: '晏阳社区',
      body: '你有 $count 条未读消息',
      onClick: showMainWindow,
    );
  }

  /// 自绘标题栏的关闭按钮走这里：托盘开着就收进托盘，否则直接退出。
  @override
  void onWindowClose() async {
    if (isDesktopShell && ref.read(desktopSettingsProvider).tray) {
      await hideWindow();
    } else {
      await destroyWindow();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      ref.read(sessionProvider.notifier).refresh();
      ref.read(notificationsProvider.notifier).refresh();
      autoCheckForUpdates(context, ref);
    }
    sync();
  }

  @override
  void dispose() {
    syncGeneration++;
    realtime.dispose();
    animation.dispose();
    if (isDesktopShell) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void select(int value) {
    if (index == value) return;
    setState(() {
      index = value;
      visited.add(value);
    });
    if (!MediaQuery.disableAnimationsOf(context)) animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // 桌面端系统标题栏跟随应用主题（Windows 11 上连颜色一起染）。
    // 带值比较，只在明暗或配色真的变化时调用一次平台通道。
    final shellTheme = Theme.of(context);
    final titleBarKey =
        '${shellTheme.brightness.name}:'
        '${shellTheme.colorScheme.surface.toARGB32()}';
    if (titleBarSignature != titleBarKey) {
      titleBarSignature = titleBarKey;
      syncTitleBar(
        shellTheme.brightness,
        shellTheme.colorScheme.surface,
        shellTheme.colorScheme.onSurface,
      );
    }
    final unread = (ref.watch(notificationsProvider).value ?? []).fold<int>(
      0,
      (sum, n) => sum + ((n['unreadCount'] as num?)?.toInt() ?? 0),
    );
    final labels = ['社区', '资源', '消息', '我的'];
    final icons = [
      Icons.forum_outlined,
      Icons.widgets_outlined,
      Icons.notifications_none_rounded,
      Icons.person_outline_rounded,
    ];
    final selectedIcons = [
      Icons.forum_rounded,
      Icons.widgets_rounded,
      Icons.notifications_rounded,
      Icons.person_rounded,
    ];
    Widget icon(int i, bool selected) => AppBadge(
      isLabelVisible: i == 2 && unread > 0,
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: AppIcon(selected ? selectedIcons[i] : icons[i]),
    );
    final stacks = IndexedStack(
      index: index,
      children: List.generate(
        4,
        (i) => visited.contains(i) ? pages[i] : const SizedBox.shrink(),
      ),
    );
    // 高频标签切换即时显示，避免重复导航时内容移动。
    // Material 风格沿用原来的固定时长淡入。
    final apple = appleTokensOf(context) != null;
    final body = apple
        ? stacks
        : FadeTransition(
            opacity: Tween<double>(begin: .5, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: stacks,
          );
    final badgeOf = <int, String?>{
      for (var i = 0; i < labels.length; i++)
        i: i == 2 && unread > 0 ? (unread > 99 ? '99+' : '$unread') : null,
    };
    final appleItems = [
      for (var i = 0; i < labels.length; i++)
        AppleTabItem(
          label: labels[i],
          icon: icons[i],
          selectedIcon: selectedIcons[i],
          badge: badgeOf[i],
        ),
    ];
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) select(0);
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 850;
          final shell = AppScaffold(
            body: wide
                ? Row(
                    children: [
                      if (apple)
                        AppleSidebar(
                          index: index,
                          onSelect: select,
                          items: appleItems,
                        )
                      else ...[
                        NavigationRail(
                          selectedIndex: index,
                          onDestinationSelected: select,
                          labelType: NavigationRailLabelType.all,
                          destinations: List.generate(
                            4,
                            (i) => NavigationRailDestination(
                              icon: icon(i, false),
                              selectedIcon: icon(i, true),
                              label: Text(labels[i]),
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                      ],
                      Expanded(child: body),
                    ],
                  )
                : body,
            bottomNavigationBar:
                wide || MediaQuery.viewInsetsOf(context).bottom > 0
                ? null
                : apple
                // iOS 的标签栏浮在内容之上，安全区由它自己内缩处理。
                ? SafeArea(
                    top: false,
                    child: AppleTabBar(
                      index: index,
                      onSelect: select,
                      items: appleItems,
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: NavigationBar(
                      selectedIndex: index,
                      onDestinationSelected: select,
                      destinations: List.generate(
                        4,
                        (i) => NavigationDestination(
                          icon: icon(i, false),
                          selectedIcon: icon(i, true),
                          label: labels[i],
                        ),
                      ),
                    ),
                  ),
          );
          // 桌面端：系统标题栏已隐藏，自绘标题栏由 MaterialApp.builder 铺在
          // Navigator 之上（见 YCommApp.build），这里只输出 shell 本体。
          return shell;
        },
      ),
    );
  }
}
