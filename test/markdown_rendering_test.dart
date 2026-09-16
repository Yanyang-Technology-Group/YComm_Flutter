import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/core/widgets/design.dart';
import 'package:ycomm_client/features/admin/admin_catalog_pages.dart';
import 'package:ycomm_client/features/admin/moderation_page.dart';
import 'package:ycomm_client/features/forum/compose_page.dart';
import 'package:ycomm_client/features/forum/forum_page.dart';
import 'package:ycomm_client/features/forum/topic_page.dart';
import 'package:ycomm_client/features/notifications/notifications_page.dart';

import 'fixtures/markdown_fixture.dart';

Future<void> markdownPage(
  WidgetTester tester,
  Widget page,
  MarkdownApi api,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: buildTheme(ThemeColour.azure, Brightness.light),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('board chips render Markdown and retain their route slugs', (
    tester,
  ) async {
    final api = MarkdownApi();
    await markdownPage(tester, const ForumPage(), api);
    expect(find.text('**官方公告**'), findsNothing);
    expect(find.text('官方公告'), findsOneWidget);
    await tester.tap(find.text('互助与 Flutter'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('/forum/boards/help/topics'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compose board dropdown renders formatting and keeps selection', (
    tester,
  ) async {
    final api = MarkdownApi();
    await markdownPage(tester, const ComposePage(boards: markdownBoards), api);
    expect(find.text('**官方公告**'), findsNothing);
    expect(find.text('官方公告'), findsWidgets);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('互助与 Flutter').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      'help',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'admin board names render Markdown while editing preserves source',
    (tester) async {
      await markdownPage(tester, const AdminBoardsPage(), MarkdownApi());
      expect(find.text('**官方公告**'), findsNothing);
      await tester.tap(find.text('官方公告'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑版块'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '**官方公告**'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nested inline styles, escaped punctuation and entities survive',
    (tester) async {
      await markdownPage(
        tester,
        const Scaffold(
          body: MarkdownText(
            r'**粗体与 *斜体*** ~~旧版~~ `a_b * c` \*字面星号\* C# &amp; [链接](/guide)',
          ),
        ),
        MarkdownApi(),
      );
      final text = tester.widget<Text>(
        find.text('粗体与 斜体 旧版 a_b * c *字面星号* C# & 链接'),
      );
      final styles = <String, TextStyle>{};
      void collect(InlineSpan span, TextStyle inherited) {
        if (span is! TextSpan) return;
        final effective = inherited.merge(span.style);
        if (span.text != null) styles[span.text!] = effective;
        for (final child in span.children ?? <InlineSpan>[]) {
          collect(child, effective);
        }
      }

      collect(text.textSpan!, const TextStyle());
      expect(styles['斜体']?.fontWeight, FontWeight.w700);
      expect(styles['斜体']?.fontStyle, FontStyle.italic);
      expect(styles['旧版']?.decoration, TextDecoration.lineThrough);
      expect(styles['a_b * c']?.fontFamily, 'monospace');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'excerpts flatten blocks, resolve references and describe images',
    (tester) async {
      await markdownPage(
        tester,
        const Scaffold(
          body: MarkdownText(
            '''
# 标题

第一段 **加粗**

> 引用

- [x] 已完成
- [ ] 待处理

![截图](/picture.png) [文档][ref]

[ref]: /docs
''',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        MarkdownApi(),
      );
      final text = tester.widget<Text>(find.byType(Text).first);
      final plain = text.textSpan!.toPlainText();
      expect(plain, contains('标题 第一段 加粗 引用'));
      expect(plain, contains('[x]'));
      expect(plain, contains('[ ]'));
      expect(plain, contains('[图片：截图] 文档'));
      expect(plain, isNot(contains('/docs')));
      expect(plain, isNot(contains('**')));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets(
    'topic titles and board move labels render Markdown without changing IDs',
    (tester) async {
      final api = MarkdownApi();
      await markdownPage(tester, const TopicPage(id: 't1'), api);
      expect(find.text('九月更新：社区体验优化'), findsOneWidget);
      await tester.tap(find.byTooltip('管理讨论'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移动版块'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('互助与 Flutter'));
      await tester.pumpAndSettle();
      expect(api.sentBody, {'action': 'move', 'boardId': 'b2'});
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'GFM body handles tables and long code at 320px, 1.8x, $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(ThemeColour.azure, brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: MarkdownContent(markdownSample),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('社区更新'), findsOneWidget);
        expect(find.byType(Table), findsOneWidget);
        expect(find.byIcon(Icons.check_box), findsOneWidget);
        expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
        final theme = Theme.of(tester.element(find.byType(MarkdownContent)));
        expect(
          tester.widget<Icon>(find.byIcon(Icons.check_box)).color,
          theme.colorScheme.primary,
        );
        final horizontal = find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        );
        expect(horizontal, findsNWidgets(2));
        for (final scroll in horizontal.evaluate()) {
          final state = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byWidget(scroll.widget),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(state.position.maxScrollExtent, greaterThan(0));
          state.position.jumpTo(state.position.maxScrollExtent);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Markdown image URLs resolve against the community and unsafe links are rejected',
    (tester) async {
      await markdownPage(
        tester,
        const Scaffold(
          body: MarkdownContent(
            '![架构图](/files/diagram.png)\n\n[不支持的链接](javascript:alert)\n\n![本地文件](file:///secret)',
          ),
        ),
        MarkdownApi(),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as NetworkImage).url,
        '$siteOrigin/files/diagram.png',
      );
      expect(image.semanticLabel, '架构图');
      final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      markdown.onTapLink!('不支持的链接', 'javascript:alert', '');
      await tester.pumpAndSettle();
      expect(find.text('无法打开此链接'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('moderation shows Markdown content as it appears publicly', (
    tester,
  ) async {
    await markdownPage(
      tester,
      const ModerationDetailPage(
        item: {
          'id': 'review1',
          'target_type': 'post',
          'target_id': 'p1',
          'status': 'pending',
          'detail': {'content_md': '**待审核内容**\n\n> 引用', 'topicTitle': '讨论'},
        },
      ),
      MarkdownApi(),
    );
    expect(find.text('待审核内容'), findsOneWidget);
    expect(find.text('**待审核内容**'), findsNothing);
    expect(find.byType(MarkdownContent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('body links open resolved URLs in the external browser', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await markdownPage(
      tester,
      const Scaffold(
        body: MarkdownContent(
          '[社区资源](/downloads)\n\n[外部文档](https://example.com/docs)',
        ),
      ),
      MarkdownApi(),
    );
    await tester.tap(find.text('社区资源'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('外部文档'));
    await tester.pumpAndSettle();
    expect(calls.map((call) => call.arguments['url']), [
      '$siteOrigin/downloads',
      'https://example.com/docs',
    ]);
    expect(
      calls.every(
        (call) =>
            call.method == 'launch' && call.arguments['useWebView'] == false,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification preview and full dialog render Markdown', (
    tester,
  ) async {
    await markdownPage(
      tester,
      const Scaffold(body: NotificationsPage()),
      MarkdownApi(),
    );
    expect(find.text('公告通知'), findsOneWidget);
    expect(find.text('**公告通知**'), findsNothing);
    await tester.tap(find.text('公告通知'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(MarkdownContent),
      ),
      findsOneWidget,
    );
    expect(find.byType(Table), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
