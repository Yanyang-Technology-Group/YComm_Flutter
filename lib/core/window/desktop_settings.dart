// 桌面端（Windows/macOS/Linux）的外观与后台行为开关。
//
// 托盘默认开启：这是客户端常见的后台驻留方式，关掉窗口时留在托盘里；
// 不想要的人可以在「通用 → 系统设置」里一键关闭，关掉后点 X 就是直接退出。
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_shell.dart';

class DesktopSettings {
  const DesktopSettings({
    this.tray = true,
    this.notifications = true,
    this.startup = false,
    this.icon = DesktopIcon.newIcon,
    this.gpu = true,
    this.opacity = 1,
  });

  /// 是否启用系统托盘（关闭窗口时最小化到托盘）。
  final bool tray;

  /// 是否在收到新消息时弹右下角系统通知。
  final bool notifications;

  /// 是否随系统启动。**不存本地缓存**：系统注册项（Windows Run / Linux
  /// autostart / macOS LaunchAgent）才是唯一事实来源，本地再存一份只会两边
  /// 不一致 —— 这里只是启动时读出来给开关用。
  final bool startup;

  final DesktopIcon icon;

  /// 是否用 GPU（硬件渲染）。默认开启；机器/驱动不支持时会被强制关掉。
  final bool gpu;

  /// 窗口整体透明度（0.1–1.0），默认完全不透明。
  final double opacity;

  DesktopSettings copyWith({
    bool? tray,
    bool? notifications,
    bool? startup,
    DesktopIcon? icon,
    bool? gpu,
    double? opacity,
  }) =>
      DesktopSettings(
        tray: tray ?? this.tray,
        notifications: notifications ?? this.notifications,
        startup: startup ?? this.startup,
        icon: icon ?? this.icon,
        gpu: gpu ?? this.gpu,
        opacity: opacity ?? this.opacity,
      );
}

enum DesktopIcon { newIcon, classic }

String desktopIconAsset(DesktopIcon icon) => switch (icon) {
  DesktopIcon.newIcon => 'assets/app_icon.png',
  DesktopIcon.classic => 'assets/app_icon_classic.png',
};

class DesktopSettingsController extends Notifier<DesktopSettings> {
  static const trayKey = 'ycomm_desktop_tray';
  static const notificationsKey = 'ycomm_desktop_notifications';
  static const iconKey = 'ycomm_desktop_icon';
  static const gpuKey = 'ycomm_desktop_gpu';
  static const opacityKey = 'ycomm_desktop_opacity';

  @override
  DesktopSettings build() => const DesktopSettings();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = DesktopSettings(
      tray: prefs.getBool(trayKey) ?? true,
      notifications: prefs.getBool(notificationsKey) ?? true,
      // 读系统里的真实状态：用户可能在系统设置里自己关掉了自启动。
      startup: await isLaunchAtLoginEnabled(),
      icon: prefs.getString(iconKey) == 'classic'
          ? DesktopIcon.classic
          : DesktopIcon.newIcon,
      // 机器/驱动不支持 GPU 加速时，存过的开关也要按关闭处理。
      gpu: (prefs.getBool(gpuKey) ?? true) && gpuAccelerationSupported(),
      opacity: (prefs.getDouble(opacityKey) ?? 1).clamp(0.1, 1.0),
    );
    try {
      await setDesktopWindowIcon(desktopIconAsset(state.icon));
    } catch (error) {
      debugPrint('初始化应用图标失败：$error');
    }
    try {
      await setWindowOpacity(state.opacity);
    } catch (error) {
      debugPrint('初始化窗口透明度失败：$error');
    }
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

  Future<void> setIcon(DesktopIcon value) async {
    // 切图标失败不能挡住「记住选择」本身：先落状态与偏好，再尽力切原生图标，
    // 否则某个平台切不动时，用户点「经典」会像什么都没发生。
    state = state.copyWith(icon: value);
    try {
      await setDesktopWindowIcon(desktopIconAsset(value));
    } catch (error) {
      debugPrint('切换应用图标失败：$error');
    }
    await (await SharedPreferences.getInstance()).setString(
      iconKey,
      value == DesktopIcon.classic ? 'classic' : 'new',
    );
  }

  /// 打开 / 关闭 GPU 加速（需要重启客户端才生效，见 alignGpuAccelerationOnLaunch）。
  Future<void> setGpu(bool value) async {
    state = state.copyWith(gpu: value);
    await (await SharedPreferences.getInstance()).setBool(gpuKey, value);
  }

  /// 调整窗口透明度；拖动过程中就实时生效，同时记住选择。
  Future<void> setOpacity(double value) async {
    final opacity = value.clamp(0.1, 1.0);
    state = state.copyWith(opacity: opacity);
    try {
      await setWindowOpacity(opacity);
    } catch (error) {
      debugPrint('设置窗口透明度失败：$error');
    }
    await (await SharedPreferences.getInstance()).setDouble(
      opacityKey,
      opacity,
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
