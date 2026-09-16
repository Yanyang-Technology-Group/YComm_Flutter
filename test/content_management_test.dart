import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/state/session.dart';
import 'package:ycomm_client/features/forum/my_posts_page.dart';
import 'package:ycomm_client/features/forum/topic_page.dart';

class ContentApi extends CommunityApi {
  Json user = {'id': 'author', 'role': 'admin', 'state': 'active'};
  Json topic = {
    'id': 'topic1',
    'title': '测试讨论',
    'author_id': 'author',
    'board_id': 'board1',
    'is_locked': false,
    'is_pinned': false,
    'created_at': '2026-09-16T08:00:00Z',
    'view_count': 1,
  };
  List<Json> posts = [
    {
      'id': 'post1',
      'topic_id': 'topic1',
      'author_id': 'author',
      'authorDisplayName': '作者',
      'content_md': '首帖正文',
      'status': 'published',
      'created_at': '2026-09-16T08:00:00Z',
    },
    {
      'id': 'post2',
      'topic_id': 'topic1',
      'author_id': 'other',
      'authorDisplayName': '回复者',
      'content_md': '第二条回复',
      'status': 'published',
      'created_at': '2026-09-16T09:00:00Z',
    },
  ];
  bool fail = false;
  final List<String> deleted = [];
  final List<Json> actions = [];
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/auth/me') return {'user': user};
    if (path == '/auth/me/posts') {
      return {
        'posts': [posts.first],
      };
    }
    if (path == '/forum/boards') {
      return {
        'boards': [
          {'id': 'board1', 'name': '原版块'},
          {'id': 'board2', 'name': '目标版块'},
        ],
      };
    }
    return {'topic': topic, 'posts': posts, 'likedPostIds': []};
  }

  @override
  Future<Json> delete(String path) async {
    deleted.add(path);
    if (fail) throw const RequestFailure('删除失败');
    posts = posts.where((p) => path != '/forum/posts/${p['id']}').toList();
    return {};
  }

  @override
  Future<Json> patch(String path, Json data) async {
    if (fail) throw const RequestFailure('保存失败');
    final index = posts.indexWhere((p) => path == '/forum/posts/${p['id']}');
    posts[index] = {...posts[index], 'content_md': data['content']};
    return {'post': posts[index]};
  }

  @override
  Future<Json> post(String path, [Json? data]) async {
    actions.add(data!);
    topic = {
      ...topic,
      if (data['action'] == 'lock') 'is_locked': true,
      if (data['action'] == 'unlock') 'is_locked': false,
      if (data['action'] == 'move') 'board_id': data['boardId'],
    };
    return {'topic': topic};
  }
}

Future<ProviderContainer> openContent(
  WidgetTester tester,
  ContentApi api, {
  Widget page = const TopicPage(id: 'topic1'),
}) async {
  final container = ProviderContainer(
    overrides: [communityProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => page)),
              child: const Text('进入'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('进入'));
  await tester.pumpAndSettle();
  return container;
}

Future<void> topicMenu(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('管理讨论'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('topic delete cancels without request then exits with a draft', (
    tester,
  ) async {
    final api = ContentApi();
    await openContent(tester, api);
    await tester.enterText(
      find.byKey(const ValueKey('reply-composer')),
      '未提交草稿',
    );
    await topicMenu(tester, '删除讨论');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.deleted, isEmpty);
    await topicMenu(tester, '删除讨论');
    await tester.tap(find.text('删除讨论'));
    await tester.pumpAndSettle();
    expect(api.deleted, ['/forum/topics/topic1']);
    expect(find.text('进入'), findsOneWidget);
    expect(find.text('放弃未发送的内容？'), findsNothing);
  });

  testWidgets('first reply can be deleted and failure keeps the content', (
    tester,
  ) async {
    final api = ContentApi()..fail = true;
    await openContent(tester, api);
    await tester.tap(find.byTooltip('管理回复').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除回复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除回复'));
    await tester.pumpAndSettle();
    expect(find.text('首帖正文'), findsOneWidget);
    expect(find.text('删除失败'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.byTooltip('管理回复').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除回复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除回复'));
    await tester.pumpAndSettle();
    expect(find.text('首帖正文'), findsNothing);
    expect(api.deleted, ['/forum/posts/post1', '/forum/posts/post1']);
  });

  testWidgets('reply edit failure retains the draft and can retry', (
    tester,
  ) async {
    final api = ContentApi()..fail = true;
    await openContent(tester, api);
    await tester.tap(find.byTooltip('管理回复').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑回复'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '修改后的正文',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('修改后的正文'), findsOneWidget);
    expect(find.text('保存失败'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('修改后的正文'), findsOneWidget);
  });

  testWidgets('lock unlock and move send their API payloads', (tester) async {
    final api = ContentApi();
    await openContent(tester, api);
    await topicMenu(tester, '锁定讨论');
    expect(find.text('已锁定'), findsOneWidget);
    await topicMenu(tester, '解锁讨论');
    expect(find.text('已锁定'), findsNothing);
    await topicMenu(tester, '移动版块');
    await tester.tap(find.text('目标版块'));
    await tester.pumpAndSettle();
    expect(api.actions, [
      {'action': 'lock'},
      {'action': 'unlock'},
      {'action': 'move', 'boardId': 'board2'},
    ]);
  });

  testWidgets('switching accounts invalidates an open delete confirmation', (
    tester,
  ) async {
    final api = ContentApi();
    final container = await openContent(tester, api);
    await topicMenu(tester, '删除讨论');
    api.user = {'id': 'new-admin', 'role': 'admin', 'state': 'active'};
    await container.read(sessionProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除讨论'));
    await tester.pumpAndSettle();
    expect(api.deleted, isEmpty);
    expect(find.text('测试讨论'), findsOneWidget);
  });

  testWidgets('my replies hide previous account content after switching', (
    tester,
  ) async {
    final api = ContentApi();
    final container = await openContent(tester, api, page: const MyPostsPage());
    expect(find.text('首帖正文'), findsOneWidget);
    api.user = {'id': 'new-admin', 'role': 'admin', 'state': 'active'};
    await container.read(sessionProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('首帖正文'), findsNothing);
    expect(find.byTooltip('管理回复'), findsNothing);
  });
}
