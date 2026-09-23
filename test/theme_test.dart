import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';

/// 颜色的色度（相邻通道最大差）。0 表示纯灰，也就是黑白。
int chroma(Color c) {
  final r = (c.r * 255).round();
  final g = (c.g * 255).round();
  final b = (c.b * 255).round();
  return math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
}

/// 会被主题色染色的角色。
List<Color> accents(ColorScheme s) => [
  s.primary,
  s.onPrimary,
  s.primaryContainer,
  s.onPrimaryContainer,
  s.secondary,
  s.secondaryContainer,
  s.tertiary,
  s.tertiaryContainer,
  s.surfaceTint,
  s.inversePrimary,
];

void main() {
  group('主题色与网站保持一致', () {
    test('中国红在晏阳蓝之后，取值是网站的 --accent', () {
      expect(ThemeColour.values[0], ThemeColour.azure);
      expect(ThemeColour.values[1], ThemeColour.red);
      expect(ThemeColour.red.label, '中国红');
      expect(ThemeColour.red.id, 'red');
      expect(ThemeColour.red.seed, const Color(0xFFFF0000));
    });

    test('其余主题的 seed 也等于网站浅色下的 --accent', () {
      expect(ThemeColour.azure.seed, const Color(0xFF5D94E8));
      expect(ThemeColour.pink.seed, const Color(0xFFF0899A));
      expect(ThemeColour.mint.seed, const Color(0xFF62B35C));
      expect(ThemeColour.orange.seed, const Color(0xFFEC8A2E));
      expect(ThemeColour.none.seed, const Color(0xFF7D848D));
    });

    test('老数据里存成 slate 的「无强调色」仍能读出来', () {
      expect(ThemeColour.fromId('slate'), ThemeColour.none);
      expect(ThemeColour.fromId('red'), ThemeColour.red);
      expect(ThemeColour.fromId('unknown'), ThemeColour.azure);
      expect(ThemeColour.fromId(null), ThemeColour.azure);
    });
  });

  group('无强调色必须是黑白，不能发蓝', () {
    for (final brightness in Brightness.values) {
      test('${brightness.name}：强调色全部无彩度', () {
        final scheme = buildTheme(ThemeColour.none, brightness).colorScheme;
        for (final c in accents(scheme)) {
          expect(chroma(c), 0, reason: '被染色的角色里有非灰颜色：$c');
        }
      });

      test('${brightness.name}：配色对齐网站 slate token', () {
        final scheme = buildTheme(ThemeColour.none, brightness).colorScheme;
        final dark = brightness == Brightness.dark;
        expect(scheme.surface, dark ? const Color(0xFF0D0E11) : const Color(0xFFF4F4F5));
        expect(
          scheme.surfaceContainerLowest,
          dark ? const Color(0xFF16171B) : Colors.white,
        );
        expect(scheme.onSurface, dark ? const Color(0xFFE5E6EA) : const Color(0xFF1F2226));
        expect(
          scheme.onSurfaceVariant,
          dark ? const Color(0xFF8E9198) : const Color(0xFF6D7178),
        );
      });
    }

    test('回归：直接 fromSeed(#7d848d) 是会发蓝的（所以才有上面的处理）', () {
      final naive = ColorScheme.fromSeed(
        seedColor: ThemeColour.none.seed,
        brightness: Brightness.light,
      );
      expect(chroma(naive.primary), greaterThan(50),
          reason: 'M3 tonalSpot 会放大种子的色度，这正是发蓝的原因');
    });
  });

  group('中国红必须是网站那支正红，不能像粉色', () {
    test('强调色直接用网站的三档取值', () {
      for (final brightness in Brightness.values) {
        final scheme = buildTheme(ThemeColour.red, brightness).colorScheme;
        final dark = brightness == Brightness.dark;
        expect(scheme.primary, dark ? const Color(0xFFFF3D3D) : const Color(0xFFFF0000));
        expect(
          scheme.primaryContainer,
          dark ? const Color(0xFF341111) : const Color(0xFFFFE9E9),
        );
        expect(
          scheme.onPrimaryContainer,
          dark ? const Color(0xFFFF7070) : const Color(0xFFCC0000),
        );
      }
    });

    test('回归：与猛男粉的主色必须能明显区分', () {
      for (final brightness in Brightness.values) {
        final red = buildTheme(ThemeColour.red, brightness).colorScheme.primary;
        final pink = buildTheme(ThemeColour.pink, brightness).colorScheme.primary;
        final distance =
            (red.r - pink.r).abs() + (red.g - pink.g).abs() + (red.b - pink.b).abs();
        expect(distance, greaterThan(0.15),
            reason: '两者太接近，用户分不清（红 $red / 粉 $pink）');
      }
    });

    test('回归：M3 直接生成的中国红确实会撞上粉色（所以要覆盖）', () {
      final naive = ColorScheme.fromSeed(
        seedColor: ThemeColour.red.seed,
        brightness: Brightness.light,
      );
      final pink = buildTheme(ThemeColour.pink, Brightness.light).colorScheme;
      final distance = (naive.primary.r - pink.primary.r).abs() +
          (naive.primary.g - pink.primary.g).abs() +
          (naive.primary.b - pink.primary.b).abs();
      expect(distance, lessThan(0.15), reason: '这正是当初看着像粉色的原因');
    });
  });
}
