import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/features/auth/captcha_dialog.dart';
import 'package:ycomm_client/features/auth/captcha_session.dart';
import 'package:ycomm_client/features/auth/captcha_webview.dart';

class FakeChallenge implements CaptchaChallenge {
  FakeChallenge(int id)
    : uri = Uri.parse('http://127.0.0.1:1234/challenge-$id');
  @override
  final Uri uri;
  final completion = Completer<String?>();
  bool closed = false;
  @override
  Future<String?> get token => completion.future;
  @override
  Future<void> close() async {
    closed = true;
    if (!completion.isCompleted) completion.complete(null);
  }
}

void main() {
  test('navigation stays in the exact local challenge document', () {
    final uri = Uri.parse('http://127.0.0.1:1234/nonce');
    expect(isCaptchaNavigationAllowed(uri, uri.toString()), isTrue);
    for (final url in [
      'https://example.com',
      'http://127.0.0.1:5678/nonce',
      'http://127.0.0.1:1234/old',
      'intent://browser',
      'file:///etc/passwd',
      'http://127.0.0.1:1234/nonce?x=1',
    ]) {
      expect(isCaptchaNavigationAllowed(uri, url), isFalse);
    }
  });
  Future<void> show(
    WidgetTester tester, {
    required CaptchaSessionFactory factory,
    required CaptchaViewBuilder builder,
    required ValueChanged<String?> done,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async {
                done(
                  await showDialog<String>(
                    context: c,
                    builder: (_) => CaptchaDialog(
                      sessionFactory: factory,
                      viewBuilder: builder,
                    ),
                  ),
                );
              },
              child: const Text('登录'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
  }

  testWidgets(
    'verification opens immediately inside dialog and returns token automatically',
    (tester) async {
      final session = FakeChallenge(1);
      String? result;
      await show(
        tester,
        factory: (_) async => session,
        builder: (uri, error) => const Text('嵌入验证组件'),
        done: (v) => result = v,
      );
      expect(find.text('嵌入验证组件'), findsOneWidget);
      expect(find.text('打开验证页面'), findsNothing);
      session.completion.complete('one-use-token');
      await tester.pumpAndSettle();
      expect(result, 'one-use-token');
      expect(session.closed, isTrue);
      expect(find.byType(CaptchaDialog), findsNothing);
    },
  );
  testWidgets(
    'narrow portrait and large text leave cancel and retry accessible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = FakeChallenge(1);
      await show(
        tester,
        factory: (_) async => session,
        builder: (_, _) => const SizedBox(),
        done: (_) {},
        scale: 1.8,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('取消').hitTestable(), findsOneWidget);
      expect(find.text('重新验证').hitTestable(), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets('cancel closes challenge and returns no token', (tester) async {
    final session = FakeChallenge(1);
    bool returned = false;
    String? result;
    await show(
      tester,
      factory: (_) async => session,
      builder: (_, _) => const SizedBox(),
      done: (v) {
        returned = true;
        result = v;
      },
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, isNull);
    expect(session.closed, isTrue);
  });
  testWidgets(
    'load failure discards old challenge; retry uses a fresh session',
    (tester) async {
      final sessions = <FakeChallenge>[];
      late VoidCallback fail;
      String? result;
      await show(
        tester,
        factory: (_) async {
          final s = FakeChallenge(sessions.length);
          sessions.add(s);
          return s;
        },
        builder: (_, onError) {
          fail = onError;
          return const Text('嵌入验证组件');
        },
        done: (v) => result = v,
      );
      fail();
      await tester.pumpAndSettle();
      expect(sessions.first.closed, isTrue);
      expect(find.text('验证页面加载失败，请检查网络后重试'), findsOneWidget);
      await tester.tap(find.text('重新验证'));
      await tester.pumpAndSettle();
      expect(sessions.length, 2);
      sessions.last.completion.complete('fresh-token');
      await tester.pumpAndSettle();
      expect(result, 'fresh-token');
    },
  );
  testWidgets('timeout permits retry without losing the parent form', (
    tester,
  ) async {
    final session = FakeChallenge(1);
    await show(
      tester,
      factory: (_) async => session,
      builder: (_, _) => const SizedBox(),
      done: (_) {},
    );
    session.completion.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('验证已超时，请重新验证'), findsOneWidget);
    expect(find.text('重新验证'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('登录'), findsOneWidget);
  });
  testWidgets('cancel during initialization closes a late-created session', (
    tester,
  ) async {
    final pending = Completer<CaptchaChallenge>();
    final session = FakeChallenge(1);
    await show(
      tester,
      factory: (_) => pending.future,
      builder: (_, _) => const SizedBox(),
      done: (_) {},
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    pending.complete(session);
    await tester.pumpAndSettle();
    expect(session.closed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
