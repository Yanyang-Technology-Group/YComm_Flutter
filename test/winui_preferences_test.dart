import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/design/design_style.dart';
import 'package:ycomm_client/core/theme/theme_controller.dart';
import 'package:ycomm_client/features/profile/appearance_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'WinUI support and defaults distinguish native Windows from browsers',
    () {
      for (final platform in TargetPlatform.values) {
        for (final web in [false, true]) {
          final supported = platform == TargetPlatform.windows && !web;
          final fallback = supported
              ? DesignStyle.winui
              : [TargetPlatform.iOS, TargetPlatform.macOS].contains(platform)
              ? DesignStyle.apple
              : DesignStyle.material;
          expect(
            DesignStyle.winui.isSupportedOn(platform: platform, isWeb: web),
            supported,
            reason: '$platform / web=$web',
          );
          final options = DesignStyle.supportedForPlatform(
            platform: platform,
            isWeb: web,
          );
          expect(options.contains(DesignStyle.winui), supported);
          expect(
            options,
            containsAll([DesignStyle.material, DesignStyle.apple]),
          );
          expect(
            DesignStyle.defaultForPlatform(platform: platform, isWeb: web),
            fallback,
          );
          expect(
            DesignStyle.resolve('winui', platform: platform, isWeb: web),
            fallback,
          );
          expect(
            DesignStyle.resolve(null, platform: platform, isWeb: web),
            fallback,
          );
          for (final style in [DesignStyle.material, DesignStyle.apple]) {
            expect(
              DesignStyle.resolve(style.id, platform: platform, isWeb: web),
              style,
            );
          }
          expect(
            DesignStyle.resolve('unknown', platform: platform, isWeb: web),
            DesignStyle.material,
          );
        }
      }
      expect(DesignStyle.fromId('winui'), DesignStyle.winui);
      expect(DesignStyle.fromId('unknown'), DesignStyle.material);
    },
  );

  for (final platform in TargetPlatform.values) {
    testWidgets('appearance offers WinUI only on native Windows ($platform)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AppearancePage()),
        ),
      );
      await tester.pumpAndSettle();
      final supported = platform == TargetPlatform.windows && !kIsWeb;
      expect(find.text('WinUI'), supported ? findsOneWidget : findsNothing);
      expect(find.text('Material'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      if (supported) {
        await tester.tap(find.text('Material'));
        await tester.pumpAndSettle();
        expect(
          container.read(themeControllerProvider).style,
          DesignStyle.material,
        );
        await tester.tap(find.text('WinUI'));
        await tester.pumpAndSettle();
        expect(
          container.read(themeControllerProvider).style,
          DesignStyle.winui,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(ThemeController.styleKey), 'winui');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
