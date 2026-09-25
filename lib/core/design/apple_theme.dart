// CupertinoPageTransitionsBuilder 定义在 cupertino/route.dart，
// material 库不再把它导出来，需要单独引入。
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tokens.dart';

/// Apple 风格主题。
///
/// 与 [buildTheme] 的关系：**强调色那部分完全一样**，中性色与排版换成 iOS 取值。
/// 不复制配色推导逻辑，而是调用 [buildColorScheme] 拿到与 Material 风格一致的
/// 六档强调色，再覆盖中性角色——这样两种风格切换时，品牌配色不会漂移，
/// test/theme_test.dart 对强调色的断言也继续成立。
///
/// ThemeData 仅作为共享业务布局的颜色、排版与 AppleTokens 数据源。
/// AppleApp 使用 CupertinoApp；adaptive.dart 的控件在 Apple 模式构建
/// Cupertino/widgets 子树，不依赖下面保留的 Material 主题配置。

/// 供 Apple 风格组件读取的扩展 token。
///
/// 挂在 [ThemeData.extensions] 上，组件里 `Theme.of(context).extension<AppleTokens>()`
/// 就能拿到分组底色、发丝线、材质高光这些 Material 配色方案里没有的角色。
class AppleTokens extends ThemeExtension<AppleTokens> {
  const AppleTokens({
    required this.brightness,
    required this.groupedBackground,
    required this.cardBackground,
    required this.elevatedBackground,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.opaqueSeparator,
    required this.fill,
    required this.secondaryFill,
    required this.materialColor,
    required this.materialHighlight,
  });

  final Brightness brightness;

  /// 页面底色：iOS 分组列表的浅灰底。
  final Color groupedBackground;

  /// 组内卡片色。
  final Color cardBackground;

  /// 抬升一层的表面（sheet、浮层）。
  final Color elevatedBackground;

  final Color secondaryLabel;
  final Color tertiaryLabel;

  /// 发丝分隔线。
  final Color separator;

  /// 不透明分隔线，用于需要明确边界的地方（tab bar 顶边）。
  final Color opaqueSeparator;

  /// 填充色：搜索框、分段控件底槽。
  final Color fill;
  final Color secondaryFill;

  /// 半透明材质本体。
  final Color materialColor;

  /// 材质顶边高光。
  final Color materialHighlight;

  bool get isDark => brightness == Brightness.dark;

  factory AppleTokens.of(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return AppleTokens(
      brightness: brightness,
      groupedBackground: ApplePalette.grouped(dark),
      cardBackground: ApplePalette.surface(dark),
      elevatedBackground: dark
          ? ApplePalette.surfaceElevatedDark
          : ApplePalette.white,
      secondaryLabel: ApplePalette.secondaryLabelOf(dark),
      tertiaryLabel: ApplePalette.tertiaryLabelOf(dark),
      separator: ApplePalette.separatorOf(dark),
      opaqueSeparator: ApplePalette.opaqueSeparatorOf(dark),
      fill: ApplePalette.fillOf(dark),
      secondaryFill: ApplePalette.secondaryFillOf(dark),
      materialColor: ApplePalette.material(dark),
      materialHighlight: ApplePalette.materialHighlight(dark),
    );
  }

  @override
  AppleTokens copyWith({
    Brightness? brightness,
    Color? groupedBackground,
    Color? cardBackground,
    Color? elevatedBackground,
    Color? secondaryLabel,
    Color? tertiaryLabel,
    Color? separator,
    Color? opaqueSeparator,
    Color? fill,
    Color? secondaryFill,
    Color? materialColor,
    Color? materialHighlight,
  }) => AppleTokens(
    brightness: brightness ?? this.brightness,
    groupedBackground: groupedBackground ?? this.groupedBackground,
    cardBackground: cardBackground ?? this.cardBackground,
    elevatedBackground: elevatedBackground ?? this.elevatedBackground,
    secondaryLabel: secondaryLabel ?? this.secondaryLabel,
    tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
    separator: separator ?? this.separator,
    opaqueSeparator: opaqueSeparator ?? this.opaqueSeparator,
    fill: fill ?? this.fill,
    secondaryFill: secondaryFill ?? this.secondaryFill,
    materialColor: materialColor ?? this.materialColor,
    materialHighlight: materialHighlight ?? this.materialHighlight,
  );

