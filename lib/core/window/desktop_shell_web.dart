// Web 上没有托盘、系统通知和自绘标题栏，这里给出同名空实现。
//
// 为什么要单独一份：tray_manager 底层的 nativeapi 用了 dart:ffi，Web 编译不过，
// 所以 desktop_shell.dart 用条件导出把实现挡在 Web 之外（见该文件）。
import 'package:flutter/foundation.dart' show VoidCallback;

/// Web 永远不是桌面外壳。
bool get isDesktopShell => false;

/// 与桌面实现保持同名，Web 上不会被用到。
const double desktopTitleBarHeight = 38;

Future<void> setupDesktopShell() async {}
Future<void> startWindowDrag() async {}
Future<void> minimizeWindow() async {}
Future<void> toggleMaximizeWindow() async {}
Future<bool> isWindowMaximized() async => false;
Future<void> destroyWindow() async {}
Future<void> closeWindow() async {}
Future<void> hideWindow() async {}
Future<void> showMainWindow() async {}
Future<void> preventWindowClose(bool prevent) async {}

Future<void> enableTray({
  required VoidCallback onShowWindow,
  required VoidCallback onCheckUpdate,
  required VoidCallback onExit,
}) async {}

Future<void> disableTray() async {}

Future<void> showDesktopNotification({
  required String title,
  required String body,
  VoidCallback? onClick,
}) async {}
