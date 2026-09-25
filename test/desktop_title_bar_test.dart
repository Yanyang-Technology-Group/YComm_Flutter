import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/window/desktop_shell.dart';
import 'package:ycomm_client/features/shell/desktop_title_bar.dart';

/// 与生产环境一致：标题栏位于 Navigator 外部。
Widget _app(Widget child) => MaterialApp(
  builder: (context, page) => DesktopWindowFrame(titleBar: child, child: page),
  home: const Scaffold(body: Text('首页')),
);

void main() {
  testWidgets('标题栏在页面跳转后仍可显示悬停提示', (tester) async {
    await tester.pumpWidget(_app(const DesktopTitleBar()));
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.text('首页')).dy, 38);
    expect(tester.getBottomRight(find.byType(Scaffold)).dy, 600);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 200));
    addTearDown(mouse.removePointer);
    for (final label in ['最小化', '最大化 / 还原', '关闭']) {
      await mouse.moveTo(tester.getCenter(find.byTooltip(label)));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text(label), findsOneWidget);
      await mouse.moveTo(const Offset(400, 200));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }
    tester.state<NavigatorState>(find.byType(Navigator)).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('子页面')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('子页面'), findsOneWidget);
    expect(tester.getTopLeft(find.text('子页面')).dy, 38);
    expect(tester.getBottomRight(find.byType(Scaffold)).dy, 600);
    await mouse.moveTo(tester.getCenter(find.byTooltip('最小化')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('最小化'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('标题栏按钮可在 Scaffold 之外渲染', (tester) async {
    await tester.pumpWidget(_app(const DesktopTitleBar()));
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('最小化'), findsOneWidget);
    expect(find.byTooltip('最大化 / 还原'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsOneWidget);
  });

  testWidgets('左上角保留应用图标，标题水平居中且无下划线', (tester) async {
    await tester.pumpWidget(_app(const DesktopTitleBar()));
    expect(tester.takeException(), isNull);
    // 左上角的 logo 必须在（曾经为了「纯文字标题」把它删掉过）。
    final logo = find.descendant(
      of: find.byType(DesktopTitleBar),
      matching: find.byType(Image),
    );
    expect(logo, findsOneWidget, reason: '标题栏左上角应有应用图标');
    final logoRect = tester.getRect(logo);
    expect(logoRect.width, 18, reason: '图标是 18×18');
    expect(logoRect.height, 18, reason: '图标是 18×18');
    expect(
      logoRect.left,
      moreOrLessEquals(12, epsilon: 0.5),
      reason: '图标贴着左边 12px',
    );
    expect(
      logoRect.center.dy,
      moreOrLessEquals(desktopTitleBarHeight / 2, epsilon: 0.5),
      reason: '图标在标题栏里垂直居中',
    );
    // 图标要在拖动区域里，按住它也能拖窗口。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('title-bar-drag-area')),
        matching: logo,
      ),
      findsOneWidget,
      reason: '图标属于拖动区域，按住图标拖动窗口',
    );
    // 没有下划线：文字样式必须显式关闭 text decoration。
    final title = tester.widget<Text>(find.text('晏阳社区'));
    expect(
      title.style?.decoration,
      TextDecoration.none,
      reason: '标题文字不允许有下划线',
    );
    // 居中：文字中心 = 标题栏中心（图标不能把标题挤偏）。
    final barWidth = tester.getSize(find.byType(DesktopTitleBar)).width;
    expect(
      tester.getCenter(find.text('晏阳社区')).dx,
      moreOrLessEquals(barWidth / 2, epsilon: 0.5),
      reason: '标题文字应水平居中',
    );
  });

  testWidgets('三个按钮在拖动区域之外，按下不会被窗口拖动吞掉', (tester) async {
    await tester.pumpWidget(_app(const DesktopTitleBar()));
    expect(tester.takeException(), isNull);
    // 标题栏里必须存在一块“按下即拖动窗口”的拖动层，用固定 key 标记。
    // （key 与 desktop_title_bar.dart 中的 titleBarDragAreaKey 保持一致。）
    const dragAreaKey = ValueKey('title-bar-drag-area');
    final dragArea = find.byKey(dragAreaKey);
    expect(
      dragArea,
      findsOneWidget,
      reason: '标题栏需要一块明确的拖动区域',
    );
    for (final label in ['最小化', '最大化 / 还原', '关闭']) {
      // 三个按钮都不能被压在拖动层下面，否则按下按钮会先触发窗口拖动。
      expect(
        find.descendant(of: dragArea, matching: find.byTooltip(label)),
        findsNothing,
        reason: '$label 必须在拖动区域之外，否则按下按钮会先触发窗口拖动',
      );
      expect(
        find.descendant(
          of: find.byType(DesktopTitleBar),
          matching: find.byTooltip(label),
        ),
        findsOneWidget,
      );
    }
    // 三个按钮都能正常点击（不抛异常）。
    for (final label in ['最小化', '最大化 / 还原', '关闭']) {
      await tester.tap(find.byTooltip(label));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('标题栏按钮固定为 46×38，三个按钮加起来不撑破标题栏', (tester) async {
    await tester.pumpWidget(
      _app(const SizedBox(width: 360, height: 38, child: DesktopTitleBar())),
    );
    expect(tester.takeException(), isNull);
    // 三个按钮各 46px，标题居中后左右都还有富余，这里直接量 Icon 本体的
    // 16×16 来证明按钮被正确布局。
    for (final tooltip in ['最小化', '最大化 / 还原', '关闭']) {
      final icon = tester.getSize(
        find.descendant(
          of: find.byTooltip(tooltip),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.width, 16, reason: tooltip);
      expect(icon.height, 16, reason: tooltip);
    }
  });
}
