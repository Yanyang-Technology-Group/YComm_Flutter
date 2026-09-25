// 桌面端（Windows/macOS/Linux）的外观与后台行为开关。
//
// 托盘默认开启：这是客户端常见的后台驻留方式，关掉窗口时留在托盘里；
// 不想要的人可以在「外观与主题」里一键关闭，关掉后点 X 就是直接退出。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_shell.dart';

class DesktopSettings {
  const DesktopSettings({
    this.tray = true,
    this.notifications = true,
    this.startup = false,
  });

  /// 是否启用系统托盘（关闭窗口时最小化到托盘）。
  final bool tray;

  /// 是否在收到新消息时弹右下角系统通知。
  final bool notifications;

  /// 是否随系统启动。**不存本地缓存**：系统注册项（Windows Run / Linux
  /// autostart / macOS LaunchAgent）才是唯一事实来源，本地再存一份只会两边
  /// 不一致 —— 这里只是启动时读出来给开关用。
  final bool startup;

  DesktopSettings copyWith({bool? tray, bool? notifications, bool? startup}) =>
      DesktopSettings(
        tray: tray ?? this.tray,
        notifications: notifications ?? this.notifications,
        startup: startup ?? this.startup,
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
      // 读系统里的真实状态：用户可能在系统设置里自己关掉了自启动。
      startup: await isLaunchAtLoginEnabled(),
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

  /// 打开 / 关闭开机自启动；返回是否真的写成功。
  /// 失败时保持原状态（开关会弹回去），由调用方给出提示。
  Future<bool> setStartup(bool value) async {
    final ok = await setLaunchAtLogin(value);
    if (!ok) {
      return false;
    }
    state = state.copyWith(startup: value);
    return true;
  }
}

final desktopSettingsProvider =
    NotifierProvider<DesktopSettingsController, DesktopSettings>(
      DesktopSettingsController.new,
    );