  @override
  AppleTokens lerp(ThemeExtension<AppleTokens>? other, double t) {
    if (other is! AppleTokens) return this;
    return AppleTokens(
      // 明暗在切换过程中不插值，取目标值——半亮半暗的中间态没有意义。
      brightness: t < 0.5 ? brightness : other.brightness,
      groupedBackground: Color.lerp(
        groupedBackground,
        other.groupedBackground,
        t,
      )!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      elevatedBackground: Color.lerp(
        elevatedBackground,
        other.elevatedBackground,
        t,
      )!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      tertiaryLabel: Color.lerp(tertiaryLabel, other.tertiaryLabel, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      opaqueSeparator: Color.lerp(opaqueSeparator, other.opaqueSeparator, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      secondaryFill: Color.lerp(secondaryFill, other.secondaryFill, t)!,
      materialColor: Color.lerp(materialColor, other.materialColor, t)!,
      materialHighlight: Color.lerp(
        materialHighlight,
        other.materialHighlight,
        t,
      )!,
    );
  }
}

/// 在 Material 配色方案基础上，把中性角色换成 iOS 取值。
ColorScheme _appleScheme(ThemeColour colour, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = buildColorScheme(colour, brightness);
  return base.copyWith(
    surface: ApplePalette.grouped(dark),
    // surfaceContainer* 在页面里被当作卡片色用（现有代码用的是
    // surfaceContainerLowest），所以这一档给纯白/抬升色，而不是分组底色。
    surfaceContainerLowest: ApplePalette.surface(dark),
    surfaceContainerLow: ApplePalette.surface(dark),
    surfaceContainer: dark
        ? ApplePalette.surfaceElevatedDark
        : ApplePalette.white,
    surfaceContainerHigh: dark
        ? ApplePalette.surfaceElevatedDark
        : ApplePalette.white,
    surfaceContainerHighest: dark
        ? ApplePalette.surfaceElevatedDark
        : ApplePalette.white,
    onSurface: ApplePalette.labelOf(dark),
    onSurfaceVariant: ApplePalette.secondaryLabelOf(dark),
    outline: ApplePalette.tertiaryLabelOf(dark),
    outlineVariant: ApplePalette.separatorOf(dark),
    surfaceTint: Colors.transparent,
    // iOS 的系统蓝用在链接和次要强调上，和品牌强调色是两件事。
    // 这里只在没有配置网站三档取值时给一个 iOS 蓝作为 secondary 之外的兜底，
    // 主色仍然完全跟随 [ThemeColour]。
  );
}

ThemeData buildAppleTheme(ThemeColour colour, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = _appleScheme(colour, brightness);
  final tokens = AppleTokens.of(brightness);

  // 文字样式统一补上字重与字距；颜色由调用处按角色给（正文 label、次要 secondaryLabel）。
  TextStyle styled(TextStyle base, Color color) => base.copyWith(color: color);

  final text = TextTheme(
    displayLarge: styled(AppleType.largeTitle, scheme.onSurface),
    displayMedium: styled(AppleType.title1, scheme.onSurface),
    displaySmall: styled(AppleType.title2, scheme.onSurface),
    headlineLarge: styled(AppleType.largeTitle, scheme.onSurface),
    headlineMedium: styled(AppleType.title1, scheme.onSurface),
    headlineSmall: styled(AppleType.title2, scheme.onSurface),
    titleLarge: styled(AppleType.title3, scheme.onSurface),
    titleMedium: styled(AppleType.headline, scheme.onSurface),
    titleSmall: styled(AppleType.subheadline, tokens.secondaryLabel),
    bodyLarge: styled(AppleType.body, scheme.onSurface),
    bodyMedium: styled(AppleType.subheadline, scheme.onSurface),
    bodySmall: styled(AppleType.footnote, tokens.secondaryLabel),
    labelLarge: styled(AppleType.headline, scheme.onSurface),
    labelMedium: styled(AppleType.footnote, tokens.secondaryLabel),
    labelSmall: styled(AppleType.caption2, tokens.tertiaryLabel),
    // 两个都要传：只给 fallback 的话，每个样式的 fontFamily 仍是空的，
    // 会把 ThemeData 上的主字体覆盖掉，文本又落回平台默认字体（拉丁变方块）。
  ).apply(fontFamily: appleFontFamily, fontFamilyFallback: appleFontFallback);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    // 必须显式给主字体：只给 fallback 链的话，文本会落到平台默认字体上，
    // fallback 不会被走到——Linux 上默认字体常只有 CJK 覆盖，拉丁字形会变方块。
    // Apple 平台上的 .SF Pro 由系统负责，这里指定的是拉丁主字体 + 中文回退链。
    fontFamily: appleFontFamily,
    fontFamilyFallback: appleFontFallback,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    scaffoldBackgroundColor: tokens.groupedBackground,
    textTheme: text,
    primaryTextTheme: text,
    extensions: [tokens],

    // iOS 导航栏：内容从半透明栏下方穿过，所以这里给透明底，
    // 真正的模糊由 TranslucentBar 画（见 apple_chrome.dart）。
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.materialColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: appleFont(
        AppleType.headline.copyWith(color: scheme.onSurface),
      ),
      iconTheme: IconThemeData(color: scheme.primary, size: 22),
      actionsIconTheme: IconThemeData(color: scheme.primary, size: 22),
    ),

    // 发丝线：iOS 的分隔线比 Material 细得多，且左右内缩由使用方控制。
    dividerTheme: DividerThemeData(
      color: tokens.separator,
      thickness: 0.5,
      space: 0.5,
    ),

    // 分组卡片：iOS 的圆角是 10，比现有 Material 的 24 收得紧。
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: tokens.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppleRadius.card),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: appleFont(AppleType.headline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleRadius.control),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        foregroundColor: scheme.primary,
        side: BorderSide(color: tokens.separator),
        textStyle: appleFont(AppleType.body),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleRadius.control),
        ),
      ),
    ),
    // iOS 的纯文字按钮是强调色的，没有容器。
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: scheme.primary,
        textStyle: appleFont(AppleType.body),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size(44, 44),
      ),
    ),

    // 搜索框/输入框：iOS 用填充而不是描边，圆角 10。
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: appleFont(
        AppleType.body.copyWith(color: tokens.tertiaryLabel),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppleRadius.control),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppleRadius.control),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppleRadius.control),
        borderSide: BorderSide.none,
      ),
    ),

    // 分段控件（资源页的「资源目录 / 社区分享」）走 iOS 底槽观感。
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.cardBackground
              : tokens.fill,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onSurface
              : tokens.secondaryLabel,
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        textStyle: WidgetStatePropertyAll(
          appleFont(AppleType.subheadline.copyWith()),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleRadius.control),
          ),
        ),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: tokens.fill,
      selectedColor: scheme.primary,
      labelStyle: appleFont(AppleType.subheadline.copyWith()),
      secondaryLabelStyle: appleFont(
        AppleType.subheadline.copyWith(color: scheme.onPrimary),
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),

    // 提示条：iOS 没有 Material 那种长条 snackbar，这里收成浮起的胶囊。
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark
          ? ApplePalette.surfaceElevatedDark
          : const Color(0xE61C1C1E),
      contentTextStyle: appleFont(
        AppleType.subheadline.copyWith(color: Colors.white),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppleRadius.card),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.elevatedBackground,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: tokens.tertiaryLabel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppleRadius.sheet),
        ),
      ),
    ),

    // 对话框：iOS 弹窗是 14 圆角、居中、带模糊底。
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.elevatedBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: appleFont(
        AppleType.headline.copyWith(color: scheme.onSurface),
      ),
      contentTextStyle: appleFont(
        AppleType.footnote.copyWith(color: scheme.onSurface),
      ),
    ),

    // 开关跟随 iOS 系统绿——这是「熟悉感」原则：开关在 iOS 上就是绿的，
    // 用品牌色反而认不出来。轨道用系统灰阶。
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF34C759)
            : tokens.fill,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: scheme.primary,
      textColor: scheme.onSurface,
      titleTextStyle: appleFont(AppleType.rowTitle),
      subtitleTextStyle: appleFont(
        AppleType.rowSubtitle.copyWith(color: tokens.secondaryLabel),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: tokens.fill,
      circularTrackColor: Colors.transparent,
    ),

    // 滚动条：iOS 默认不常驻，滚动时才出现且更细。
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(3),
      radius: const Radius.circular(2),
      thumbColor: WidgetStatePropertyAll(tokens.tertiaryLabel),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: tokens.elevatedBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppleRadius.sheet),
      ),
      textStyle: appleFont(AppleType.body.copyWith(color: scheme.onSurface)),
    ),

    // 页面切换：横向推入 + 手势返回，这是 iOS 最容易被认出来的动效。
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        // 其余平台也用同一套，风格统一比平台一致更重要（用户主动选了 Apple 风格）。
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
