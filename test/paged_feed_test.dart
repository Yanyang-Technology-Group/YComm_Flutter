import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/widgets/paged_feed.dart';

class PagingApi extends CommunityApi {
  final offsets = <int>[];
  bool fail = false;
  @override
  Future<Json> get(String path, {Json? query}) async {
    final offset = query!['offset'] as int;
    offsets.add(offset);
    if (fail) throw const RequestFailure('刷新失败');
    return {
      'total': 2,
      'topics': [
        {'title': offset == 0 ? '第一条' : '第二条'},
      ],
    };
  }
}

void main() {
  testWidgets('pagination appends and failed refresh retries offset zero', (
    tester,
  ) async {
    final api = PagingApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: PagedFeed(
              path: '/topics',
              listKey: 'topics',
              emptyTitle: '空',
              emptyMessage: '空',
              itemBuilder: (t) => ListTile(title: Text(t['title'])),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续加载 · 1 / 2'));
    await tester.pumpAndSettle();
    expect(find.text('第二条'), findsOneWidget);
    expect(api.offsets, [0, 1]);
    api.fail = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('第一条'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(api.offsets, [0, 1, 0, 0]);
    expect(find.text('第二条'), findsNothing);
  });
}
