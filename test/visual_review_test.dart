// Rendering-only review harness. Uses a captured public API response, never demo data in the app.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/main.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/core/theme/theme_controller.dart';
import 'package:ycomm_client/features/profile/appearance_page.dart';
import 'package:ycomm_client/features/auth/login_page.dart';
import 'package:ycomm_client/features/auth/register_page.dart';

class SnapshotApi extends CommunityApi {
  SnapshotApi(this.snapshot);
  final Json snapshot;
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/auth/me') {
      throw const RequestFailure('请登录', 'UNAUTHENTICATED');
    }
    final response = Json.from(snapshot[path] ?? {});
    if (response['ok'] != true) {
      throw RequestFailure(
        response['error']?['message'] ?? '请登录后查看',
        response['error']?['code'],
      );
    }
    return Json.from(response['data'] ?? {});
  }
}

void main() {
  testWidgets('render phone designs for visual inspection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = File('/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc')
        .readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    final snapshot = Json.from(
      jsonDecode(File('test/fixtures/public_snapshot.json').readAsStringSync()),
    );
    final key = GlobalKey();
    final container = ProviderContainer(
      overrides: [communityProvider.overrideWithValue(SnapshotApi(snapshot))],
    );
    addTearDown(container.dispose);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/ycomm_mark.png'),
          key.currentContext!,
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('build/design-review/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: key, child: const YCommApp()),
      ),
    );
    await capture('01-community');
    await tester.tap(find.text('资源').last);
    await capture('02-resources');
    await tester.tap(find.text('消息').last);
    await capture('03-inbox');
    await tester.tap(find.text('我的').last);
    await capture('04-profile');
    // Render auxiliary routes directly with the same production theme.
    Future<void> page(
      Widget page, {
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(ThemeColour.azure, brightness),
              home: page,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await page(const AppearancePage());
    await capture('05-appearance');
    await page(const LoginPage());
    await capture('06-login');
    await page(const RegisterPage());
    await capture('07-register');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: key, child: const YCommApp()),
      ),
    );
    await tester.pumpAndSettle();
    await container
        .read(themeControllerProvider.notifier)
        .setMode(ThemeModePreference.dark);
    await capture('08-community-dark');
    debugDisableShadows = true;
  }, skip: !const bool.fromEnvironment('VISUAL_REVIEW'));
}
