import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/state/session.dart';
import 'package:ycomm_client/features/admin/admin_catalog_pages.dart';

class CatalogApi extends CommunityApi {
  final calls = <({String method, String path, Json? body})>[];
  String userId = 'owner';
  @override
  Future<Json> get(String path, {Json? query}) async {
    calls.add((method: 'GET', path: path, body: query));
    if (path == '/auth/me') {
      return {
        'user': {'id': userId, 'role': 'owner', 'state': 'active'},
      };
    }
    if (path == '/admin/boards') {
      return {
        'boards': [
          {
            'id': 'b/1',
            'slug': 'news',
            'name': '公告',
            'description': '站点公告',
            'sortOrder': 1,
            'visibility': 'public',
            'postingPolicy': 'staff',
            'archivedAt': null,
          },
          {
            'id': 'old',
            'slug': 'old',
            'name': '旧版块',
            'sortOrder': 2,
            'visibility': 'login',
            'postingPolicy': 'all',
            'archivedAt': '2026-01-01T00:00:00Z',
          },
        ],
      };
    }
    if (path == '/admin/cards') {
      return {
        'cards': [
          {
            'id': 'root',
            'parentId': null,
            'title': '根目录',
            'subtitle': '入口',
            'kind': 'container',
            'visibility': 'public',
            'position': 0,
            'w': 2,
            'h': 1,
            'status': 'approved',
          },
          {
            'id': 'child',
            'parentId': 'root',
            'title': '子目录',
            'kind': 'redirect',
            'redirectUrl': 'https://example.com',
            'visibility': 'login',
            'position': 0,
            'w': 1,
            'h': 1,
            'status': 'pending',
          },
        ],
      };
    }
    if (path == '/admin/badges') {
      return {
        'badges': [
          {
            'id': 'gold',
            'name': '金牌',
            'colorFrom': '#FFAA00',
            'colorTo': '#FF6600',
          },
        ],
      };
    }
    if (path == '/admin/invites') {
      return {
        'inviteCodes': [
          {
            'id': 'i/1',
            'name': '内测',
            'code': 'HELLO',
            'maxUses': 3,
            'usedCount': 1,
          },
        ],
      };
    }
    if (path == '/admin/invites/i%2F1/uses') {
      return {
        'users': [
          {
            'userId': 'u1',
            'username': 'alice',
            'displayName': '小艾',
            'role': 'member',
            'state': 'active',
            'usedAt': '2026-09-01T00:00:00Z',
          },
        ],
      };
    }
    return {};
  }

  @override
  Future<Json> post(String path, [Json? body]) async {
    calls.add((method: 'POST', path: path, body: body));
    return {};
  }

  @override
  Future<Json> patch(String path, Json body) async {
    calls.add((method: 'PATCH', path: path, body: body));
    return {};
  }

  @override
  Future<Json> delete(String path) async {
    calls.add((method: 'DELETE', path: path, body: null));
    return {};
  }
}

