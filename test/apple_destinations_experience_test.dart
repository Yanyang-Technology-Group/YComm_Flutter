import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/design/adaptive.dart';
import 'package:ycomm_client/core/design/apple_app.dart';
import 'package:ycomm_client/core/design/apple_theme.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/features/downloads/downloads_page.dart';
import 'package:ycomm_client/features/downloads/resource_tile.dart';
import 'package:ycomm_client/features/downloads/resource_page.dart';
import 'package:ycomm_client/features/profile/profile_page.dart';
import 'package:ycomm_client/features/profile/settings_page.dart';
import 'package:ycomm_client/features/profile/appearance_page.dart';

import 'package:ycomm_client/features/notifications/notifications_page.dart';

import 'card_directory_test.dart' show CardApi;

class InboxApi extends CardApi {
  bool readAll = false;
  @override
  Future<List<Json>> notifications() async => [
    {
      'key': 'new',
      'title': '新的回复',
      'body': '讨论里有一条新的回复',
      'unreadCount': readAll ? 0 : 1,
    },
    {'key': 'old', 'title': '先前的回复', 'unreadCount': 0},
  ];
  @override
  Future<Json> post(String path, [Json? body]) async {
    if (path == '/notifications/read') readAll = true;
    return super.post(path, body);
  }
}

class LeafDirectoryApi extends CardApi {
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/downloads/cards') {
      return {
        'cards': [
          {
            'id': 'leaf',
            'parentId': null,
            'kind': 'container',
            'title': '文件集合',
          },
        ],
      };
    }
    if (path == '/downloads/resources') {
      return {
        'total': 20,
        'resources': List.generate(
          20,
          (index) => {'id': 'r$index', 'title': '资源 $index'},
        ),
      };
    }
    if (path.startsWith('/downloads/resources/')) {
      return {
        'resource': {
          'id': path.split('/').last,
          'title': '资源详情',
          'description': '说明',
        },
      };
    }
    return super.get(path, query: query);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> mount(WidgetTester tester, Widget page, {CardApi? api}) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api ?? CardApi())],
        child: AppleApp(
          theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AppScaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Apple directory pushes and returns with one scrolling navigation',
    (tester) async {
      await mount(tester, const DownloadsPage());
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
      await tester.tap(find.text('工具目录'));
      await tester.pumpAndSettle();
      expect(find.text('下载文件'), findsOneWidget);
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      expect(find.text('工具目录'), findsOneWidget);
      await tester.tap(find.text('社区分享'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Apple leaf directory can return to its parent', (tester) async {
    await mount(tester, const DownloadsPage(), api: LeafDirectoryApi());
    await tester.tap(find.text('文件集合'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.text('社区分享'), findsOneWidget);
  });

  for (final directory in [true, false]) {
    testWidgets(
      'Apple resources preserve reading position, directory=$directory',
      (tester) async {
        await mount(tester, const DownloadsPage(), api: LeafDirectoryApi());
        await tester.tap(find.text(directory ? '文件集合' : '社区分享'));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -800),
        );
        await tester.pumpAndSettle();
        double offset() => tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels;
        final before = offset();
        await tester.tap(find.byType(ResourceTile).hitTestable().first);
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(ResourcePage))).pop();
        await tester.pumpAndSettle();
        expect(offset(), closeTo(before, 1));
      },
    );
  }

  testWidgets('Apple account reaches grouped preferences at large text', (
    tester,
  ) async {
    await mount(tester, const ProfilePage());
    expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    await tester.scrollUntilVisible(find.text('设置'), 300);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    await tester.tap(find.text('外观与主题'));
    await tester.pumpAndSettle();
    expect(find.byType(AppearancePage), findsOneWidget);
    expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    await tester.scrollUntilVisible(find.text('深色模式'), 400);
    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Apple inbox filters unread and keeps mark-all available after scroll',
    (tester) async {
      final api = InboxApi()..signedIn = true;
      await mount(tester, const NotificationsPage(), api: api);
      expect(find.text('先前的回复'), findsOneWidget);
      await tester.tap(find.text('未读 · 1'));
      await tester.pumpAndSettle();
      expect(find.text('先前的回复'), findsNothing);
      expect(find.text('新的回复'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('全部标记为已读'));
      await tester.pumpAndSettle();
      expect(api.readAll, isTrue);
      expect(find.text('暂无未读消息'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
