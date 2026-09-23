// 桌面端系统标题栏的明暗跟随应用主题。
//
// 低风险方案：不动窗口结构（不加 titleBarStyle、不用 waitUntilReadyToShow，
// 自绘标题栏一旦拖动/按钮有问题，用户会既不能移动也不能关窗），只把系统标题栏
// 的明暗改成和应用一致 —— Windows 走 DWM 沉浸式深色标题栏，macOS 走窗口 appearance。
//
// 这样深色主题配浅色标题栏的割裂感就没有了，窗口的拖动、缩放、关闭仍由系统负责。
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show Brightness, debugPrint, kIsWeb;
import 'package:window_manager/window_manager.dart';

/// 是否是支持设置标题栏明暗的桌面平台。
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// 在 runApp 之前调用一次。
Future<void> initializeDesktopWindow() async {
  if (!_isDesktop) {
    return;
  }
  await windowManager.ensureInitialized();
}

/// 让系统标题栏跟随应用当前的明暗。失败不影响使用，只是标题栏保持系统外观。
Future<void> syncTitleBarBrightness(Brightness brightness) async {
  if (!_isDesktop) {
    return;
  }
  try {
    await windowManager.setBrightness(brightness);
  } catch (error) {
    debugPrint('设置标题栏明暗失败：$error');
  }
}
