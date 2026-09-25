import 'profile_page.dart' show SettingsGroup;
import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design_style.dart';
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
    Widget group(Iterable<Widget> children) => isApple(context)
        ? SettingsGroup(children: children.toList())
        : Column(children: children.toList());
    Widget section(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Text(
        text,
        style: isApple(context)
            ? Theme.of(context).textTheme.bodySmall
            : Theme.of(context).textTheme.titleMedium,
      ),
    );
    return AppScaffold(
      appBar: AppNavigationBar(title: const Text('外观与主题')),
      body: SafeArea(
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // 界面风格放在最前：它决定的是整套排版与动效语言，比换主题色更重。
              section('界面风格'),
              group(
                DesignStyle.values.map(
                  (style) => Semantics(
                    selected: state.style == style,
                    child: AppListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      leading: AppIcon(
                        style == DesignStyle.apple
                            ? Icons.apple
                            : Icons.android_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(style.label),
                      subtitle: Text(
                        style == DesignStyle.apple
                            ? '原生控件、清晰排版与轻盈反馈'
                            : '沿用当前 Material 3 界面',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: state.style == style
                          ? AppIcon(Icons.check_rounded, color: scheme.primary)
                          : null,
                      onTap: () => control.setStyle(style),
                    ),
                  ),
                ),
              ),
              if (!isApple(context))
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: AppDivider(),
                ),
              section('主题色'),
              group(
                ThemeColour.values.map(
                  (colour) => Semantics(
                    selected: state.colour == colour,
                    child: AppListTile(
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
                          ? AppIcon(Icons.check_rounded, color: scheme.primary)
                          : null,
                      onTap: () => control.setColour(colour),
                    ),
                  ),
                ),
              ),
              if (!isApple(context))
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: AppDivider(),
                ),
              section('显示模式'),
              group(
                ThemeModePreference.values.map(
                  (mode) => Semantics(
                    selected: state.mode == mode,
                    child: AppListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      leading: AppIcon(switch (mode) {
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
                          ? AppIcon(Icons.check_rounded, color: scheme.primary)
                          : null,
                      onTap: () => control.setMode(mode),
                    ),
                  ),
                ),
              ),
              // 桌面端才有托盘与系统通知，手机端不显示这一段。
              if (isDesktopShell) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: AppDivider(),
                ),
                section('桌面'),
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
