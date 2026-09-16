import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_all/webview_all.dart';
import 'package:ycomm_client/features/auth/github_login_page.dart';

// Load the real authorize endpoint, but never enter credentials or authorize.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('GitHub authorization renders in app and can be cancelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GithubLoginPage(),
                ),
              ),
              child: const Text('开始'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('开始'));
    bool ready = false;
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      final views = find.byType(WebViewWidget);
      if (views.evaluate().isEmpty) {
        if (find.text('重新授权').evaluate().isNotEmpty) break;
        continue;
      }
      final controller = tester
          .widget<WebViewWidget>(views)
          .platform
          .params
          .controller;
      final result = await controller.runJavaScriptReturningResult(
        "location.hostname === 'github.com' && document.readyState === 'complete' && !!document.querySelector('input[name=login]')",
      );
      if (result == true || result == 'true') {
        ready = true;
        break;
      }
    }
    expect(
      ready,
      isTrue,
      reason:
          'GitHub official form must render: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
    );
    await tester.tap(find.byTooltip('取消登录'));
    await tester.pumpAndSettle();
    expect(find.byType(GithubLoginPage), findsNothing);
  });
}
