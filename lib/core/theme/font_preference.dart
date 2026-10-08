import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum FontPreference {
  material('material', 'Material 默认正文'),
  notoSans('noto', 'NotoSans'),
  system('system', '系统默认');

  const FontPreference(this.id, this.label);
  final String id, label;

  static FontPreference fromId(String? id) =>
      values.firstWhere((font) => font.id == id, orElse: () => material);
}

ThemeData applyFontPreference(ThemeData theme, FontPreference font) {
  final family = switch (font) {
    FontPreference.material => 'Roboto',
    FontPreference.notoSans => 'NotoSans',
    FontPreference.system => switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'Segoe UI',
      TargetPlatform.macOS || TargetPlatform.iOS => '.AppleSystemUIFont',
      TargetPlatform.linux => 'sans-serif',
      _ => null,
    },
  };
  final fallback = font == FontPreference.system
      ? switch (defaultTargetPlatform) {
          TargetPlatform.windows => const ['Microsoft YaHei', 'sans-serif'],
          TargetPlatform.macOS ||
          TargetPlatform.iOS => const ['PingFang SC', 'sans-serif'],
          _ => const ['sans-serif'],
        }
      : const ['NotoSans', 'Microsoft YaHei', 'PingFang SC', 'sans-serif'];
  TextStyle? style(TextStyle? value) =>
      value?.copyWith(fontFamily: family, fontFamilyFallback: fallback);
  WidgetStateProperty<TextStyle?>? states(
    WidgetStateProperty<TextStyle?>? value,
  ) => value == null
      ? null
      : WidgetStateProperty.resolveWith((state) => style(value.resolve(state)));
  ButtonStyle? button(ButtonStyle? value) =>
      value?.copyWith(textStyle: states(value.textStyle));
  TextTheme update(TextTheme text) =>
      text.apply(fontFamily: family, fontFamilyFallback: fallback);
  final text = update(theme.textTheme);
  return theme.copyWith(
    textTheme: text,
    primaryTextTheme: update(theme.primaryTextTheme),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: style(theme.appBarTheme.titleTextStyle),
      toolbarTextStyle: style(theme.appBarTheme.toolbarTextStyle),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: button(theme.filledButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: button(theme.elevatedButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: button(theme.textButtonTheme.style),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: button(theme.segmentedButtonTheme.style),
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: style(theme.listTileTheme.titleTextStyle),
      subtitleTextStyle: style(theme.listTileTheme.subtitleTextStyle),
      leadingAndTrailingTextStyle: style(
        theme.listTileTheme.leadingAndTrailingTextStyle,
      ),
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      hintStyle: style(theme.inputDecorationTheme.hintStyle),
      labelStyle: style(theme.inputDecorationTheme.labelStyle),
      floatingLabelStyle: style(theme.inputDecorationTheme.floatingLabelStyle),
      helperStyle: style(theme.inputDecorationTheme.helperStyle),
      errorStyle: style(theme.inputDecorationTheme.errorStyle),
      counterStyle: style(theme.inputDecorationTheme.counterStyle),
    ),
    searchBarTheme: theme.searchBarTheme.copyWith(
      textStyle: states(theme.searchBarTheme.textStyle),
      hintStyle: states(theme.searchBarTheme.hintStyle),
    ),
    dialogTheme: theme.dialogTheme.copyWith(
      titleTextStyle: style(theme.dialogTheme.titleTextStyle),
      contentTextStyle: style(theme.dialogTheme.contentTextStyle),
    ),
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: style(theme.chipTheme.labelStyle),
    ),
    tabBarTheme: theme.tabBarTheme.copyWith(
      labelStyle: style(theme.tabBarTheme.labelStyle),
      unselectedLabelStyle: style(theme.tabBarTheme.unselectedLabelStyle),
    ),
    popupMenuTheme: theme.popupMenuTheme.copyWith(
      textStyle: style(theme.popupMenuTheme.textStyle),
    ),
    tooltipTheme: theme.tooltipTheme.copyWith(
      textStyle: style(theme.tooltipTheme.textStyle),
    ),
    snackBarTheme: theme.snackBarTheme.copyWith(
      contentTextStyle: style(theme.snackBarTheme.contentTextStyle),
    ),
    navigationBarTheme: theme.navigationBarTheme.copyWith(
      labelTextStyle: states(theme.navigationBarTheme.labelTextStyle),
    ),
    navigationDrawerTheme: theme.navigationDrawerTheme.copyWith(
      labelTextStyle: states(theme.navigationDrawerTheme.labelTextStyle),
    ),
    navigationRailTheme: theme.navigationRailTheme.copyWith(
      selectedLabelTextStyle: style(
        theme.navigationRailTheme.selectedLabelTextStyle,
      ),
      unselectedLabelTextStyle: style(
        theme.navigationRailTheme.unselectedLabelTextStyle,
      ),
    ),
  );
}
