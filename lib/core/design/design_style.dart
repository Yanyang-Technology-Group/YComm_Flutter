import 'package:flutter/foundation.dart';

/// 界面风格。
///
/// 主题色是站点的品牌配色，各种风格共用；
/// 风格决定的是排版、材质、控件和动效语言。
enum DesignStyle {
  /// 现有的一整套：Material 3 控件、平铺列表、Material 路由过渡。
  material('material', 'Material'),

  /// Apple 风格：iOS 系统灰、半透明材质、弹簧动效、Cupertino 路由过渡。
  apple('apple', 'Apple'),

  /// Windows 桌面风格：WinUI 控件、侧边导航与系统字体。
  winui('winui', 'WinUI');

  const DesignStyle(this.id, this.label);

  final String id;
  final String label;

  /// 存到 prefs 里的兼容读取：认不出来的值退回 [material]，
  /// 这样老用户升级后行为不变。
  static DesignStyle fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => material);

  /// WinUI 仅对 Windows 原生客户端开放。
  bool get isSupported => isSupportedOn();

  bool isSupportedOn({TargetPlatform? platform, bool isWeb = kIsWeb}) =>
      this != winui ||
      (!isWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.windows);

  static List<DesignStyle> supportedForPlatform({
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) => values
      .where((style) => style.isSupportedOn(platform: platform, isWeb: isWeb))
      .toList(growable: false);

  /// 首次启动：Windows 原生客户端用 WinUI，Apple 平台用 Apple，其余用 Material。
  ///
  /// 用 [defaultTargetPlatform] 而不是 `dart:io` 的 `Platform`：前者在 Web 上
  /// 也有定义、并且测试里可以用 `debugDefaultTargetPlatformOverride` 覆盖。
  static DesignStyle defaultForPlatform({
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) => switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.windows when !isWeb => DesignStyle.winui,
    TargetPlatform.iOS || TargetPlatform.macOS => DesignStyle.apple,
    _ => DesignStyle.material,
  };

  /// 用户没做过选择时，按平台来。
  static DesignStyle resolve(
    String? storedId, {
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    final fallback = defaultForPlatform(platform: platform, isWeb: isWeb);
    if (storedId == null) return fallback;
    final stored = DesignStyle.fromId(storedId);
    return stored.isSupportedOn(platform: platform, isWeb: isWeb)
        ? stored
        : fallback;
  }
}
