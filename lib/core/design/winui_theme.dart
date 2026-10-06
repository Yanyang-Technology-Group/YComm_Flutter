import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const winuiFontFamily = 'Segoe UI Variable';
const winuiFontFallback = <String>[
  'Segoe UI',
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'PingFang SC',
  'Roboto',
];

/// Fluent surface roles, also used to identify the WinUI layout at runtime.
/// Platform preferences decide whether this theme can be activated.
class WinuiTokens extends ThemeExtension<WinuiTokens> {
  const WinuiTokens({
    required this.brightness,
    required this.canvas,
    required this.card,
    required this.elevated,
    required this.control,
    required this.stroke,
    required this.hover,
    required this.pressed,
    required this.focus,
  });

  final Brightness brightness;
  final Color canvas;
  final Color card;
  final Color elevated;
  final Color control;
  final Color stroke;
  final Color hover;
  final Color pressed;
  final Color focus;

  bool get isDark => brightness == Brightness.dark;

  factory WinuiTokens.of(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return WinuiTokens(
      brightness: brightness,
      canvas: dark ? const Color(0xFF202020) : const Color(0xFFF3F3F3),
      card: dark ? const Color(0xFF2B2B2B) : Colors.white,
      elevated: dark ? const Color(0xFF2C2C2C) : const Color(0xFFF9F9F9),
      control: dark ? const Color(0xFF333333) : Colors.white,
      stroke: dark ? const Color(0xFF595959) : const Color(0xFFD1D1D1),
      hover: dark ? const Color(0xFF3A3A3A) : const Color(0xFFEFEFEF),
      pressed: dark ? const Color(0xFF303030) : const Color(0xFFE5E5E5),
      focus: dark ? Colors.white : Colors.black,
    );
  }

  @override
  WinuiTokens copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? card,
    Color? elevated,
    Color? control,
    Color? stroke,
    Color? hover,
    Color? pressed,
    Color? focus,
  }) => WinuiTokens(
    brightness: brightness ?? this.brightness,
    canvas: canvas ?? this.canvas,
    card: card ?? this.card,
    elevated: elevated ?? this.elevated,
    control: control ?? this.control,
    stroke: stroke ?? this.stroke,
    hover: hover ?? this.hover,
    pressed: pressed ?? this.pressed,
    focus: focus ?? this.focus,
  );

  @override
  WinuiTokens lerp(ThemeExtension<WinuiTokens>? other, double t) {
    if (other is! WinuiTokens) {
      return this;
    }
    return WinuiTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      control: Color.lerp(control, other.control, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      pressed: Color.lerp(pressed, other.pressed, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
    );
  }
}

WinuiTokens? winuiTokensOf(BuildContext context) =>
    Theme.of(context).extension<WinuiTokens>();

bool isWinui(BuildContext context) => winuiTokensOf(context) != null;

TextStyle _winuiFont(TextStyle style) => style.copyWith(
  fontFamily: winuiFontFamily,
  fontFamilyFallback: winuiFontFallback,
);

