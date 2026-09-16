import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/features/downloads/resource_page.dart';

class ResourceApi extends CommunityApi {
  final withdraw = Completer<Json>();
  final calls = <String>[];

  @override
  Future<Json> get(String path, {Json? query}) async {
    calls.add(path);
    if (path == '/auth/me') {
      return {
        'user': {'id': 'author', 'role': 'member', 'state': 'active'},
      };
    }
    if (path.endsWith('/extract-code')) return {'extractCode': 'CODE'};
    return {
      'resource': {
        'id': 'resource1',
        'authorId': 'author',
        'title': '测试资源',
        'summary': '摘要',
        'descriptionMd': '说明',
        'sourceType': 'external',
        'status': 'published',
      },
    };
  }

  @override
  Future<Json> post(String path, [Json? data]) {
    calls.add(path);
    return withdraw.future;
  }
}

Future<ResourceApi> pumpResource(
  WidgetTester tester, {
  VoidCallback? onChanged,
}) async {
  final api = ResourceApi();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityProvider.overrideWithValue(api)],
      child: MaterialApp(
        home: ResourcePage(id: 'resource1', onChanged: onChanged),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('withdraw cancellation sends no request', (tester) async {
    final api = await pumpResource(tester);

    final withdrawButton = find.widgetWithText(TextButton, '撤回资源');
    await tester.ensureVisible(withdrawButton);
    await tester.pumpAndSettle();
    await tester.tap(withdrawButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(api.calls.where((p) => p.endsWith('/withdraw')), isEmpty);
    expect(find.text('获取资源'), findsOneWidget);
  });

  testWidgets('pending and completed withdrawal prevent resource access', (
    tester,
  ) async {
    var changes = 0;
    final api = await pumpResource(tester, onChanged: () => changes++);

    final withdrawButton = find.widgetWithText(TextButton, '撤回资源');
    await tester.ensureVisible(withdrawButton);
    await tester.pumpAndSettle();
    await tester.tap(withdrawButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '撤回资源'),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '获取资源'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '复制提取码'))
          .onPressed,
      isNull,
    );
    expect(api.calls.where((p) => p.endsWith('/extract-code')), isEmpty);

    api.withdraw.complete({});
    await tester.pumpAndSettle();

    expect(changes, 1);
    expect(find.text('获取资源'), findsNothing);
    expect(find.text('复制提取码'), findsNothing);
    expect(find.text('资源已撤回'), findsWidgets);
  });
}
