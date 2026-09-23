// 桌面端外壳的统一入口。
//
// 这里只做条件导出：Web 用空实现，其余平台（桌面 + 手机）用真实实现。
// 手机端虽然会编译进真实实现，但所有调用都被 isDesktopShell 挡住，不会执行。
//
// 必须走条件导出而不是直接 import —— tray_manager 底层的 nativeapi 依赖
// dart:ffi，Web 上没有这个库，直接 import 会让 `flutter build web` 编译失败。
export 'desktop_shell_web.dart'
    if (dart.library.io) 'desktop_shell_io.dart';
