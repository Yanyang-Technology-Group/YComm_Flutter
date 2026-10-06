import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/design/design_style.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/core/theme/theme_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('website theme presets expose four colours plus neutral', () {
    expect(
      ThemeColour.values.map((e) => e.id),
      containsAll(<String>['azure', 'pink', 'mint', 'orange', 'none']),
    );
  });

  test('theme mode round trips', () {
    expect(
      ThemeModePreference.fromId(ThemeModePreference.dark.id),
      ThemeModePreference.dark,
    );
  });

  for (final entry in {
    TargetPlatform.windows: kIsWeb ? DesignStyle.material : DesignStyle.winui,
    TargetPlatform.iOS: DesignStyle.apple,
    TargetPlatform.macOS: DesignStyle.apple,
    TargetPlatform.android: DesignStyle.material,
    TargetPlatform.linux: DesignStyle.material,
    TargetPlatform.fuchsia: DesignStyle.material,
  }.entries) {
    test(
      '$entry starts with its platform default without persisting it',
      () async {
        debugDefaultTargetPlatformOverride = entry.key;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(themeControllerProvider).style, entry.value);
        await container.read(themeControllerProvider.notifier).load();
        expect(container.read(themeControllerProvider).style, entry.value);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(ThemeController.styleKey), isFalse);
      },
    );
  }

  for (final style in [DesignStyle.material, DesignStyle.apple]) {
    test(
      'Windows preserves saved $style instead of using its new default',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        SharedPreferences.setMockInitialValues({
          ThemeController.styleKey: style.id,
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(themeControllerProvider.notifier).load();
        expect(container.read(themeControllerProvider).style, style);
      },
    );
  }

  test(
    'WinUI selection survives reload and preserves colour and mode',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final control = container.read(themeControllerProvider.notifier);
      await control.setColour(ThemeColour.mint);
      await control.setMode(ThemeModePreference.dark);
      await control.setStyle(DesignStyle.material);
      await control.setStyle(DesignStyle.winui);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(ThemeController.styleKey),
        kIsWeb ? 'material' : 'winui',
      );
      final reopened = ProviderContainer();
      addTearDown(reopened.dispose);
      await reopened.read(themeControllerProvider.notifier).load();
      final state = reopened.read(themeControllerProvider);
      expect(state.style, kIsWeb ? DesignStyle.material : DesignStyle.winui);
      expect(state.colour, ThemeColour.mint);
      expect(state.mode, ThemeModePreference.dark);
    },
  );

  for (final platform in TargetPlatform.values.where(
    (platform) => platform != TargetPlatform.windows,
  )) {
    test(
      '$platform falls back from saved WinUI and rejects new WinUI selection',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        SharedPreferences.setMockInitialValues({
          ThemeController.styleKey: 'winui',
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final control = container.read(themeControllerProvider.notifier);
        await control.load();
        expect(
          container.read(themeControllerProvider).style,
          [TargetPlatform.iOS, TargetPlatform.macOS].contains(platform)
              ? DesignStyle.apple
              : DesignStyle.material,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(ThemeController.styleKey), 'winui');
        await control.setStyle(DesignStyle.material);
        await control.setStyle(DesignStyle.winui);
        expect(
          container.read(themeControllerProvider).style,
          DesignStyle.material,
        );
        expect(prefs.getString(ThemeController.styleKey), 'material');
      },
    );
  }
}
