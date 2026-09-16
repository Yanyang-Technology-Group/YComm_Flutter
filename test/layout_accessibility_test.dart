import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/features/profile/appearance_page.dart';
import 'package:ycomm_client/features/profile/about_page.dart';
import 'package:ycomm_client/features/auth/login_page.dart';
import 'package:ycomm_client/features/auth/register_page.dart';
import 'package:ycomm_client/features/downloads/downloads_page.dart';
import 'package:ycomm_client/features/forum/forum_page.dart';
import 'package:ycomm_client/features/profile/profile_page.dart';

import 'widget_test.dart' show TestApi;

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('phone width $width supports dark mode and 1.8x text', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final page in <Widget>[
        const ForumPage(),
        const DownloadsPage(),
        const ProfilePage(),
        const AppearancePage(),
        const AboutPage(),
        const LoginPage(),
        const RegisterPage(),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [communityProvider.overrideWithValue(TestApi())],
            child: MaterialApp(
              theme: buildTheme(ThemeColour.pink, Brightness.dark),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Scaffold(body: page),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$page initial layout');
        final list = find.byType(ListView).first;
        if (list.evaluate().isNotEmpty) {
          await tester.drag(list, const Offset(0, -450));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$page scrolled layout',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });
  }
}
