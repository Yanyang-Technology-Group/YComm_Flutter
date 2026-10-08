import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/theme/font_preference.dart';
import 'package:ycomm_client/core/theme/theme_controller.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/core/design/winui_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('font choice survives restart and other appearance changes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final control = container.read(themeControllerProvider.notifier);
    expect(
      container.read(themeControllerProvider).font,
      FontPreference.material,
    );
    await control.setFont(FontPreference.notoSans);
    await control.setColour(ThemeColour.red);
    await control.setMode(ThemeModePreference.dark);
    await control.load();
    expect(
      container.read(themeControllerProvider).font,
      FontPreference.notoSans,
    );
    final theme = applyFontPreference(
      buildTheme(ThemeColour.red, Brightness.dark),
      FontPreference.notoSans,
    );
    expect(theme.textTheme.bodyMedium?.fontFamily, 'NotoSans');
    expect(
      theme.iconTheme,
      buildTheme(ThemeColour.red, Brightness.dark).iconTheme,
    );
  });
  test('WinUI controls inherit the chosen font without losing baseline', () {
    final original = buildWinuiTheme(ThemeColour.azure, Brightness.light);
    final theme = applyFontPreference(original, FontPreference.notoSans);
    expect(
      theme.filledButtonTheme.style?.textStyle?.resolve({})?.fontFamily,
      'NotoSans',
    );
    expect(theme.listTileTheme.titleTextStyle?.fontFamily, 'NotoSans');
    expect(theme.inputDecorationTheme.labelStyle?.fontFamily, 'NotoSans');
    expect(
      theme.inputDecorationTheme.labelStyle?.textBaseline,
      TextBaseline.alphabetic,
    );
  });
}
