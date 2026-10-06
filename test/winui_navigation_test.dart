import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/design/winui_nav.dart';
import 'package:ycomm_client/core/design/winui_theme.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';

const items = [
  WinuiNavigationItem(label: '社区', icon: Icons.forum_outlined),
  WinuiNavigationItem(label: '资源', icon: Icons.widgets_outlined),
  WinuiNavigationItem(
    label: '消息',
    icon: Icons.notifications_outlined,
    badge: '99+',
  ),
  WinuiNavigationItem(label: '我的', icon: Icons.person_outline),
];

void main() {
  for (final expanded in [true, false]) {
    testWidgets(
      'WinUI navigation selects with pointer and keyboard, expanded=$expanded',
      (tester) async {
        final selections = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: buildWinuiTheme(ThemeColour.azure, Brightness.light),
            home: Scaffold(
              body: WinuiNavigationPane(
                index: 0,
                onSelect: selections.add,
                items: items,
                expanded: expanded,
              ),
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('winui-selection-indicator')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('winui-destination-2')));
        await tester.pumpAndSettle();
        expect(selections, [2]);
        final button = find.descendant(
          of: find.byKey(const ValueKey('winui-destination-1')),
          matching: find.byType(TextButton),
        );
        Focus.of(
          tester.element(
            find.descendant(of: button, matching: find.byType(Icon)).first,
          ),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(selections.last, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'collapsed WinUI navigation fits a narrow window at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildWinuiTheme(ThemeColour.azure, Brightness.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Row(
                children: [
                  WinuiNavigationPane(
                    index: 2,
                    onSelect: (_) {},
                    items: items,
                    expanded: false,
                  ),
                  const Expanded(child: Text('内容')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('消息，99+ 条未读'), findsOneWidget);
        final unread = find.descendant(
          of: find.byKey(const ValueKey('winui-destination-2')),
          matching: find.byType(Badge),
        );
        expect(tester.widget<Badge>(unread).label, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
