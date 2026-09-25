import 'package:flutter/foundation.dart';

/// 界面风格。
///
/// 这不是「主题色」那一层——主题色（[ThemeColour]）是站点的品牌配色，两种风格共用；
/// 风格决定的是排版、材质、控件和动效语言。
enum DesignStyle {
  /// 现有的一整套：Material 3 控件、平铺列表、Material 路由过渡。
  material('material', 'Material'),

  /// Apple 风格：iOS 系统灰、半透明材质、弹簧动效、Cupertino 路由过渡。
  apple('apple', 'Apple');

  const DesignStyle(this.id, this.label);

  final String id;
  final String label;

  /// 存到 prefs 里的兼容读取：认不出来的值退回 [material]，
  /// 这样老用户升级后行为不变。
  static DesignStyle fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => material);

  /// 首次启动时的默认风格：Apple 平台给 Apple 风格，其余平台保持 Material。
  ///
  /// 用 [defaultTargetPlatform] 而不是 `dart:io` 的 `Platform`：前者在 Web 上
  /// 也有定义、并且测试里可以用 `debugDefaultTargetPlatformOverride` 覆盖。
  static DesignStyle defaultForPlatform() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => DesignStyle.apple,
    _ => DesignStyle.material,
  };

  /// 用户没做过选择时，按平台来。
  static DesignStyle resolve(String? storedId) =>
      storedId == null ? defaultForPlatform() : DesignStyle.fromId(storedId);
}
