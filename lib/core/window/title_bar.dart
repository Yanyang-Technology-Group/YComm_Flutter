// 桌面端系统标题栏跟随应用主题。
//
// 低风险方案：保留窗口结构，只调整系统标题栏的外观。托盘功能在桌面外壳中
// 初始化 waitUntilReadyToShow，以便隐藏窗口时正确移除任务栏按钮。
//
// 平台差异：
//   Windows —— 自己调 DWM（见 caption_color_ffi.dart）。window_manager 在
//     Windows 上会先读注册表，系统是浅色时应用请求什么都不生效，所以不用它。
//   macOS / Linux —— 用 window_manager.setBrightness（改窗口 appearance /
//     GTK 主题变体），只能到明暗两档。
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show Brightness, debugPrint, kIsWeb;
import 'package:flutter/painting.dart' show Color;
import 'package:window_manager/window_manager.dart';

import 'caption_color_unsupported.dart'
    if (dart.library.ffi) 'caption_color_ffi.dart' as caption;

/// 是否是支持调整标题栏的桌面平台。
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// 在 runApp 之前调用一次。
Future<void> initializeDesktopWindow() async {
  if (!_isDesktop) {
    return;
  }
  await windowManager.ensureInitialized();
}

/// 让系统标题栏跟随应用主题。
///
/// [brightness] 决定明暗；[background] / [foreground] 是应用当前的背景色与文字色，
/// Windows 11 上会直接把标题栏染成这个颜色。失败不影响使用，只是标题栏保持系统外观。
Future<void> syncTitleBar(
  Brightness brightness,
  Color background,
  Color foreground,
) async {
  if (!_isDesktop) {
    return;
  }
  try {
    if (Platform.isWindows) {
      caption.setCaptionColors(background, foreground);
    } else {
      await windowManager.setBrightness(brightness);
    }
  } catch (error) {
    debugPrint('设置标题栏外观失败：$error');
  }
}
