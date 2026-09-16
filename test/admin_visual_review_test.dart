import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/state/session.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/features/admin/admin_page.dart';
import 'package:ycomm_client/features/admin/admin_users_page.dart';
import 'package:ycomm_client/features/admin/moderation_page.dart';

import 'fixtures/admin_fixture.dart';

void main() {
  testWidgets('render management screenshots', (tester) async {
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Roboto')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc')
                .readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final directory = Directory('build/admin-review')
      ..createSync(recursive: true);
    final container = ProviderContainer(
      overrides: [communityProvider.overrideWithValue(AdminFixtureApi())],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.notifier).refresh();
    for (final scenario in [
      ('phone-light', const Size(390, 844), Brightness.light, 1.0),
      ('phone-dark', const Size(390, 844), Brightness.dark, 1.0),
      ('small-large-text', const Size(320, 740), Brightness.light, 1.8),
      ('tablet', const Size(1024, 768), Brightness.light, 1.0),
      ('landscape', const Size(844, 390), Brightness.dark, 1.8),
    ]) {
      tester.view.physicalSize = scenario.$2;
      for (final entry in <String, Widget>{
        'dashboard': const AdminDashboardPage(),
        'moderation': const ModerationDetailPage(item: reviewItem),
        'users': const AdminUsersPage(),
        'user-detail': const AdminUserDetailPage(user: managedUser),
      }.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                key: UniqueKey(),
                debugShowCheckedModeBanner: false,
                theme: buildTheme(ThemeColour.azure, scenario.$3),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scenario.$4)),
                  child: child!,
                ),
                home: entry.value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final bitmap = await boundary.toImage(pixelRatio: 1.5);
          final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          File('${directory.path}/${scenario.$1}-${entry.key}.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          bitmap.dispose();
        });
      }
    }
    debugDisableShadows = true;
  }, skip: !const bool.fromEnvironment('ADMIN_VISUAL_REVIEW'));
}
