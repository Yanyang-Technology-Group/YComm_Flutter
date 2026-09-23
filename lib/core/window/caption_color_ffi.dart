// Windows 标题栏按主题上色：直接调 DWM，不经过 window_manager。
//
// 为什么不用 window_manager.setBrightness：它在 Windows 上先读注册表
//   HKLM\...\Themes\Personalize\AppsUseLightTheme
// 只有「系统本身是深色」时才把标题栏变暗（见其 window_manager.cpp 里的
//   BOOL enable_dark_mode = light_mode == 0 && brightness == "dark";）
// 所以系统浅色时应用怎么请求都没用；而且它只能明暗两档，不能按主题上色。
//
// 这里直接调 DwmSetWindowAttribute：
//   DWMWA_USE_IMMERSIVE_DARK_MODE 20（Win10 20H1+）/ 19（1809~1909）：明暗
//   DWMWA_CAPTION_COLOR 35、DWMWA_TEXT_COLOR 36：任意颜色，Windows 11 起支持
// Win10 上 35/36 会失败并保持原样，明暗那档仍然生效。
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/painting.dart' show Color;

typedef _DwmSetWindowAttributeNative = Int32 Function(
  IntPtr hwnd,
  Uint32 attribute,
  Pointer<Void> value,
  Uint32 size,
);
typedef _DwmSetWindowAttributeDart = int Function(
  int hwnd,
  int attribute,
  Pointer<Void> value,
  int size,
);

typedef _FindWindowNative = IntPtr Function(
  Pointer<Utf16> className,
  Pointer<Utf16> windowName,
);
typedef _FindWindowDart = int Function(
  Pointer<Utf16> className,
  Pointer<Utf16> windowName,
);

const int _darkModeAttribute = 20;
const int _darkModeAttributeLegacy = 19;
const int _captionColorAttribute = 35;
const int _textColorAttribute = 36;

/// Flutter Windows runner 的窗口类名，见 windows/runner/win32_window.cpp。
const String _windowClassName = 'FLUTTER_RUNNER_WIN32_WINDOW';

_DwmSetWindowAttributeDart? _setAttribute;
_FindWindowDart? _findWindow;
int? _handle;

bool _bind() {
  if (_setAttribute != null && _findWindow != null) {
    return true;
  }
  try {
    _setAttribute = DynamicLibrary.open('dwmapi.dll')
        .lookupFunction<_DwmSetWindowAttributeNative, _DwmSetWindowAttributeDart>(
          'DwmSetWindowAttribute',
        );
    _findWindow = DynamicLibrary.open('user32.dll')
        .lookupFunction<_FindWindowNative, _FindWindowDart>('FindWindowW');
    return true;
  } catch (_) {
    // 非 Windows 或缺少库时静默降级。
    return false;
  }
}

int? _windowHandle() {
  final cached = _handle;
  if (cached != null && cached != 0) {
    return cached;
  }
  final className = _windowClassName.toNativeUtf16();
  try {
    final handle = _findWindow!(className, nullptr);
    if (handle == 0) {
      return null;
    }
    _handle = handle;
    return handle;
  } finally {
    malloc.free(className);
  }
}

/// DWM 要的是 COLORREF：0x00BBGGRR。
int _colorRef(Color c) =>
    (((c.b * 255).round() & 0xff) << 16) |
    (((c.g * 255).round() & 0xff) << 8) |
    ((c.r * 255).round() & 0xff);

/// 把窗口标题栏设成给定底色与文字色。
void setCaptionColors(Color background, Color foreground) {
  if (!_bind()) {
    return;
  }
  final hwnd = _windowHandle();
  if (hwnd == null) {
    return;
  }

  final isDark =
      (0.2126 * background.r + 0.7152 * background.g + 0.0722 * background.b) <
      0.5;

  final flag = calloc<Int32>();
  final color = calloc<Uint32>();
  try {
    flag.value = isDark ? 1 : 0;
    // 新属性号失败就退回 1809 用的 19。
    if (_setAttribute!(
          hwnd,
          _darkModeAttribute,
          flag.cast<Void>(),
          sizeOf<Int32>(),
        ) !=
        0) {
      _setAttribute!(
        hwnd,
        _darkModeAttributeLegacy,
        flag.cast<Void>(),
        sizeOf<Int32>(),
      );
    }

    color.value = _colorRef(background);
    _setAttribute!(
      hwnd,
      _captionColorAttribute,
      color.cast<Void>(),
      sizeOf<Uint32>(),
    );
    color.value = _colorRef(foreground);
    _setAttribute!(
      hwnd,
      _textColorAttribute,
      color.cast<Void>(),
      sizeOf<Uint32>(),
    );
  } finally {
    calloc.free(flag);
    calloc.free(color);
  }
}
