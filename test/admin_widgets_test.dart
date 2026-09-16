import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/state/session.dart';
import 'package:ycomm_client/features/admin/admin_widgets.dart';
import 'package:ycomm_client/features/admin/admin_access.dart';

class AdminTestApi extends CommunityApi {
  Json user = {'id': 'staff', 'role': 'admin', 'state': 'active'};
  final List<int> offsets = [];
  RequestFailure? failure;
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/auth/me') return {'user': user};
    if (failure != null) throw failure!;
    final offset = query?['offset'] as int? ?? 0;
    offsets.add(offset);
    return {
      'items': offset == 0
          ? [
              {'id': 'one'},
              {'id': 'two'},
            ]
          : [
              {'id': 'three'},
            ],
    };
  }
}

void main() {
  for (final code in ['UNAUTHENTICATED', 'FORBIDDEN']) {
    testWidgets('$code shows permission feedback instead of an empty list', (
      tester,
    ) async {
      final api = AdminTestApi()..failure = RequestFailure('需要重新登录或检查权限', code);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [communityProvider.overrideWithValue(api)],
          child: MaterialApp(
            home: AdminPage(
              title: '审核',
              child: AdminCollection(
                path: '/admin/moderation',
                listKey: 'items',
                itemBuilder: (context, row, refresh) => Text(row['id']),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前无法访问'), findsOneWidget);
      expect(find.text('暂无内容'), findsNothing);
      api.failure = null;
      await tester.tap(find.text('重新检查'));
      await tester.pumpAndSettle();
      expect(find.text('one'), findsOneWidget);
    });
  }
  testWidgets('a collection without total loads following pages', (
    tester,
  ) async {
    final api = AdminTestApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: AdminPage(
            title: '审核',
            child: AdminCollection(
              path: '/admin/moderation',
              listKey: 'items',
              pageSize: 2,
              itemBuilder: (c, r, refresh) => Text(r['id']),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('one'), findsOneWidget);
    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();
    expect(find.text('three'), findsOneWidget);
    expect(api.offsets, [0, 2]);
    expect(find.text('加载更多'), findsNothing);
  });
  testWidgets(
    'switching staff identities removes previously visible sensitive content',
    (tester) async {
      final api = AdminTestApi();
      final container = ProviderContainer(
        overrides: [communityProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      await container.read(sessionProvider.notifier).refresh();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: AdminGuard(child: Text('private data'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('private data'), findsOneWidget);
      api.user = {'id': 'other', 'role': 'admin', 'state': 'active'};
      await container.read(sessionProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(find.text('private data'), findsNothing);
    },
  );
  testWidgets(
    'mutation failure keeps confirmation open and prevents duplicate requests',
    (tester) async {
      final api = AdminTestApi();
      final pending = Completer<void>();
      int calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [communityProvider.overrideWithValue(api)],
          child: MaterialApp(
            home: AdminPage(
              title: '测试',
              child: Builder(
                builder: (c) => TextButton(
                  onPressed: () => confirmAdminAction(
                    c,
                    title: '删除内容',
                    message: '确认删除',
                    onConfirm: () {
                      calls++;
                      return pending.future;
                    },
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pump();
      expect(calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.completeError(const RequestFailure('权限不足', 'FORBIDDEN'));
      await tester.pumpAndSettle();
      expect(find.text('权限不足'), findsOneWidget);
      expect(find.text('删除内容'), findsOneWidget);
    },
  );
}
