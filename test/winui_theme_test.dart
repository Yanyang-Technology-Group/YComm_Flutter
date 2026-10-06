import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/design/winui_theme.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

List<Color> _brandRoles(ColorScheme scheme) => [
  scheme.primary,
  scheme.onPrimary,
  scheme.primaryContainer,
  scheme.onPrimaryContainer,
  scheme.secondary,
  scheme.onSecondary,
  scheme.secondaryContainer,
  scheme.onSecondaryContainer,
  scheme.tertiary,
  scheme.onTertiary,
  scheme.tertiaryContainer,
  scheme.onTertiaryContainer,
  scheme.inversePrimary,
];

List<Color> _tokenColours(WinuiTokens tokens) => [
  tokens.canvas,
  tokens.card,
  tokens.elevated,
  tokens.control,
  tokens.stroke,
  tokens.hover,
  tokens.pressed,
  tokens.focus,
];

void main() {
  group('WinUI colour roles', () {
    for (final brightness in Brightness.values) {
      for (final colour in ThemeColour.values) {
        test('${brightness.name}/${colour.id} preserves every brand role', () {
          final scheme = buildWinuiTheme(colour, brightness).colorScheme;
          final original = buildColorScheme(colour, brightness);
          expect(_brandRoles(scheme), _brandRoles(original));
          expect(scheme.error, original.error);
          expect(scheme.onError, original.onError);
          expect(scheme.surfaceTint, Colors.transparent);
        });
      }

      test('${brightness.name} has neutral surfaces and readable labels', () {
        final theme = buildWinuiTheme(ThemeColour.red, brightness);
        final tokens = theme.extension<WinuiTokens>()!;
        final scheme = theme.colorScheme;
        for (final color in [
          ..._tokenColours(tokens),
          scheme.onSurface,
          scheme.onSurfaceVariant,
          scheme.outline,
          scheme.inverseSurface,
        ]) {
          expect(color.r, color.g, reason: 'Expected neutral role: $color');
          expect(color.g, color.b, reason: 'Expected neutral role: $color');
        }
        for (final background in [
          tokens.canvas,
          tokens.card,
          tokens.elevated,
          tokens.control,
        ]) {
          expect(
            _contrast(scheme.onSurface, background),
            greaterThanOrEqualTo(7),
          );
          expect(
            _contrast(scheme.onSurfaceVariant, background),
            greaterThanOrEqualTo(4.5),
          );
          expect(_contrast(tokens.focus, background), greaterThanOrEqualTo(7));
        }
        expect(theme.scaffoldBackgroundColor, tokens.canvas);
        expect(theme.cardTheme.color, tokens.card);
        expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
        expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
        expect(
          theme.menuTheme.style!.surfaceTintColor!.resolve({}),
          Colors.transparent,
        );
        expect(theme.popupMenuTheme.surfaceTintColor, Colors.transparent);
        expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
      });
    }

    test('light and dark canvases retain distinct Fluent levels', () {
      final light = WinuiTokens.of(Brightness.light);
      final dark = WinuiTokens.of(Brightness.dark);
      expect(light.canvas, const Color(0xFFF3F3F3));
      expect(dark.canvas, const Color(0xFF202020));
      expect(
        light.canvas.computeLuminance(),
        lessThan(light.card.computeLuminance()),
      );
      expect(
        dark.canvas.computeLuminance(),
        lessThan(dark.card.computeLuminance()),
      );
      expect(light.isDark, isFalse);
      expect(dark.isDark, isTrue);
    });
  });

  test(
    'Segoe and CJK fallback apply to absolute and inherited text styles',
    () {
      final theme = buildWinuiTheme(ThemeColour.azure, Brightness.light);
      for (final style in [
        theme.textTheme.headlineLarge,
        theme.textTheme.titleLarge,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.bodySmall,
        theme.textTheme.labelLarge,
        theme.primaryTextTheme.bodyMedium,
        theme.appBarTheme.titleTextStyle,
        theme.filledButtonTheme.style!.textStyle!.resolve({}),
        theme.listTileTheme.titleTextStyle,
        theme.dialogTheme.contentTextStyle,
        theme.popupMenuTheme.textStyle,
        theme.tooltipTheme.textStyle,
      ]) {
        expect(style!.fontFamily, 'Segoe UI Variable');
        expect(style.fontFamilyFallback, winuiFontFallback);
        expect(
          style.fontFamilyFallback,
          containsAllInOrder([
            'Segoe UI',
            'Microsoft YaHei UI',
            'Microsoft YaHei',
          ]),
        );
      }
    },
  );

  test(
    'controls have rectangular shapes and distinct keyboard focus borders',
    () {
      for (final brightness in Brightness.values) {
        final theme = buildWinuiTheme(ThemeColour.orange, brightness);
        final tokens = theme.extension<WinuiTokens>()!;
        for (final button in [
          theme.filledButtonTheme.style!,
          theme.elevatedButtonTheme.style!,
          theme.outlinedButtonTheme.style!,
          theme.textButtonTheme.style!,
        ]) {
          final shape = button.shape!.resolve({})! as RoundedRectangleBorder;
          expect(shape.borderRadius, BorderRadius.circular(4));
          expect(button.minimumSize!.resolve({})!.height, 32);
          expect(button.tapTargetSize, MaterialTapTargetSize.padded);
          final focused = button.side!.resolve({WidgetState.focused})!;
          expect(focused.width, 2);
          expect(focused.color, tokens.focus);
          expect(
            button.side!.resolve({WidgetState.disabled})!.width,
            lessThan(2),
          );
        }
        final focusedInput =
            theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
        expect(focusedInput.borderRadius, BorderRadius.circular(4));
        expect(
          focusedInput.borderSide,
          BorderSide(color: tokens.focus, width: 2),
        );
        final card = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(card.borderRadius, BorderRadius.circular(8));
        expect(card.side.color, tokens.stroke);
        expect(card.side.width, 1);
        expect(
          theme.checkboxTheme.materialTapTargetSize,
          MaterialTapTargetSize.padded,
        );
        expect(
          theme.switchTheme.materialTapTargetSize,
          MaterialTapTargetSize.padded,
        );
      }
    },
  );

  test(
    'theme extensions interpolate every surface role without losing the marker',
    () {
      final light = WinuiTokens.of(Brightness.light);
      final dark = WinuiTokens.of(Brightness.dark);
      final middle = light.lerp(dark, 0.5);
      final lightColours = _tokenColours(light);
      final darkColours = _tokenColours(dark);
      final middleColours = _tokenColours(middle);
      for (var i = 0; i < lightColours.length; i++) {
        expect(
          middleColours[i],
          Color.lerp(lightColours[i], darkColours[i], 0.5),
        );
      }
      expect(_tokenColours(light.lerp(dark, 0)), lightColours);
      expect(_tokenColours(light.lerp(dark, 1)), darkColours);
      expect(light.lerp(dark, 0.49).brightness, Brightness.light);
      expect(middle.brightness, Brightness.dark);
      expect(light.lerp(null, 0.5), same(light));
      expect(light.copyWith(canvas: Colors.black).canvas, Colors.black);
      expect(light.canvas, const Color(0xFFF3F3F3));
      final theme = ThemeData.lerp(
        buildWinuiTheme(ThemeColour.azure, Brightness.light),
        buildWinuiTheme(ThemeColour.azure, Brightness.dark),
        0.5,
      );
      expect(theme.extension<WinuiTokens>()!.canvas, middle.canvas);
    },
  );

  testWidgets(
    'theme marker distinguishes WinUI from the existing Material theme',
    (tester) async {
      WinuiTokens? tokens;
      bool? active;
      Widget app(ThemeData theme) => MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            tokens = winuiTokensOf(context);
            active = isWinui(context);
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(
        app(buildWinuiTheme(ThemeColour.azure, Brightness.light)),
      );
      expect(active, isTrue);
      expect(tokens!.canvas, const Color(0xFFF3F3F3));
      await tester.pumpWidget(
        app(buildTheme(ThemeColour.azure, Brightness.light)),
      );
      await tester.pumpAndSettle();
      expect(active, isFalse);
      expect(tokens, isNull);
    },
  );

  testWidgets(
    'compact button keeps its accessible hit area outside the painted control',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildWinuiTheme(ThemeColour.azure, Brightness.light),
          home: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('发布'),
              ),
            ),
          ),
        ),
      );
      final button = find.byType(FilledButton);
      final surface = find
          .descendant(of: button, matching: find.byType(Material))
          .first;
      expect(tester.getSize(surface).height, 32);
      expect(tester.getSize(button).height, 48);
      final point =
          tester.getTopLeft(button) +
          Offset(tester.getSize(button).width / 2, 2);
      await tester.tapAt(point);
      await tester.pump();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
