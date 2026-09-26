import 'package:ycomm_client/core/state/session.dart';
import 'package:ycomm_client/core/design/apple_app.dart';

// Apple 风格的渲染审阅通道。与 visual_review_test.dart 共用同一份公开接口快照，
// 只换主题与风格，用来把两种风格并排比对。
//
// 运行（Linux 已装 Noto CJK）：
//   flutter test test/apple_visual_review_test.dart --dart-define=VISUAL_REVIEW=true
// 输出到 build/design-review/apple-*.png
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/design/apple_theme.dart';
import 'package:ycomm_client/core/design/design_style.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/core/theme/theme_controller.dart';
import 'package:ycomm_client/features/profile/appearance_page.dart';
import 'package:ycomm_client/features/profile/settings_page.dart';
import 'package:ycomm_client/features/auth/login_page.dart';
import 'package:ycomm_client/main.dart';
import 'package:ycomm_client/features/forum/forum_page.dart';
import 'package:ycomm_client/features/forum/topic_page.dart';

class SnapshotApi extends CommunityApi {
  SnapshotApi(this.snapshot);
  final Json snapshot;
  bool signedIn = false;
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/auth/me') {
      if (signedIn) {
        return {
          'user': {
            'id': 'u1',
            'username': 'xiaobai',
            'displayName': '小白',
            'state': 'active',
            'role': 'member',
          },
        };
      }
      throw const RequestFailure('请登录', 'UNAUTHENTICATED');
    }
    if (signedIn && path == '/forum/boards') {
      return {
        'boards': [
          {'id': 'b1', 'slug': 'general', 'name': '综合交流'},
          {'id': 'b2', 'slug': 'help', 'name': '问答互助'},
          {'id': 'b3', 'slug': 'share', 'name': '作品分享'},
          {'id': 'b4', 'slug': 'feedback', 'name': '建议与反馈'},
        ],
      };
    }
    if (signedIn &&
        path.startsWith('/forum/boards/') &&
        path.endsWith('/topics')) {
      return Json.from(
        snapshot.entries
            .firstWhere(
              (e) =>
                  e.key.startsWith('/forum/boards/') &&
                  e.key.endsWith('/topics'),
            )
            .value['data'],
      );
    }
    // Representative offline content for reading and inbox visual review.
    if (signedIn && path == '/notifications') {
      return {
        'groups': [
          {
            'key': 'reply',
            'title': '你的讨论有了新回复',
            'body': '期待听到更多使用体验，欢迎继续交流。',
            'unreadCount': 2,
            'latestAt': '2026-09-26T02:30:00Z',
            'actors': [
              {'displayName': '林'},
            ],
          },
          {
            'key': 'resource',
            'title': '资源更新',
            'body': '你关注的资源发布了新的版本。',
            'unreadCount': 0,
            'latestAt': '2026-09-25T09:00:00Z',
          },
        ],
      };
    }
    if (signedIn && path.startsWith('/forum/topics/')) {
      return {
        'topic': {
          'id': path.split('/').last,
          'title': '一起聊聊社区的使用体验',
          'author_id': 'u1',
          'board_id': 'b1',
          'created_at': '2026-09-26T01:00:00Z',
          'view_count': 128,
        },
        'posts': [
          {
            'id': 'p1',
            'position': 1,
            'author_id': 'u1',
            'authorDisplayName': '小白',
            'created_at': '2026-09-26T01:00:00Z',
            'content_md': '希望阅读讨论时，能更自然地找到内容、参与交流。\n\n大家平时最常使用社区里的哪些功能？',
          },
          {
            'id': 'p2',
            'position': 2,
            'authorDisplayName': '林',
            'created_at': '2026-09-26T02:30:00Z',
            'content_md': '我最常浏览讨论和资源。看完一条讨论返回后，能接着刚才的位置继续读，会很方便。',
          },
        ],
        'likedPostIds': [],
      };
    }
    if (path.startsWith('/users/')) return {'profile': {}};
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
  testWidgets('render Apple style designs for visual inspection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 中文字形：Apple 风格的字栈里 Noto Sans CJK SC 是 Linux 上的第一顺位，
    // 所以按这个名字注册，才能真的走到与运行时一致的字体。
    final cjk = File('/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc')
        .readAsBytesSync();
    for (final family in ['Noto Sans CJK SC', 'Roboto']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(cjk)));
      await loader.load();
    }
    final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await icons.load();

    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);

    final snapshot = Json.from(
      jsonDecode(File('test/fixtures/public_snapshot.json').readAsStringSync()),
    );
    final key = GlobalKey();
    final api = SnapshotApi(snapshot);
    final container = ProviderContainer(
      overrides: [communityProvider.overrideWithValue(api)],
    );

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
        (File('build/design-review/$name.png')
              ..parent.createSync(recursive: true))
            .writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    Future<void> captureMotion(String name, int frameCount) async {
      for (var i = 0; i < frameCount; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await boundary.toImage(pixelRatio: 1);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          (File(
            'build/design-review/motion/$name-${i.toString().padLeft(2, '0')}.png',
          )..parent.createSync(recursive: true)).writeAsBytesSync(
            png!.buffer.asUint8List(),
          );
          img.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    }

    // 切到 Apple 风格。setStyle 会写 prefs，这里本来就是一次性的测试容器。
    await container
        .read(themeControllerProvider.notifier)
        .setStyle(DesignStyle.apple);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: key, child: const YCommApp()),
      ),
    );
    await capture('apple-01-community');
    await tester.tap(find.text('资源').last);
    await capture('apple-02-resources');
    await tester.tap(find.text('消息').last);
    await capture('apple-03-inbox');
    await tester.tap(find.text('我的').last);
    await capture('apple-04-profile');

    // 辅助路由用同一套生产主题单独渲染。
    Future<void> page(
      Widget page, {
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: key,
            child: AppleApp(
              theme: buildAppleTheme(ThemeColour.azure, brightness),
              home: page,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await page(const AppearancePage());
    await capture('apple-05-appearance');
    await page(const SettingsPage());
    await capture('apple-06-settings');
    await page(const LoginPage());
    await capture('apple-07-login');

    // 深色
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
    await capture('apple-08-community-dark');
    await tester.tap(find.text('我的').last);
    await capture('apple-09-profile-dark');

    // Keep this fixture offline: the root shell normally connects its socket
    // when a session becomes available. Inactive lifecycle suspends that work.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    api.signedIn = true;
    await container.read(sessionProvider.notifier).refresh();
    await container
        .read(themeControllerProvider.notifier)
        .setMode(ThemeModePreference.light);
    await capture('apple-10-profile-signed-in');
    await tester.tap(find.text('社区').last);
    await capture('apple-11-community-signed-in');
    await tester.tap(find.byTooltip('发起讨论'));
    await tester.pump();
    await captureMotion('compose-open', 16);
    await capture('apple-16-compose');
    await tester.tap(find.text('取消'));
    await tester.pump();
    await captureMotion('compose-close', 16);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TopicTile).first);
    await capture('apple-17-discussion');
    await tester.tap(find.bySemanticsLabel('管理讨论'));
    await tester.pump();
    await captureMotion('actions-open', 12);
    await capture('apple-18-context-menu');
    await tester.tapAt(const Offset(8, 600));
    await tester.pump();
    await captureMotion('actions-close', 12);
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(TopicPage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('消息').last);
    await capture('apple-19-inbox-signed-in');
    await tester.tap(find.text('社区').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apple-board-picker')));
    await capture('apple-12-board-menu');
    await tester.tapAt(const Offset(8, 600));
    await tester.pumpAndSettle();
    await container
        .read(themeControllerProvider.notifier)
        .setMode(ThemeModePreference.dark);
    await tester.tap(find.byKey(const ValueKey('apple-board-picker')));
    await capture('apple-13-board-menu-dark');
    await tester.tapAt(const Offset(8, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的').last);
    await capture('apple-14-profile-signed-in-dark');
    tester.view.physicalSize = const Size(1024, 800);
    await capture('apple-15-profile-desktop');
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    debugDisableShadows = true;
  }, skip: !const bool.fromEnvironment('VISUAL_REVIEW'));
}
