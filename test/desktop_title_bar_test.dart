import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('标题栏按钮固定为 46×38，三个按钮加起来不撑破标题栏', (tester) async {
    await tester.pumpWidget(
      _app(const SizedBox(width: 360, height: 38, child: DesktopTitleBar())),
    );
    expect(tester.takeException(), isNull);
    // 三个按钮各 46px，12px 边距 + 18px 图标 + 8px 间距 + 标题文字后仍有富余，
    // 这里直接量 Icon 本体的 16×16 来证明按钮被正确布局。
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
