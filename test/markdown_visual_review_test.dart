import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/state/session.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/features/admin/admin_catalog_pages.dart';
import 'package:ycomm_client/features/forum/compose_page.dart';
import 'package:ycomm_client/features/forum/forum_page.dart';
import 'package:ycomm_client/features/forum/topic_page.dart';

import 'fixtures/markdown_fixture.dart';

void main() {
  testWidgets('render Markdown across content and board controls', (
    tester,
  ) async {
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Roboto')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc')
                .readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    final cjk = FontLoader('Noto Sans CJK SC')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc')
                .readAsBytesSync(),
          ),
        ),
      );
    await cjk.load();
    final monospace = FontLoader('monospace')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('/usr/share/fonts/noto/NotoSansMono-Regular.ttf')
                .readAsBytesSync(),
          ),
        ),
      );
    await monospace.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final directory = Directory('build/markdown-review')
      ..createSync(recursive: true);
    final container = ProviderContainer(
      overrides: [communityProvider.overrideWithValue(MarkdownApi())],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.notifier).refresh();
    for (final scenario in [
      ('phone-light', const Size(390, 844), Brightness.light, 1.0),
      ('phone-dark', const Size(390, 844), Brightness.dark, 1.0),
      ('small-large-text', const Size(320, 740), Brightness.light, 1.8),
      ('tablet', const Size(1024, 768), Brightness.light, 1.0),
      ('landscape', const Size(844, 390), Brightness.dark, 1.8),
    ]) {
      tester.view.physicalSize = scenario.$2;
      for (final entry in <String, Widget>{
        'forum': const ForumPage(),
        'compose': const ComposePage(boards: markdownBoards),
        'topic': const TopicPage(id: 't1'),
        'boards': const AdminBoardsPage(),
      }.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                key: UniqueKey(),
                debugShowCheckedModeBanner: false,
                theme: buildTheme(ThemeColour.azure, scenario.$3),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scenario.$4)),
                  child: child!,
                ),
                home: entry.value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/ycomm_mark.png'),
            key.currentContext!,
          );
        });
        await tester.pumpAndSettle();
        Future<void> capture(String name) async {
          expect(tester.takeException(), isNull);
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final bitmap = await boundary.toImage(pixelRatio: 1.5);
            final data = await bitmap.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File('${directory.path}/${scenario.$1}-$name.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
            bitmap.dispose();
          });
        }

        await capture(entry.key);
        if (entry.key == 'topic') {
          await Scrollable.ensureVisible(
            tester.element(find.byType(Table)),
            alignment: .05,
          );
          await tester.pumpAndSettle();
          await capture('topic-table');
        }
      }
    }
    debugDisableShadows = true;
  }, skip: !const bool.fromEnvironment('MARKDOWN_VISUAL_REVIEW'));
}