Future<CatalogApi> pumpPage(WidgetTester tester, Widget page) async {
  final api = CatalogApi();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityProvider.overrideWithValue(api)],
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets(
    'boards expose create, edit, archive and restore using documented endpoints',
    (tester) async {
      final api = await pumpPage(tester, const AdminBoardsPage());
      expect(find.text('公告'), findsOneWidget);
      expect(find.text('已归档'), findsOneWidget);
      await tester.tap(find.byTooltip('新建版块'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '标识'),
        'new-board',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '名称'), '新版块');
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '创建'));
      await tester.pumpAndSettle();
      expect(
        api.calls,
        contains(
          predicate<({String method, String path, Json? body})>(
            (c) =>
                c.method == 'POST' &&
                c.path == '/admin/boards' &&
                c.body?['slug'] == 'new-board',
          ),
        ),
      );
      await tester.tap(find.text('旧版块'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复版块'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复'));
      await tester.pumpAndSettle();
      expect(
        api.calls.any((c) => c.path == '/admin/boards/old/restore'),
        isTrue,
      );
    },
  );

  testWidgets('cards render hierarchy and owner can review pending card', (
    tester,
  ) async {
    final api = await pumpPage(tester, const AdminCardsPage());
    expect(find.text('根目录'), findsOneWidget);
    expect(find.text('子目录'), findsOneWidget);
    await tester.tap(find.text('子目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('通过审核'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();
    expect(
      api.calls.any(
        (c) =>
            c.path == '/admin/cards/child/review' &&
            c.body?['decision'] == 'approve',
      ),
      isTrue,
    );
  });

  testWidgets('new cards can select an existing card as parent', (
    tester,
  ) async {
    final api = await pumpPage(tester, const AdminCardsPage());
    await tester.tap(find.byTooltip('新建卡片'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('顶层'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('根目录').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '标题'), '新子卡片');
    await tester.fling(
      find.byType(ListView).last,
      const Offset(0, -1400),
      2000,
    );
    await tester.pumpAndSettle();
    final createButton = find.widgetWithText(FilledButton, '创建');
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(
      api.calls.any(
        (c) =>
            c.method == 'POST' &&
            c.path == '/admin/cards' &&
            c.body?['parentId'] == 'root',
      ),
      isTrue,
    );
  });

  testWidgets('editing a card can clear its optional subtitle', (tester) async {
    final api = await pumpPage(tester, const AdminCardsPage());
    await tester.tap(find.text('根目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑卡片'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('顶层'));
    await tester.pumpAndSettle();
    final parentOptions = find.byType(DropdownMenuItem<String>);
    expect(
      find.descendant(of: parentOptions, matching: find.text('根目录')),
      findsNothing,
    );
    expect(
      find.descendant(of: parentOptions, matching: find.text('子目录')),
      findsNothing,
    );
    await tester.tap(find.text('顶层').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '副标题'), '');
    await tester.fling(
      find.byType(ListView).last,
      const Offset(0, -1400),
      2000,
    );
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(FilledButton, '保存');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final update = api.calls.lastWhere(
      (c) => c.method == 'PATCH' && c.path == '/admin/cards/root',
    );
    expect(update.body, containsPair('subtitle', ''));
  });

  testWidgets('editing a board can clear its description', (tester) async {
    final api = await pumpPage(tester, const AdminBoardsPage());
    await tester.tap(find.text('公告'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑版块'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '说明'), '');
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final update = api.calls.lastWhere(
      (c) => c.method == 'PATCH' && c.path == '/admin/boards/b%2F1',
    );
    expect(update.body, containsPair('description', ''));
  });

  testWidgets('a card menu cannot open stale actions after account switch', (
    tester,
  ) async {
    final api = CatalogApi();
    final container = ProviderContainer(
      overrides: [communityProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AdminCardsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('根目录'));
    await tester.pumpAndSettle();
    api.userId = 'other-owner';
    await container.read(sessionProvider.notifier).refresh();
    await tester.tap(find.text('编辑卡片'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '保存'), findsNothing);
    expect(api.calls.where((c) => c.method != 'GET'), isEmpty);
  });

  testWidgets('a board menu cannot open stale actions after account switch', (
    tester,
  ) async {
    final api = CatalogApi();
    final container = ProviderContainer(
      overrides: [communityProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AdminBoardsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('公告'));
    await tester.pumpAndSettle();
    api.userId = 'other-owner';
    await container.read(sessionProvider.notifier).refresh();
    await tester.tap(find.text('编辑版块'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '保存'), findsNothing);
    expect(api.calls.where((c) => c.method != 'GET'), isEmpty);
  });

  testWidgets('badge creation validates and sends gradient colors', (
    tester,
  ) async {
    final api = await pumpPage(tester, const AdminBadgesPage());
    await tester.tap(find.byTooltip('新建徽章'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '贡献者');
    await tester.enterText(
      find.widgetWithText(TextFormField, '起始颜色'),
      '#112233',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '结束颜色'),
      '#445566',
    );
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(
      api.calls.any(
        (c) =>
            c.path == '/admin/badges' &&
            c.body?['colorFrom'] == '#112233' &&
            c.body?['colorTo'] == '#445566',
      ),
      isTrue,
    );
  });

  testWidgets('invite usage records load through escaped invite ID', (
    tester,
  ) async {
    final api = await pumpPage(tester, const AdminInvitesPage());
    expect(find.textContaining('1 / 3'), findsOneWidget);
    await tester.tap(find.text('内测'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用记录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('小艾'), findsOneWidget);
    expect(api.calls.any((c) => c.path == '/admin/invites/i%2F1/uses'), isTrue);
  });
}
