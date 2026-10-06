import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/design/adaptive.dart';
import 'package:ycomm_client/core/design/winui_nav.dart';
import 'package:ycomm_client/core/design/winui_theme.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/features/profile/appearance_page.dart';
import 'package:ycomm_client/main.dart';

import 'widget_test.dart' show TestApi;

void main() {
  testWidgets(
    'Windows starts with WinUI and switches styles without losing the settings route',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [communityProvider.overrideWithValue(TestApi())],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const YCommApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WinuiNavigationPane>(find.byType(WinuiNavigationPane))
            .expanded,
        isTrue,
      );
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .extension<WinuiTokens>(),
        isNotNull,
      );
      final shell = tester.element(find.byType(AppShell));
      Navigator.of(shell)
          .push(appPageRoute(shell, builder: (_) => const AppearancePage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Material'));
      await tester.pumpAndSettle();
      expect(find.byType(AppearancePage), findsOneWidget);
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .extension<WinuiTokens>(),
        isNull,
      );
      await tester.ensureVisible(find.text('WinUI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WinUI'));
      await tester.pumpAndSettle();
      expect(find.byType(AppearancePage), findsOneWidget);
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .darkTheme!
            .extension<WinuiTokens>(),
        isNotNull,
      );
      Navigator.of(tester.element(find.byType(AppearancePage))).pop();
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(600, 700);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WinuiNavigationPane>(find.byType(WinuiNavigationPane))
            .expanded,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
    skip: kIsWeb,
  );
}
