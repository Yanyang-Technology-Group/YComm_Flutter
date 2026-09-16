import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/network/community_api.dart';
import 'core/network/realtime_service.dart';
import 'core/state/session.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/downloads/downloads_page.dart';
import 'features/forum/forum_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/profile/profile_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.initialize();
  runApp(const ProviderScope(child: YCommApp()));
}

class YCommApp extends ConsumerStatefulWidget {
  const YCommApp({super.key});
  @override
  ConsumerState<YCommApp> createState() => _YCommAppState();
}

class _YCommAppState extends ConsumerState<YCommApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(themeControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeControllerProvider);
    return MaterialApp(
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
      theme: buildTheme(theme.colour, Brightness.light),
      darkTheme: buildTheme(theme.colour, Brightness.dark),
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 250),
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int index = 0, syncGeneration = 0;
  final visited = <int>{0};
  bool active = true;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      ref.read(sessionProvider.notifier).refresh();
      ref.read(notificationsProvider.notifier).refresh();
    }
    sync();
  }

  @override
  void dispose() {
    syncGeneration++;
    realtime.dispose();
    animation.dispose();
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
    Widget icon(int i, bool selected) => Badge(
      isLabelVisible: i == 2 && unread > 0,
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: Icon(selected ? selectedIcons[i] : icons[i]),
    );
    final body = FadeTransition(
      opacity: Tween<double>(
        begin: .5,
        end: 1,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: IndexedStack(
        index: index,
        children: List.generate(
          4,
          (i) => visited.contains(i) ? pages[i] : const SizedBox.shrink(),
        ),
      ),
    );
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) select(0);
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 850;
          return Scaffold(
            body: wide
                ? Row(
                    children: [
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
                      Expanded(child: body),
                    ],
                  )
                : body,
            bottomNavigationBar: wide
                ? null
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
        },
      ),
    );
  }
}
