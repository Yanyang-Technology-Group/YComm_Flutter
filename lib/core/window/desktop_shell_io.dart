// 桌面端外壳：自绘标题栏所需的窗口设置、系统托盘、右下角系统通知。
//
// 自绘标题栏的前提（已核对 window_manager 的 Windows 实现）：它的
// setTitleBarStyle(hidden) 只是 DwmExtendFrameIntoClientArea(0,0,0,0) 加
// SWP_FRAMECHANGED，**不动 WS_THICKFRAME**，所以隐藏系统标题栏之后窗口边缘
// 仍然可以拉伸缩放；拖动、最小化、最大化、关闭改由 Flutter 侧调用
// startDragging / minimize / maximize / close。
import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show VoidCallback, debugPrint, kIsWeb;
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// 是否是支持托盘与自绘标题栏的桌面平台。
bool get isDesktopShell =>
    !kIsWeb &&
    // widget test 也跑在桌面系统上（CI 的 Linux、开发机的 Windows），但那时既没有
    // 原生端，多出来的自绘标题栏还会把布局用例顶掉，所以测试环境一律当作非桌面。
    !Platform.environment.containsKey('FLUTTER_TEST') &&
    (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// 自绘标题栏的高度，也是可拖动区域的高度。
const double desktopTitleBarHeight = 38;

TrayIcon? _trayIcon;
Menu? _trayMenu;

/// 启动时调用一次：初始化窗口与通知。
Future<void> setupDesktopShell() async {
  if (!isDesktopShell) {
    return;
  }
  try {
    await windowManager.ensureInitialized();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    // 自绘之后如果没有最小尺寸，窗口可以被拖到几乎没有，页面上就没法操作了。
    await windowManager.setMinimumSize(const Size(720, 520));
    await localNotifier.setup(appName: '晏阳社区');
  } catch (error) {
    debugPrint('初始化桌面外壳失败：$error');
  }
}

// ---- 窗口操作（自绘标题栏的按钮用）----

Future<void> startWindowDrag() async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.startDragging();
}

Future<void> minimizeWindow() async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.minimize();
}

/// 最大化 / 还原。
Future<void> toggleMaximizeWindow() async {
  if (!isDesktopShell) {
    return;
  }
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

Future<bool> isWindowMaximized() async =>
    isDesktopShell && await windowManager.isMaximized();

/// 真正退出（不经过「最小化到托盘」）。
Future<void> destroyWindow() async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.destroy();
}

/// 请求关闭窗口。托盘开启时会被 onWindowClose 拦成「隐藏到托盘」。
Future<void> closeWindow() async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.close();
}

/// 隐藏窗口（最小化到托盘）。
Future<void> hideWindow() async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.hide();
}

Future<void> showMainWindow() async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.show();
  await windowManager.focus();
}

/// 让关闭按钮由 Flutter 处理（托盘开启时改成隐藏窗口）。
Future<void> preventWindowClose(bool prevent) async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.setPreventClose(prevent);
}

// ---- 系统托盘 ----

/// 打开托盘。
Future<void> enableTray({
  required VoidCallback onShowWindow,
  required VoidCallback onCheckUpdate,
  required VoidCallback onExit,
}) async {
  if (!isDesktopShell || _trayIcon != null) {
    return;
  }
  try {
    final tray = TrayIcon.create();
    if (tray == null) {
      return;
    }
    tray.icon = ImageAsset.fromAsset('assets/app_icon.png');
    tray.setTooltip('晏阳社区');

    final menu = Menu.create();
    if (menu == null) {
      return;
    }
    void addItem(String label, VoidCallback action, {bool first = false}) {
      if (!first) {
        menu.addSeparator();
      }
      final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal);
      item?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          action();
        }
      });
      menu.addItem(item);
    }

    // 分隔线只加在项之间，第一项前面不加。
    final show = MenuItem.createWithLabelAndType('显示主窗口', MenuItemType.normal);
    show?.addListener((event) {
      if (event is MenuItemClickedEvent) {
        onShowWindow();
      }
    });
    menu.addItem(show);
    addItem('检查更新', onCheckUpdate);
    addItem('退出', onExit);

    tray.setContextMenu(menu);
    // 左键单击托盘图标也回到窗口：Windows 上单击上报 down/up。
    tray.addListener((event) {
      if (event is TrayIconClickedEvent ||
          event is TrayIconDoubleClickedEvent) {
        onShowWindow();
      }
    });
    tray.setVisible(true);

    _trayIcon = tray;
    _trayMenu = menu;
  } catch (error) {
    debugPrint('启用系统托盘失败：$error');
  }
}

/// 关掉托盘。
Future<void> disableTray() async {
  try {
    _trayIcon?.setVisible(false);
    _trayIcon?.dispose();
  } catch (error) {
    debugPrint('关闭系统托盘失败：$error');
  }
  _trayIcon = null;
  _trayMenu?.dispose();
  _trayMenu = null;
}

// ---- 右下角系统通知 ----

/// 弹一条系统通知。点通知会回到窗口。
Future<void> showDesktopNotification({
  required String title,
  required String body,
  VoidCallback? onClick,
}) async {
  if (!isDesktopShell) {
    return;
  }
  try {
    final notification = LocalNotification(title: title, body: body);
    notification.onClick = () => onClick?.call();
    await notification.show();
  } catch (error) {
    debugPrint('弹出系统通知失败：$error');
  }
}
