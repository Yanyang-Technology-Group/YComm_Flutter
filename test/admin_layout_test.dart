import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/features/admin/admin_page.dart';
import 'package:ycomm_client/features/admin/admin_catalog_pages.dart';
import 'package:ycomm_client/features/admin/admin_system_pages.dart';
import 'package:ycomm_client/features/admin/admin_users_page.dart';
import 'package:ycomm_client/features/admin/moderation_page.dart';

import 'fixtures/admin_fixture.dart';

void main() {
  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(1024, 768),
    const Size(844, 390),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('admin pages at $size, $brightness, 1.8x text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final page in <Widget>[
          const AdminDashboardPage(),
          const ModerationPage(),
          const ModerationDetailPage(item: reviewItem),
          const AdminUsersPage(),
          const AdminUserDetailPage(user: managedUser),
          const AdminResourcesPage(),
          const AdminBoardsPage(),
          const AdminCardsPage(),
          const AdminBadgesPage(),
          const AdminInvitesPage(),
          const AdminAuditPage(),
          const AdminSettingsPage(),
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                communityProvider.overrideWithValue(AdminFixtureApi()),
              ],
              child: MaterialApp(
                theme: buildTheme(ThemeColour.azure, brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.8),
                    disableAnimations: true,
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                  ),
                  child: child!,
                ),
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$page initial layout',
          );
          final list = find.byType(ListView);
          if (list.evaluate().isNotEmpty) {
            for (var i = 0; i < 4; i++) {
              await tester.drag(list.first, Offset(0, -size.height * .65));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$page scrolled layout',
              );
            }
          }
        }
      });
    }
  }
}
