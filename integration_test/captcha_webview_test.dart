import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_all/webview_all.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/features/auth/captcha_dialog.dart';

// Native smoke test: loads the official widget but NEVER solves a challenge.
// Run: flutter test integration_test/captcha_webview_test.dart -d linux
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'official CAP widget loads inside the app and cancel returns to form',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(ThemeColour.azure, Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showCaptchaDialog(context),
                  child: const Text('验证'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('验证'));
      Object? state;
      for (var attempt = 0; attempt < 60; attempt++) {
        await tester.pump(const Duration(milliseconds: 500));
        final views = find.byType(WebViewWidget);
        if (views.evaluate().isEmpty) continue;
        final controller = tester
            .widget<WebViewWidget>(views)
            .platform
            .params
            .controller;
        state = await controller.runJavaScriptReturningResult(
          "JSON.stringify({ready:!!customElements.get('cap-widget'),rendered:!!document.querySelector('cap-widget')?.shadowRoot?.querySelector('.captcha'),status:document.getElementById('status')?.textContent,overflow:document.documentElement.scrollWidth>window.innerWidth})",
        );
        if (state is String) {
          var decoded = jsonDecode(state);
          if (decoded is String) decoded = jsonDecode(decoded);
          if (decoded is Map &&
              decoded['ready'] == true &&
              decoded['rendered'] == true) {
            expect(decoded['overflow'], false);
            break;
          }
        }
      }
      var decoded = jsonDecode(state.toString());
      if (decoded is String) decoded = jsonDecode(decoded);
      expect(
        decoded['ready'],
        true,
        reason: 'Official CAP custom element must load: $decoded',
      );
      expect(
        decoded['rendered'],
        true,
        reason: 'Human-operated verification button must render: $decoded',
      );
      // Only fetch and compile the published WASM; never request or solve a
      // challenge. This checks the worker dependency and CSP permissions.
      final controller = tester
          .widget<WebViewWidget>(find.byType(WebViewWidget))
          .platform
          .params
          .controller;
      await controller.runJavaScript("""
        window.wasmCheck = 'loading';
        import(window.CAP_CUSTOM_WASM_URL)
          .then(module => module.default())
          .then(() => { window.wasmCheck = 'compiled'; })
          .catch(error => { window.wasmCheck = String(error); });
        void 0;
      """);
      Object? wasm;
      for (var attempt = 0; attempt < 60; attempt++) {
        await tester.pump(const Duration(milliseconds: 500));
        wasm = await controller.runJavaScriptReturningResult(
          'window.wasmCheck',
        );
        if (!wasm.toString().contains('loading')) break;
      }
      expect(wasm.toString(), contains('compiled'));
      expect(find.text('打开验证页面'), findsNothing);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(CaptchaDialog), findsNothing);
      expect(find.text('验证'), findsOneWidget);
    },
  );
}
