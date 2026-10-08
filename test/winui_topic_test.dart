import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/design/winui_theme.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/features/forum/topic_page.dart';

class TopicApi extends CommunityApi {
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/auth/me') return {'user': null};
    return {
      'topic': {
        'id': 'topic',
        'title': 'WinUI 讨论',
        'author_id': 'a',
        'is_locked': false,
      },
      'posts': [
        {
          'id': 'p',
          'author_id': 'a',
          'content_md': '主题正文',
          'authorDisplayName': '作者',
          'created_at': '2026-10-07T00:00:00Z',
        },
      ],
      'likedPostIds': [],
    };
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('WinUI topic opens with body and composer in $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [communityProvider.overrideWithValue(TopicApi())],
          child: MaterialApp(
            theme: buildWinuiTheme(ThemeColour.azure, brightness),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TopicPage(id: 'topic'),
                    ),
                  ),
                  child: const Text('打开讨论'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开讨论'));
      await tester.pumpAndSettle();
      expect(find.text('主题正文'), findsOneWidget);
      expect(find.byKey(const ValueKey('reply-composer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
