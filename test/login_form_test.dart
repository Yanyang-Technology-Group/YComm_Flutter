import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/features/auth/login_page.dart';
import 'package:ycomm_client/features/auth/register_page.dart';

void main() {
  testWidgets(
    'GitHub sign-in requires consent without validating password fields',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      final button = find.text('使用 GitHub 登录');
      await tester.scrollUntilVisible(
        button,
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      expect(find.text('请先阅读并同意服务协议和儿童个人信息保护规则'), findsOneWidget);
      expect(find.text('请输入用户名或邮箱'), findsNothing);
      expect(find.text('请输入密码'), findsNothing);
    },
  );
  testWidgets(
    'registration offers GitHub without requiring password registration fields',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
      final button = find.text('使用 GitHub 登录');
      await tester.scrollUntilVisible(
        button,
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(button);
      await tester.pump();
      expect(find.text('请先阅读并同意服务协议和儿童个人信息保护规则'), findsOneWidget);
      expect(find.text('请输入用户名'), findsNothing);
      expect(find.text('请输入有效邮箱'), findsNothing);
    },
  );
  testWidgets('empty fields are rejected before contacting authentication', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    final submit = find.widgetWithText(FilledButton, '登录');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('请输入用户名或邮箱'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
    expect(find.text('完成人机验证'), findsNothing);
  });
  testWidgets('consent is required and form scrolls at narrow phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.enterText(find.byType(TextFormField).first, 'test');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    final submit = find.widgetWithText(FilledButton, '登录');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('请先阅读并同意服务协议和儿童个人信息保护规则'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
