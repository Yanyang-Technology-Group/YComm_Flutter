import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;
import 'package:ycomm_client/core/design/adaptive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/design/apple_app.dart';
import 'package:ycomm_client/core/design/apple_theme.dart';
import 'package:ycomm_client/core/design/apple_chrome.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';

void main() {
  testWidgets('iOS Reduce Motion removes press displacement immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppleApp(
        theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
        home: Center(
          child: PressableScale(
            onTap: () {},
            child: const SizedBox(width: 100, height: 50, child: Text('打开')),
          ),
        ),
      ),
    );
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    final press = await tester.startGesture(tester.getCenter(find.text('打开')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    final transforms = tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(PressableScale),
        matching: find.byType(Transform),
      ),
    );
    for (final transform in transforms) {
      expect(transform.transform.entry(0, 0), 1);
    }
    await press.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Apple action menu stays attached to its toolbar trigger', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppleApp(
        theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
        home: CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.topRight,
            child: AppPopupMenuButton<String>(
              child: const Text('操作'),
              itemBuilder: (_) => const [
                m.PopupMenuItem(value: 'copy', child: Text('复制链接')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('操作'));
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('复制链接')).dy, lessThan(200));
  });

  testWidgets('compact reading header begins below the navigation toolbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppleApp(
        theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
        home: const AppleScrollPage(
          title: '详情',
          largeTitle: false,
          slivers: [SliverToBoxAdapter(child: Text('正文标题'))],
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('正文标题')).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.byType(CupertinoNavigationBar)).dy,
      ),
    );
  });

  test('secondary reading text is legible on both content surfaces', () {
    for (final brightness in Brightness.values) {
      final theme = buildAppleTheme(ThemeColour.azure, brightness);
      final tokens = theme.extension<AppleTokens>()!;
      final foreground = Color.alphaBlend(
        tokens.secondaryLabel,
        tokens.cardBackground,
      );
      final a = foreground.computeLuminance();
      final b = tokens.cardBackground.computeLuminance();
      final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: brightness.name);
    }
  });
}
