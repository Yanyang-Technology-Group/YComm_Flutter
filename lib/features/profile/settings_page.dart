import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/session.dart';
import '../../core/network/community_api.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/design.dart';
import '../../core/window/desktop_settings.dart';
import '../../core/window/desktop_shell.dart';
import '../api/api_explorer_page.dart';
import '../auth/auth_gate.dart';
import '../settings/status_monitor_page.dart';
import 'about_page.dart';
import 'account_security_page.dart';
import 'appearance_page.dart';
import 'profile_page.dart';

/// 设置页：外观、桌面管理（桌面端）、开发者工具与关于。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    final user = ref.watch(sessionProvider).value;
    final children = <Widget>[
      const SizedBox(height: 8),
      if (user != null) ...[
        const SectionLabel('账号'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.security_outlined,
              title: '账号安全',
              subtitle: '登录设备管理',
              onTap: () async {
                if (await requireSession(context, ref) && context.mounted) {
                  openPage(context, const AccountSecurityPage());
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 26),
      ],
      const SectionLabel('外观'),
      SettingsGroup(
        children: [
          SettingsRow(
            icon: Icons.palette_outlined,
            title: '外观与主题',
            subtitle:
                '${theme.colour.label} · ${switch (theme.mode.id) {
                  'dark' => '深色模式',
                  'light' => '浅色模式',
                  _ => '跟随系统',
                }}',
            onTap: () => openPage(context, const AppearancePage()),
          ),
        ],
      ),
      const SizedBox(height: 26),
      const SectionLabel('通用'),
      SettingsGroup(
        children: [
          SettingsRow(
            icon: Icons.notifications_outlined,
            title: '通知',
            subtitle: '浏览、评论、点赞、分享和官方消息',
            onTap: () => openPage(context, const NotificationSettingsPage()),
          ),
          SettingsRow(
            icon: Icons.settings_outlined,
            title: '系统设置',
            subtitle: isDesktopShell ? '默认图标、系统托盘、通知与开机自启动' : '默认图标',
            onTap: () => openPage(context, const SystemSettingsPage()),
          ),
        ],
      ),
      const SizedBox(height: 26),
      const SectionLabel('开发者工具'),
      SettingsGroup(
        children: [
          SettingsRow(
            icon: Icons.api_outlined,
            title: 'API 浏览器',
            subtitle: '搜索 API 接口、查看参数并在线运行',
            onTap: () => openPage(context, const ApiExplorerPage()),
          ),
          SettingsRow(
            icon: Icons.monitor_heart_outlined,
            title: '状态监测',
            subtitle: '检测服务器连通性、API 与 WebSocket 可用性',
            onTap: () => openPage(context, const StatusMonitorPage()),
          ),
        ],
      ),
      const SizedBox(height: 26),
      const SectionLabel('关于'),
      SettingsGroup(
        children: [
          SettingsRow(
            icon: Icons.info_outline_rounded,
            title: '关于晏阳社区',
            onTap: () => openPage(context, const AboutPage()),
          ),
        ],
      ),
    ];
    if (isApple(context)) {
      final page = AppleScrollPage(
        title: '设置',
        grouped: true,
        slivers: [
          SliverList.list(children: children),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      );
      return AppScaffold(body: page);
    }
    return AppScaffold(
      appBar: AppNavigationBar(title: const Text('设置')),
      body: SafeArea(
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: children,
          ),
        ),
      ),
    );
  }
}

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});
  @override
  ConsumerState<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  static const _labels = <String, String>{
    'views': '浏览通知',
    'comments': '评论通知',
    'likes': '点赞通知',
    'shares': '分享通知',
    'official': '官方通知',
  };
  final values = <String, bool>{for (final key in _labels.keys) key: true};
  final busy = <String>{};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await ref.read(communityProvider).get('/users/me/notification-preferences');
      final preferences = data['preferences'];
      if (mounted && preferences is Map) {
        setState(() {
          for (final key in _labels.keys) {
            values[key] = preferences[key] != false;
          }
        });
      }
    } catch (error) {
      if (mounted) notice(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> update(String key, bool value) async {
    if (busy.contains(key)) return;
    final previous = values[key] ?? true;
    setState(() { values[key] = value; busy.add(key); });
    try {
      await ref.read(communityProvider).patch('/users/me/notification-preferences', {key: value});
    } catch (error) {
      if (mounted) {
        setState(() => values[key] = previous);
        notice(context, error);
      }
    } finally {
      if (mounted) setState(() => busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: const AppNavigationBar(title: Text('通知')),
    body: SafeArea(
      child: PageWidth(child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        const SizedBox(height: 8),
        SettingsGroup(children: _labels.entries.map((entry) => AppSwitchListTile(
          title: Text(entry.value),
          value: values[entry.key] ?? true,
          onChanged: loading || busy.contains(entry.key) ? null : (value) => update(entry.key, value),
        )).toList()),
      ])),
    ),
  );
}

class SystemSettingsPage extends ConsumerWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(desktopSettingsProvider);
    final control = ref.read(desktopSettingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      appBar: const AppNavigationBar(title: Text('系统设置')),
      body: SafeArea(
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 8),
              const SectionLabel('默认图标'),
              SettingsGroup(
                children: DesktopIcon.values.map((icon) => AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: Image.asset(desktopIconAsset(icon), width: 24, height: 24),
                  title: Text(icon == DesktopIcon.newIcon ? '默认' : '经典'),
                  subtitle: Text(icon == DesktopIcon.newIcon ? '圆蓝白图标' : '原来的应用图标'),
                  trailing: settings.icon == icon ? AppIcon(Icons.check_rounded, color: scheme.primary) : null,
                  onTap: () => control.setIcon(icon),
                )).toList(),
              ),
              if (isDesktopShell) ...[
                const SizedBox(height: 26),
                const SectionLabel('系统行为'),
                SettingsGroup(children: [
                  AppSwitchListTile(title: const Text('系统托盘'), subtitle: const Text('关闭窗口时收进托盘；右键托盘图标可退出'), value: settings.tray, onChanged: control.setTray),
                  AppSwitchListTile(title: const Text('右下角系统通知'), subtitle: const Text('收到新消息时在屏幕右下角弹出提示'), value: settings.notifications, onChanged: control.setNotifications),
                  AppSwitchListTile(title: const Text('开机自启动'), subtitle: const Text('登录系统后自动启动客户端'), value: settings.startup, onChanged: (value) async {
                    if (!await control.setStartup(value) && context.mounted) appNotice(context, '设置开机自启动失败，可能被系统策略拦下了');
                  }),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
