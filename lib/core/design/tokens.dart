import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Apple 风格设计 token。
///
/// 取值思路来自 Apple HIG 而不是 Material：间距按 4 的倍数但基数更大（iOS 常用的
/// 8/16/20），圆角分「连续曲率」那一档（iOS 的 squircle 视觉上比同半径圆弧更圆），
/// 发丝线用设备物理像素而不是逻辑像素。
class AppleSpacing {
  const AppleSpacing._();

  /// 列表行内边距，与 iOS 系统「设置」一致。
  static const double row = 16;

  /// 分组的左右外边距。
  static const double gutter = 16;

  /// 页面大标题的左边距（比列表多 4，视觉上对齐正文起点）。
  static const double title = 20;

  /// 分组之间的垂直间隔。
  static const double section = 32;

  /// 分组内标题与内容的间隔。
  static const double sectionHeader = 8;

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// 圆角。iOS 的连续曲率圆角在 Flutter 里没有直接对应，
/// 这里统一用略大的半径来近似那种「更饱满」的观感。
class AppleRadius {
  const AppleRadius._();

  static const double row = 10;
  static const double card = 10;
  static const double sheet = 16;
  static const double control = 8;
  static const double chip = 100; // 胶囊
}

/// 发丝线宽度：按设备像素比取最小可见线，避免高 DPI 上出现 2px 灰边。
double hairlineOf(BuildContext context) {
  final ratio = MediaQuery.devicePixelRatioOf(context);
  return ratio <= 0 ? 1 : 1 / ratio;
}

/// 配色。
///
/// 这里只放 Apple 自己的系统灰阶，强调色一律复用 [ThemeColour]（test/theme_test.dart
/// 对那六组取值有精确断言，不能被 Apple 风格覆盖）。
class ApplePalette {
  const ApplePalette._();

  // 中性底色与清晰表面层级；品牌色只用于交互强调。
  static const white = Color(0xFFFFFFFF);
  static const groupedBackground = Color(0xFFF5F5F7);
  static const label = Color(0xFF000000);
  static const secondaryLabel = Color(0x993C3C43); // label @ 60%
  static const tertiaryLabel = Color(0x4C3C3C43); // label @ 30%
  static const separator = Color(0x383C3C43); // @ 22%
  static const opaqueSeparator = Color(0xFFC6C6C8);
  static const fill = Color(0x1F787880); // @ 12%
  static const secondaryFill = Color(0x29787880); // @ 16%

  // ---- 深色 ----
  static const groupedBackgroundDark = Color(0xFF08090B);
  static const surfaceDark = Color(0xFF1C1C1E);
  static const surfaceElevatedDark = Color(0xFF2C2C2E);
  static const labelDark = Color(0xFFFFFFFF);
  static const secondaryLabelDark = Color(0x99EBEBF5); // @ 60%
  static const tertiaryLabelDark = Color(0x4CEBEBF5); // @ 30%
  static const separatorDark = Color(0x66545458); // @ 40%
  static const opaqueSeparatorDark = Color(0xFF38383A);
  static const fillDark = Color(0x5C787880); // @ 36%
  static const secondaryFillDark = Color(0x52787880); // @ 32%

  static Color grouped(bool dark) =>
      dark ? groupedBackgroundDark : groupedBackground;
  static Color surface(bool dark) => dark ? surfaceDark : white;
  static Color labelOf(bool dark) => dark ? labelDark : label;
  static Color secondaryLabelOf(bool dark) =>
      dark ? secondaryLabelDark : secondaryLabel;
  static Color tertiaryLabelOf(bool dark) =>
      dark ? tertiaryLabelDark : tertiaryLabel;
  static Color separatorOf(bool dark) => dark ? separatorDark : separator;
  static Color opaqueSeparatorOf(bool dark) =>
      dark ? opaqueSeparatorDark : opaqueSeparator;
  static Color fillOf(bool dark) => dark ? fillDark : fill;
  static Color secondaryFillOf(bool dark) =>
      dark ? secondaryFillDark : secondaryFill;

  /// 半透明材质层。导航栏、输入条、sheet 都用它垫在 BackdropFilter 下面。
  static Color material(bool dark) =>
      dark ? const Color(0xCC1C1C1E) : const Color(0xCCF9F9F9);

  /// 材质的顶边高光——光打在材质边缘上，是 iOS 半透明栏最明显的特征。
  static Color materialHighlight(bool dark) =>
      dark ? const Color(0x1FFFFFFF) : const Color(0x66FFFFFF);
}

/// 动态字级。
///
/// Apple 的排版规则是**字号、行高、字距三者一起变**：字号越大字距越紧（负值），
/// 正文接近 0，脚注略微放开。固定 letterSpacing 一定会在某个字号上是错的，
/// 所以这里每个档位单独给值。
///
/// 字号倍数交给 Flutter 的文本缩放（系统辅助功能里的「文字大小」），
/// 布局用相对间距跟随，不写死像素高度。
class AppleType {
  const AppleType._();

  static const largeTitle = TextStyle(
    fontSize: 34,
    height: 38 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );
  static const title1 = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
  );
  static const title2 = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.26,
  );
  static const title3 = TextStyle(
    fontSize: 20,
    height: 25 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.45,
  );
  static const headline = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
  );
  static const body = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
  );
  static const callout = TextStyle(
    fontSize: 16,
    height: 21 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
  );
  static const subheadline = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
  );
  static const footnote = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
  );
  static const caption1 = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const caption2 = TextStyle(
    fontSize: 11,
    height: 13 / 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.07,
  );

  /// 表格行标题用 17pt 常规，副标题降一档并转次要色。
  static const rowTitle = headline;
  static const rowSubtitle = footnote;
}

/// 给任何显式构造的 [TextStyle] 补上字体。
///
/// 必须成对给：`ButtonStyle.textStyle`、`AppBarTheme.titleTextStyle` 这类样式是
/// **绝对应用**的，不会与 [DefaultTextStyle] 合并。只给 `fontFamilyFallback`
/// 而 `fontFamily` 为空时，文本会落到平台默认字体上，fallback 链根本走不到——
/// 表现就是中文正常、拉丁字母变方块。用这个函数统一处理，避免再漏。
TextStyle appleFont(TextStyle style) => style.copyWith(
  fontFamily: appleFontFamily,
  fontFamilyFallback: appleFontFallback,
);

/// Apple 平台使用系统 San Francisco，其它平台使用可用的字体回退。
String get appleFontFamily => switch (defaultTargetPlatform) {
  TargetPlatform.iOS || TargetPlatform.macOS => '.SF Pro Text',
  _ => 'Roboto',
};

/// 中文与其它字形的回退链。
///
/// 顺序按平台铺开：Apple 平台上 `.SF Pro` 由系统提供，这里只需要中文侧；
/// 其余平台优先复用已注册的拉丁字体，再落到各平台自带的中文字体。
const appleFontFallback = <String>[
  // 与主字体同名，保证 fallback 的第一顺位仍是它，而不是某个 CJK 字体
  'Roboto',
  // Apple 平台（.SF Pro 由系统提供，这里只写中文侧）
  'PingFang SC',
  'Hiragino Sans GB',
  // Windows
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Segoe UI',
  // Linux / Android
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Source Han Sans SC',
  'WenQuanYi Micro Hei',
];
