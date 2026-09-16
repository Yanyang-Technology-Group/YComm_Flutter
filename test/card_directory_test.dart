import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/features/downloads/downloads_page.dart';

import 'widget_test.dart' show TestApi;

class CardApi extends TestApi {
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/downloads/cards') {
      return {
        'cards': [
          {
            'id': 'root',
            'parentId': null,
            'kind': 'container',
            'title': '工具目录',
            'position': 1,
          },
          {
            'id': 'file',
            'parentId': 'root',
            'kind': 'redirect',
            'title': '下载文件',
            'redirectUrl': 'https://example.com/file.zip',
            'position': 0,
          },
        ],
      };
    }
    return super.get(path, query: query);
  }
}

void main() {
  testWidgets(
    'public directory follows parent IDs to an external resource landing page',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [communityProvider.overrideWithValue(CardApi())],
          child: const MaterialApp(home: Scaffold(body: DownloadsPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('工具目录'), findsOneWidget);
      expect(find.text('下载文件'), findsNothing);
      await tester.tap(find.text('工具目录'));
      await tester.pumpAndSettle();
      expect(find.text('下载文件'), findsOneWidget);
      await tester.tap(find.text('下载文件'));
      await tester.pumpAndSettle();
      expect(find.text('外部资源'), findsOneWidget);
      expect(find.text('打开资源'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('下载文件'), findsOneWidget);
    },
  );
}
