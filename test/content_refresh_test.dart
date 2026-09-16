import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/features/downloads/card_directory.dart';
import 'package:ycomm_client/features/downloads/downloads_page.dart';
import 'package:ycomm_client/features/search/search_page.dart';

class RefreshApi extends CommunityApi {
  final calls = <String>[];

  int count(String path) => calls.where((p) => p == path).length;

  @override
  Future<Json> get(String path, {Json? query}) async {
    calls.add(path);
    if (path == '/auth/me') return {'user': null};
    if (path == '/downloads/categories') return {'categories': []};
    if (path == '/downloads/cards') {
      return {
        'cards': [
          {
            'id': 'leaf',
            'parentId': null,
            'title': '资源目录',
            'kind': 'resources',
          },
        ],
      };
    }
    if (path == '/downloads/resources') {
      return {
        'resources': [
          {
            'id': 'resource1',
            'title': '列表资源',
            'summary': '摘要',
            'sourceType': 'external',
            'status': 'published',
          },
        ],
        'total': 1,
      };
    }
    if (path == '/downloads/resources/resource1') {
      return {
        'resource': {
          'id': 'resource1',
          'title': '列表资源',
          'summary': '摘要',
          'descriptionMd': '说明',
          'sourceType': 'external',
          'status': 'published',
        },
      };
    }
    if (path == '/forum/search') {
      return {
        'topics': [
          {'id': 'topic1', 'title': '搜索结果', 'authorDisplayName': '作者'},
        ],
      };
    }
    return {
      'topic': {
        'id': 'topic1',
        'title': '搜索结果',
        'author_id': 'author',
        'board_id': 'board',
        'is_locked': false,
        'is_pinned': false,
      },
      'posts': const [],
      'likedPostIds': const [],
    };
  }
}

Future<RefreshApi> pump(WidgetTester tester, Widget page) async {
  final api = RefreshApi();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityProvider.overrideWithValue(api)],
      child: MaterialApp(home: Scaffold(body: page)),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('downloads refresh after returning from a resource', (
    tester,
  ) async {
    final api = await pump(tester, const DownloadsPage());
    await tester.tap(find.text('社区分享'));
    await tester.pumpAndSettle();
    expect(api.count('/downloads/resources'), 1);

    await tester.tap(find.text('列表资源'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(api.count('/downloads/resources'), 2);
  });

  testWidgets('card resource feed refreshes after returning from detail', (
    tester,
  ) async {
    final api = await pump(tester, const CardDirectoryPage(id: 'leaf'));
    expect(api.count('/downloads/resources'), 1);

    await tester.tap(find.text('列表资源'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(api.count('/downloads/resources'), 2);
  });

  testWidgets('search reruns after returning from a topic', (tester) async {
    final api = await pump(tester, const SearchPage());
    await tester.enterText(find.byType(TextField), '关键字');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(api.count('/forum/search'), 1);

    await tester.tap(find.text('搜索结果'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(api.count('/forum/search'), 2);
  });
}