/// WinUI appearance rendered by Flutter, with shared brand colours and semantics.
ThemeData buildWinuiTheme(ThemeColour colour, Brightness brightness) {
  final base = buildTheme(colour, brightness);
  final tokens = WinuiTokens.of(brightness);
  final dark = tokens.isDark;
  final scheme = buildColorScheme(colour, brightness).copyWith(
    surface: tokens.canvas,
    surfaceContainerLowest: tokens.card,
    surfaceContainerLow: tokens.card,
    surfaceContainer: tokens.elevated,
    surfaceContainerHigh: tokens.control,
    surfaceContainerHighest: tokens.hover,
    onSurface: dark ? Colors.white : const Color(0xFF1A1A1A),
    onSurfaceVariant: dark ? const Color(0xFFC6C6C6) : const Color(0xFF5D5D5D),
    outline: dark ? const Color(0xFF9D9D9D) : const Color(0xFF727272),
    outlineVariant: tokens.stroke,
    inverseSurface: dark ? const Color(0xFFF3F3F3) : const Color(0xFF202020),
    onInverseSurface: dark ? const Color(0xFF1A1A1A) : Colors.white,
    surfaceTint: Colors.transparent,
  );
  final text = base.textTheme
      .copyWith(
        headlineLarge: const TextStyle(
          fontSize: 32,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: const TextStyle(
          fontSize: 24,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: const TextStyle(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
        labelLarge: const TextStyle(fontSize: 14, height: 1.4),
        labelMedium: const TextStyle(fontSize: 12, height: 1.4),
        labelSmall: const TextStyle(fontSize: 11, height: 1.4),
      )
      .apply(
        fontFamily: winuiFontFamily,
        fontFamilyFallback: winuiFontFallback,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      )
      .copyWith(
        bodySmall: _winuiFont(
          TextStyle(fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
        ),
      );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(4),
  );
  final surfaceShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(color: tokens.stroke),
  );

  Color overlay(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return Colors.transparent;
    }
    if (states.contains(WidgetState.pressed)) {
      return scheme.onSurface.withValues(alpha: 0.08);
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return scheme.onSurface.withValues(alpha: 0.04);
    }
    return Colors.transparent;
  }

  BorderSide controlSide(Set<WidgetState> states, {bool border = true}) {
    if (states.contains(WidgetState.disabled)) {
      return border
          ? BorderSide(color: tokens.stroke.withValues(alpha: 0.6))
          : BorderSide.none;
    }
    if (states.contains(WidgetState.focused)) {
      return BorderSide(color: tokens.focus, width: 2);
    }
    return border ? BorderSide(color: tokens.stroke) : BorderSide.none;
  }

  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 32)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    textStyle: WidgetStatePropertyAll(text.labelLarge),
    shape: WidgetStatePropertyAll(controlShape),
    overlayColor: WidgetStateProperty.resolveWith(overlay),
    elevation: const WidgetStatePropertyAll(0),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    visualDensity: VisualDensity.standard,
    // The visible desktop control is compact; its tap target remains 48px.
    tapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: NoSplash.splashFactory,
    animationDuration: const Duration(milliseconds: 100),
  );
  final neutralButton = button.copyWith(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.disabled) ? tokens.hover : tokens.control,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? scheme.onSurfaceVariant
          : scheme.onSurface,
    ),
    side: WidgetStateProperty.resolveWith(controlSide),
  );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.canvas,
    canvasColor: tokens.canvas,
    cardColor: tokens.card,
    dividerColor: tokens.stroke,
    focusColor: scheme.onSurface.withValues(alpha: 0.08),
    hoverColor: scheme.onSurface.withValues(alpha: 0.04),
    highlightColor: scheme.onSurface.withValues(alpha: 0.08),
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: text,
    primaryTextTheme: text,
    extensions: [...base.extensions.values, tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.canvas,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 48,
      titleTextStyle: text.titleMedium,
      toolbarTextStyle: text.bodyMedium,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 20),
      actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 20),
    ),
    cardTheme: CardThemeData(
      color: tokens.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: surfaceShape,
    ),
    dividerTheme: DividerThemeData(
      color: tokens.stroke,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: button.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? tokens.hover
              : scheme.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurfaceVariant
              : scheme.onPrimary,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => controlSide(states, border: false),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: neutralButton),
    outlinedButtonTheme: OutlinedButtonThemeData(style: neutralButton),
    textButtonTheme: TextButtonThemeData(
      style: button.copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurfaceVariant
              : scheme.primary,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => controlSide(states, border: false),
        ),
      ),
    ),
    iconTheme: IconThemeData(color: scheme.onSurface, size: 20),
    iconButtonTheme: IconButtonThemeData(
      style: button.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(32, 32)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurfaceVariant
              : scheme.onSurface,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => controlSide(states, border: false),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      shape: controlShape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.control,
      isDense: true,
      constraints: const BoxConstraints(minHeight: 36),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: text.bodyMedium,
      border: inputBorder(tokens.stroke),
      enabledBorder: inputBorder(tokens.stroke),
      disabledBorder: inputBorder(tokens.stroke.withValues(alpha: 0.6)),
      focusedBorder: inputBorder(tokens.focus, 2),
      errorBorder: inputBorder(scheme.error),
      focusedErrorBorder: inputBorder(scheme.error, 2),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(tokens.control),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: WidgetStateProperty.resolveWith(overlay),
      side: WidgetStateProperty.resolveWith(controlSide),
      shape: WidgetStatePropertyAll(controlShape),
      constraints: const BoxConstraints(minHeight: 36),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      textStyle: WidgetStatePropertyAll(text.bodyMedium),
      hintStyle: WidgetStatePropertyAll(
        text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: 40,
      minVerticalPadding: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      horizontalTitleGap: 12,
      minLeadingWidth: 20,
      shape: controlShape,
      textColor: scheme.onSurface,
      iconColor: scheme.onSurfaceVariant,
      selectedColor: scheme.onSurface,
      selectedTileColor: scheme.primaryContainer,
      titleTextStyle: text.bodyMedium,
      subtitleTextStyle: text.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? tokens.hover
            : states.contains(WidgetState.selected)
            ? scheme.primary
            : tokens.control,
      ),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      overlayColor: WidgetStateProperty.resolveWith(overlay),
      side: WidgetStateBorderSide.resolveWith(controlSide),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? tokens.hover
            : states.contains(WidgetState.selected)
            ? scheme.primary
            : tokens.control,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? tokens.focus
            : states.contains(WidgetState.selected)
            ? Colors.transparent
            : tokens.stroke,
      ),
      trackOutlineWidth: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused) ? 2 : 1,
      ),
      overlayColor: WidgetStateProperty.resolveWith(overlay),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.onSurfaceVariant,
      ),
      overlayColor: WidgetStateProperty.resolveWith(overlay),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: neutralButton.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : tokens.control,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.control,
      selectedColor: scheme.primaryContainer,
      disabledColor: tokens.hover,
      checkmarkColor: scheme.primary,
      labelStyle: text.bodyMedium,
      side: BorderSide(color: tokens.stroke),
      shape: controlShape,
      elevation: 0,
      pressElevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    tabBarTheme: TabBarThemeData(
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: tokens.stroke,
      dividerHeight: 1,
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: text.labelLarge,
      overlayColor: WidgetStateProperty.resolveWith(overlay),
      splashFactory: NoSplash.splashFactory,
      splashBorderRadius: BorderRadius.circular(4),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: tokens.canvas,
      elevation: 0,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: controlShape,
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 20),
      unselectedIconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: 20,
      ),
      selectedLabelTextStyle: text.bodyMedium,
      unselectedLabelTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: tokens.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: controlShape,
      indicatorSize: const Size(220, 40),
      labelTextStyle: WidgetStatePropertyAll(text.bodyMedium),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: scheme.onSurface, size: 20),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: tokens.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: controlShape,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: tokens.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.elevated,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: surfaceShape,
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.elevated,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        side: BorderSide(color: tokens.stroke),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.elevated,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: surfaceShape,
      menuPadding: const EdgeInsets.all(4),
      textStyle: text.bodyMedium,
      iconColor: scheme.onSurface,
      iconSize: 20,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(tokens.elevated),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(surfaceShape),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: button.copyWith(
        foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
        side: WidgetStateProperty.resolveWith(
          (states) => controlSide(states, border: false),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: tokens.elevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tokens.stroke),
      ),
      textStyle: text.bodySmall?.copyWith(color: scheme.onSurface),
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      waitDuration: const Duration(milliseconds: 700),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.elevated,
      elevation: 4,
      shape: surfaceShape,
      contentTextStyle: text.bodyMedium,
      actionTextColor: scheme.primary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: tokens.hover,
      circularTrackColor: Colors.transparent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) ? 8 : 4,
      ),
      radius: const Radius.circular(2),
      thumbColor: WidgetStatePropertyAll(scheme.outline),
      interactive: true,
    ),
  );
}
