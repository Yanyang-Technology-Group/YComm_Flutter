import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/features/search/search_page.dart';

class SearchApi extends CommunityApi {
  bool fail = false;
  Json? parameters;
  @override
  Future<Json> get(String path, {Json? query}) async {
    parameters = query;
    if (fail) throw const RequestFailure('搜索连接失败');
    return {
      'forum': [
        {
          'boardId': 'one',
          'topics': [
            {'id': 'a', 'title': '第一版块命中'},
          ],
        },
        {
          'boardId': 'two',
          'topics': [
            {'id': 'b', 'title': '第二版块命中'},
          ],
        },
      ],
      'users': [],
      'downloads': [],
    };
  }
}

void main() {
  testWidgets('search uses forum scope and reads topics from every board', (
    tester,
  ) async {
    final api = SearchApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: const MaterialApp(home: SearchPage()),
      ),
    );
    await tester.enterText(find.byType(TextField), '  关键字  ');
    await tester.tap(find.byTooltip('开始搜索'));
    await tester.pumpAndSettle();
    expect(api.parameters, {'q': '关键字', 'scope': 'forum'});
    expect(find.text('第一版块命中'), findsOneWidget);
    expect(find.text('第二版块命中'), findsOneWidget);
    api.fail = true;
    await tester.tap(find.byTooltip('开始搜索'));
    await tester.pumpAndSettle();
    expect(find.textContaining('搜索连接失败'), findsOneWidget);
    expect(find.text('没有找到相关讨论'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
