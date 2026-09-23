// 桌面端（Windows/macOS/Linux）的外观与后台行为开关。
//
// 托盘默认开启：这是客户端常见的后台驻留方式，关掉窗口时留在托盘里；
// 不想要的人可以在「外观与主题」里一键关闭，关掉后点 X 就是直接退出。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DesktopSettings {
  const DesktopSettings({this.tray = true, this.notifications = true});

  /// 是否启用系统托盘（关闭窗口时最小化到托盘）。
  final bool tray;

  /// 是否在收到新消息时弹右下角系统通知。
  final bool notifications;

  DesktopSettings copyWith({bool? tray, bool? notifications}) =>
      DesktopSettings(
        tray: tray ?? this.tray,
        notifications: notifications ?? this.notifications,
      );
}

class DesktopSettingsController extends Notifier<DesktopSettings> {
  static const trayKey = 'ycomm_desktop_tray';
  static const notificationsKey = 'ycomm_desktop_notifications';

  @override
  DesktopSettings build() => const DesktopSettings();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = DesktopSettings(
      tray: prefs.getBool(trayKey) ?? true,
      notifications: prefs.getBool(notificationsKey) ?? true,
    );
  }

  Future<void> setTray(bool value) async {
    state = state.copyWith(tray: value);
    await (await SharedPreferences.getInstance()).setBool(trayKey, value);
  }

  Future<void> setNotifications(bool value) async {
    state = state.copyWith(notifications: value);
    await (await SharedPreferences.getInstance()).setBool(
      notificationsKey,
      value,
    );
  }
}

final desktopSettingsProvider =
    NotifierProvider<DesktopSettingsController, DesktopSettings>(
      DesktopSettingsController.new,
    );
