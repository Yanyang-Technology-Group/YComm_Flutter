import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/main.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/features/profile/appearance_page.dart';
import 'package:ycomm_client/features/auth/login_page.dart';
import 'package:ycomm_client/features/forum/compose_page.dart';

class TestApi extends CommunityApi {
  final calls = <String>[];
  bool fail = false;
  @override
  Future<Json> get(String path, {Json? query}) async {
    calls.add(path);
    if (fail) throw const RequestFailure('连接中断', 'NETWORK');
    if (path == '/auth/me') {
      throw const RequestFailure('请登录', 'UNAUTHENTICATED');
    }
    if (path == '/forum/boards') {
      return {
        'boards': [
          {
            'id': 'b1',
            'slug': 'actual-board',
            'name': '交流',
            'description': '一起分享想法',
          },
          {'id': 'b2', 'slug': 'second', 'name': '第二版块'},
        ],
      };
    }
    if (path.contains('/boards/')) {
      return {
        'total': 1,
        'topics': [
          {
            'id': 't1',
            'title': path.contains('second') ? '第二版块的内容' : '真实接口讨论',
            'authorUsername': 'member',
            'reply_count': 0,
            'view_count': 2,
            'preview': {
              'firstPost': {'contentExcerpt': '一段讨论内容'},
            },
          },
        ],
      };
    }
    if (path == '/forum/topics/t1') {
      return {
        'topic': {'id': 't1', 'title': '真实接口讨论', 'board_id': 'b1'},
        'posts': [
          {'id': 'p1', 'content_md': '正文内容', 'authorUsername': 'member'},
        ],
        'likedPostIds': [],
      };
    }
    if (path == '/forum/search') {
      return {
        'topics': [
          {'id': 't1', 'title': '搜索命中'},
        ],
      };
    }
    if (path == '/downloads/categories') return {'categories': []};
    if (path == '/downloads/resources') return {'resources': [], 'total': 0};
    return {};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> app(
    WidgetTester tester,
    TestApi api, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: const YCommApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'server board selects real slug; switching and topic detail work',
    (tester) async {
      final api = TestApi();
      await app(tester, api);
      expect(api.calls, contains('/forum/boards/actual-board/topics'));
      expect(api.calls.any((p) => p.contains('/general/')), isFalse);
      await tester.tap(find.text('第二版块'));
      await tester.pumpAndSettle();
      expect(find.text('第二版块的内容'), findsOneWidget);
      await tester.tap(find.text('交流'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('真实接口讨论'));
      await tester.pumpAndSettle();
      expect(find.text('正文内容'), findsOneWidget);
      await tester.tap(find.text('参与讨论'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('正文内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'tabs, empty resources, guest messages, appearance and persistence',
    (tester) async {
      final api = TestApi();
      await app(tester, api, size: const Size(360, 740));
      await tester.tap(find.text('资源').last);
      await tester.pumpAndSettle();
      expect(find.text('暂无目录'), findsOneWidget);
      await tester.tap(find.text('社区分享'));
      await tester.pumpAndSettle();
      expect(find.text('暂无资源'), findsOneWidget);
      await tester.tap(find.text('消息').last);
      await tester.pumpAndSettle();
      expect(find.text('登录查看'), findsOneWidget);
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('外观与主题'), 200);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -140));
      await tester.pumpAndSettle();
      await tester.tap(find.text('外观与主题'));
      await tester.pumpAndSettle();
      expect(find.byType(AppearancePage), findsOneWidget);
      await tester.scrollUntilVisible(find.text('猛男粉'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('猛男粉'));
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getString('ycomm_theme_colour'),
        'pink',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('API failure is an error with retry, never a false empty state', (
    tester,
  ) async {
    final api = TestApi()..fail = true;
    await app(tester, api);
    expect(find.text('暂时没有加载成功'), findsOneWidget);
    expect(find.text('暂无版块'), findsNothing);
    api.fail = false;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(find.text('真实接口讨论'), findsOneWidget);
  });
  testWidgets('search submits query and navigates to result', (tester) async {
    await app(tester, TestApi());
    await tester.tap(find.byTooltip('搜索讨论'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '测试');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('搜索命中'), findsOneWidget);
    await tester.tap(find.text('搜索命中'));
    await tester.pumpAndSettle();
    expect(find.text('正文内容'), findsOneWidget);
  });
  testWidgets('compose protects unsubmitted content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(TestApi())],
        child: MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute<void>(
                    builder: (_) => const ComposePage(
                      boards: [
                        {'slug': 'a', 'name': '交流'},
                      ],
                    ),
                  ),
                ),
                child: const Text('写'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('写'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '保留我的输入');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('离开编辑？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('保留我的输入'), findsOneWidget);
  });
}
