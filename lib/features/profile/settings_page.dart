import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/session.dart';
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
    final desktop = ref.watch(desktopSettingsProvider);
    final desktopControl = ref.read(desktopSettingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      appBar: AppNavigationBar(title: const Text('设置')),
      body: SafeArea(
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
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
                        if (await requireSession(context, ref) &&
                            context.mounted) {
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
              // 桌面管理：桌面端才有托盘与系统通知，手机端不显示这一段。
              if (isDesktopShell) ...[
                const SizedBox(height: 26),
                const SectionLabel('桌面管理'),
                SettingsGroup(
                  children: [
                    AppSwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      secondary: AppIcon(
                        Icons.desktop_windows_outlined,
                        color: scheme.primary,
                      ),
                      title: const Text('系统托盘'),
                      subtitle: const Text('关闭窗口时收进托盘；右键托盘图标可退出'),
                      value: desktop.tray,
                      onChanged: desktopControl.setTray,
                    ),
                    AppSwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      secondary: AppIcon(
                        Icons.notifications_active_outlined,
                        color: scheme.primary,
                      ),
                      title: const Text('右下角系统通知'),
                      subtitle: const Text('收到新消息时在屏幕右下角弹出提示'),
                      value: desktop.notifications,
                      onChanged: desktopControl.setNotifications,
                    ),
                    AppSwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      secondary: AppIcon(
                        Icons.power_settings_new_outlined,
                        color: scheme.primary,
                      ),
                      title: const Text('开机自启动'),
                      subtitle: const Text('登录系统后自动启动客户端'),
                      value: desktop.startup,
                      onChanged: (value) async {
                        final ok = await desktopControl.setStartup(value);
                        if (!ok && context.mounted) {
                          appNotice(context, '设置开机自启动失败，可能被系统策略拦下了');
                        }
                      },
                    ),
                  ],
                ),
              ],
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
            ],
          ),
        ),
      ),
    );
  }
}
