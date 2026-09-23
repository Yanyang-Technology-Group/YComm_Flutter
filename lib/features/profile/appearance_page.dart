import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/design.dart';
import '../../core/window/desktop_settings.dart';
import '../../core/window/desktop_shell.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(themeControllerProvider);
    final desktop = ref.watch(desktopSettingsProvider);
    final control = ref.read(themeControllerProvider.notifier);
    final desktopControl = ref.read(desktopSettingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    Widget section(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('外观与主题')),
      body: SafeArea(
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              section('主题色'),
              ...ThemeColour.values.map(
                (colour) => Semantics(
                  selected: state.colour == colour,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: colour.seed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(colour.label),
                    trailing: state.colour == colour
                        ? Icon(Icons.check_rounded, color: scheme.primary)
                        : null,
                    onTap: () => control.setColour(colour),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Divider(),
              ),
              section('显示模式'),
              ...ThemeModePreference.values.map(
                (mode) => Semantics(
                  selected: state.mode == mode,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: Icon(switch (mode) {
                      ThemeModePreference.auto =>
                        Icons.brightness_auto_outlined,
                      ThemeModePreference.light => Icons.light_mode_outlined,
                      ThemeModePreference.dark => Icons.dark_mode_outlined,
                    }, color: scheme.primary),
                    title: Text(switch (mode) {
                      ThemeModePreference.auto => '跟随系统',
                      ThemeModePreference.light => '浅色模式',
                      ThemeModePreference.dark => '深色模式',
                    }),
                    trailing: state.mode == mode
                        ? Icon(Icons.check_rounded, color: scheme.primary)
                        : null,
                    onTap: () => control.setMode(mode),
                  ),
                ),
              ),
              // 桌面端才有托盘与系统通知，手机端不显示这一段。
              if (isDesktopShell) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Divider(),
                ),
                section('桌面'),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    Icons.desktop_windows_outlined,
                    color: scheme.primary,
                  ),
                  title: const Text('系统托盘'),
                  subtitle: const Text('关闭窗口时收进托盘；右键托盘图标可退出'),
                  value: desktop.tray,
                  onChanged: desktopControl.setTray,
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    Icons.notifications_active_outlined,
                    color: scheme.primary,
                  ),
                  title: const Text('右下角系统通知'),
                  subtitle: const Text('收到新消息时在屏幕右下角弹出提示'),
                  value: desktop.notifications,
                  onChanged: desktopControl.setNotifications,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
