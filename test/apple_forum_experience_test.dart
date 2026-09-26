import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Brightness, TextButton;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/design/apple_app.dart';
import 'package:ycomm_client/core/design/apple_theme.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/core/widgets/design.dart';
import 'package:ycomm_client/features/forum/compose_page.dart';
import 'package:ycomm_client/features/forum/forum_page.dart';
import 'package:ycomm_client/features/forum/topic_page.dart';

import 'widget_test.dart' show TestApi;

class _LongForumApi extends TestApi {
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path.contains('/boards/')) {
      return {
        'total': 20,
        'topics': List.generate(
          20,
          (index) => {
            'id': 't1',
            'title': '阅读讨论 $index',
            'authorUsername': 'member',
            'reply_count': index,
            'preview': {
              'firstPost': {'contentExcerpt': '连续阅读时，返回应留在刚才的位置。'},
            },
          },
        ),
      };
    }
    return super.get(path, query: query);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(WidgetTester tester, TestApi api, Widget home) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: AppleApp(
          theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Apple compose has explicit cancellation and protects edits', (
    tester,
  ) async {
    await mount(
      tester,
      TestApi(),
      Builder(
        builder: (context) => CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () =>
                  openTaskPage(context, const ComposePage(topicId: 't1')),
              child: const Text('打开编辑'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '保留这段未发布的回复');
    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('离开编辑？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('保留这段未发布的回复'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃内容'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposePage), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets(
    'Apple publish remains reachable and failure retains editor contents',
    (tester) async {
      final api = TestApi()..failSend = true;
      await mount(tester, api, const ComposePage(topicId: 't1'));
      await tester.enterText(find.byType(EditableText), '发布失败也不能丢失');
      expect(find.text('发布'), findsOneWidget);
      await tester.tap(find.text('发布'));
      await tester.pumpAndSettle();
      expect(api.sentBody?['content'], '发布失败也不能丢失');
      expect(find.text('发布失败也不能丢失'), findsOneWidget);
      expect(find.textContaining('发送失败'), findsOneWidget);
    },
  );

  testWidgets('Apple community retains board controls after scrolling', (
    tester,
  ) async {
    final api = TestApi();
    await mount(tester, api, const ForumPage());
    expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apple-board-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二版块').last);
    await tester.pumpAndSettle();
    expect(api.calls, contains('/forum/boards/second/topics'));
    expect(find.text('第二版块的内容'), findsOneWidget);
  });
  testWidgets('preview cannot bypass empty reply validation', (tester) async {
    final api = TestApi();
    await mount(tester, api, const ComposePage(topicId: 't1'));
    await tester.tap(find.text('预览正文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发布'));
    await tester.pumpAndSettle();
    expect(api.calls.where((path) => path.endsWith('/posts')), isEmpty);
    expect(find.text('请先写一点内容'), findsOneWidget);
  });

  testWidgets('Apple forum pages support 200 percent text on a narrow screen', (
    tester,
  ) async {
    for (final page in <Widget>[
      const ForumPage(),
      const TopicPage(id: 't1'),
      const ComposePage(topicId: 't1'),
    ]) {
      await mount(
        tester,
        TestApi(),
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 740),
            textScaler: TextScaler.linear(2),
          ),
          child: page,
        ),
      );
      tester.view.physicalSize = const Size(320, 740);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$page at 200 percent text',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets('the full width of a discussion row opens its detail', (
    tester,
  ) async {
    await mount(tester, TestApi(), const ForumPage());
    final row = tester.getRect(find.byType(TopicTile).first);
    await tester.tapAt(Offset(row.right - 20, row.center.dy));
    await tester.pumpAndSettle();
    expect(find.byType(TopicPage), findsOneWidget);
  });

  testWidgets('returning from a discussion preserves the reading position', (
    tester,
  ) async {
    await mount(tester, _LongForumApi(), const ForumPage());
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    double offset() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    final before = offset();
    await tester.tap(find.byType(TopicTile).hitTestable().first);
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(TopicPage))).pop();
    await tester.pumpAndSettle();
    expect(offset(), closeTo(before, 1));
  });
}
