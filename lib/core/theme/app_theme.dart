import 'package:flutter/material.dart';

/// 主题色。
///
/// 顺序与取值都跟网站（YComm_WebSite 的 THEME_FAMILIES / globals.css）对齐：
/// seed 就是网站浅色模式下的 --accent。
enum ThemeColour {
  azure('azure', '晏阳蓝', Color(0xFF5D94E8)),
  red('red', '中国红', Color(0xFFFF0000)),
  pink('pink', '猛男粉', Color(0xFFF0899A)),
  mint('mint', '纳西妲绿', Color(0xFF62B35C)),
  orange('orange', '活力橙', Color(0xFFEC8A2E)),
  none('none', '无强调色', Color(0xFF7D848D));

  const ThemeColour(this.id, this.label, this.seed);
  final String id;
  final String label;
  final Color seed;

  /// 网站早期把「无强调色」存成 slate，这里保持兼容。
  static ThemeColour fromId(String? id) => id == 'slate'
      ? none
      : values.firstWhere((e) => e.id == id, orElse: () => azure);
}

enum ThemeModePreference {
  auto('auto'),
  light('light'),
  dark('dark');

  const ThemeModePreference(this.id);
  final String id;
  static ThemeModePreference fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => auto);
}

/// 中文字体回退链。
///
/// 三个桌面平台默认都不保证装有 Noto CJK：Linux 常见 Noto，Windows 是微软雅黑，
/// macOS 是苹方。回退链里少了某个平台的名字，该平台的中文就可能渲染成豆腐块或
/// 落到不带中文字形的默认字体上。
const _cjkFallback = <String>[
  'Noto Sans CJK SC', // Linux
  'Noto Sans SC',
  'Source Han Sans SC',
  'WenQuanYi Micro Hei',
  'Microsoft YaHei UI', // Windows
  'Microsoft YaHei',
  'SimHei',
  'PingFang SC', // macOS
  'Hiragino Sans GB',
  'Heiti SC',
];

/// 把颜色压成同亮度的灰，去掉色相与色度。
Color _greyscale(Color c) {
  final v = (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b).clamp(0.0, 1.0);
  return Color.from(alpha: c.a, red: v, green: v, blue: v);
}

/// 「无强调色」走网站 slate 那一套中性取值。
///
/// 不能直接用 fromSeed(#7d848d)：tonalSpot 会把种子里那一点点偏蓝放大成显眼的主色
/// （实测生成 #2f628c、色度 93，所以看起来是蓝的）。这里改用 M3 的 neutral 变体，
/// 再把残留色度全部去掉，得到真正的黑白灰；error 属于语义色，保持不动。
ColorScheme _neutralScheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: ThemeColour.none.seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  );
  return base.copyWith(
    primary: _greyscale(base.primary),
    onPrimary: _greyscale(base.onPrimary),
    primaryContainer: _greyscale(base.primaryContainer),
    onPrimaryContainer: _greyscale(base.onPrimaryContainer),
    secondary: _greyscale(base.secondary),
    onSecondary: _greyscale(base.onSecondary),
    secondaryContainer: _greyscale(base.secondaryContainer),
    onSecondaryContainer: _greyscale(base.onSecondaryContainer),
    tertiary: _greyscale(base.tertiary),
    onTertiary: _greyscale(base.onTertiary),
    tertiaryContainer: _greyscale(base.tertiaryContainer),
    onTertiaryContainer: _greyscale(base.onTertiaryContainer),
    surfaceTint: _greyscale(base.surfaceTint),
    inversePrimary: _greyscale(base.inversePrimary),
    // 下面这些对齐网站的 slate token：bg / surface / text / muted / border
    surface: dark ? const Color(0xFF0D0E11) : const Color(0xFFF4F4F5),
    surfaceContainerLowest: dark ? const Color(0xFF16171B) : Colors.white,
    onSurface: dark ? const Color(0xFFE5E6EA) : const Color(0xFF1F2226),
    onSurfaceVariant: dark ? const Color(0xFF8E9198) : const Color(0xFF6D7178),
    outlineVariant: dark ? const Color(0xFF26282E) : const Color(0xFFE0E1E4),
  );
}

ThemeData buildTheme(ThemeColour colour, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = colour == ThemeColour.none
      ? _neutralScheme(brightness)
      : ColorScheme.fromSeed(
          seedColor: colour.seed,
          brightness: brightness,
        ).copyWith(
          surface: dark ? const Color(0xFF14171B) : const Color(0xFFF8F9FB),
          surfaceContainerLowest: dark ? const Color(0xFF1C2026) : Colors.white,
          onSurface: dark ? const Color(0xFFECEEF2) : const Color(0xFF19232F),
          onSurfaceVariant: dark
              ? const Color(0xFFADB6C3)
              : const Color(0xFF576474),
          outlineVariant: dark
              ? const Color(0xFF343B45)
              : const Color(0xFFE1E6ED),
        );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    fontFamilyFallback: _cjkFallback,
    colorScheme: scheme,
    brightness: brightness,
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.8,
            color: scheme.onSurface,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.3,
            letterSpacing: -0.6,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.4,
            color: scheme.onSurface,
          ),
          titleMedium: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.45,
            color: scheme.onSurface,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.65,
            color: scheme.onSurface,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: scheme.onSurface,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
        )
        // copyWith 里新建的 TextStyle 不带 fallback，这里统一补上，
        // 否则被覆盖的那几个文字样式在中文字体缺失时会退化。
        .apply(fontFamily: 'Roboto', fontFamilyFallback: _cjkFallback),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: scheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.all(18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
