import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'captcha_transport.dart';

abstract interface class CaptchaChallenge {
  Uri get uri;
  Future<String?> get token;
  Future<void> close();
}

/// Local callback for a user-operated CAP widget in the in-app WebView.
/// No credentials or session cookies ever enter this page.
class CaptchaSession implements CaptchaChallenge {
  CaptchaSession._(
    this._server,
    this._nonce,
    this._dark,
    this._loadResource,
    this._transport,
  ) {
    _server.listen((request) {
      unawaited(
        _handle(request).catchError((Object error) async {
          // Closing the dialog may abort a response while HTTPS is in flight.
          try {
            await request.response.close();
          } catch (_) {
            // The socket was already closed with the session.
          }
        }),
      );
    });
    _timeout = Timer(const Duration(minutes: 3), close);
  }

  final HttpServer _server;
  final String _nonce;
  final bool _dark;
  final CaptchaResourceLoader _loadResource;
  final CaptchaTransport _transport;
  static final _resources = <String, (Uri, String, String)>{
    'cap.min.js': (
      Uri.parse('https://cap.yanyn.cn/cap.min.js'),
      'GET',
      'application/javascript',
    ),
    'wasm/cap_wasm.min.js': (
      Uri.parse(
        'https://cdn.jsdelivr.net/npm/@cap.js/wasm@0.0.6/browser/cap_wasm.min.js',
      ),
      'GET',
      'application/javascript',
    ),
    'wasm/cap_wasm_bg.wasm': (
      Uri.parse(
        'https://cdn.jsdelivr.net/npm/@cap.js/wasm@0.0.6/browser/cap_wasm_bg.wasm',
      ),
      'GET',
      'application/wasm',
    ),
    'api/challenge': (
      Uri.parse('https://cap.yanyn.cn/api/challenge'),
      'POST',
      'application/json',
    ),
    'api/redeem': (
      Uri.parse('https://cap.yanyn.cn/api/redeem'),
      'POST',
      'application/json',
    ),
  };
  final _token = Completer<String?>();
  late final Timer _timeout;
  bool _closed = false;
  @override
  Future<String?> get token => _token.future;
  @override
  Uri get uri => Uri.parse('http://127.0.0.1:${_server.port}/$_nonce');

  static Future<CaptchaSession> start({
    bool dark = false,
    CaptchaResourceLoader? resourceLoader,
  }) async {
    final random = Random.secure();
    final nonce = base64Url
        .encode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    final transport = CaptchaTransport();
    return CaptchaSession._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      nonce,
      dark,
      resourceLoader ?? transport.load,
      transport,
    );
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('Referrer-Policy', 'no-referrer');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    // Reject foreign origins, DNS rebinding and callbacks from older sessions.
    if (request.headers.value('host') != uri.authority ||
        request.uri.hasQuery) {
      response.statusCode = 404;
    } else if (request.uri.path.startsWith('${uri.path}/')) {
      await _serveResource(request);
      return;
    } else if (request.uri.path != uri.path) {
      response.statusCode = 404;
    } else if (request.method == 'GET') {
      response.headers.contentType = ContentType.html;
      response.headers.set(
        'Content-Security-Policy',
        "default-src 'none'; script-src 'self' 'nonce-$_nonce' 'wasm-unsafe-eval'; connect-src 'self'; worker-src blob:; style-src 'unsafe-inline'; img-src data:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
      );
      response.write(_page);
    } else if (request.method != 'POST') {
      response.statusCode = 405;
    } else if (request.headers.value('origin') != uri.origin) {
      response.statusCode = 403;
    } else if (_token.isCompleted) {
      response.statusCode = 409;
    } else {
      try {
        final bytes = <int>[];
        await for (final chunk in request.timeout(
          const Duration(seconds: 10),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > 4096) {
            throw const FormatException('Token too large');
          }
        }
        final value = utf8.decode(bytes).trim();
        if (value.isEmpty) throw const FormatException('Empty token');
        response.write('ok');
        await response.close();
        _token.complete(value);
        return;
      } catch (_) {
        response.statusCode = 400;
      }
    }
    await response.close();
  }

  Future<void> _serveResource(HttpRequest request) async {
    final response = request.response;
    final resource =
        _resources[request.uri.path.substring(uri.path.length + 1)];
    if (resource == null) {
      response.statusCode = 404;
    } else if (request.method != resource.$2) {
      response.statusCode = 405;
    } else if (request.method == 'POST' &&
        request.headers.value('origin') != uri.origin) {
      response.statusCode = 403;
    } else {
      try {
        final body = <int>[];
        await for (final chunk in request.timeout(
          const Duration(seconds: 10),
        )) {
          body.addAll(chunk);
          if (body.length > 64 * 1024) {
            throw const FormatException('CAP request too large');
          }
        }
        final result = await _loadResource(
          resource.$1,
          resource.$2,
          body,
        ).timeout(const Duration(seconds: 25));
        response.statusCode = result.statusCode;
        response.headers.set('Content-Type', resource.$3);
        // Blob workers inherit the page CSP. No arbitrary network destinations
        // or remote script URLs are accepted by this session-scoped relay.
        response.add(result.bytes);
      } catch (_) {
        response.statusCode = 502;
      }
    }
    await response.close();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timeout.cancel();
    _transport.close();
    if (!_token.isCompleted) _token.complete(null);
    await _server.close(force: true);
  }

  String get _page =>
      '''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>晏阳社区 · 人机验证</title>
<style>
:root{color-scheme:${_dark ? 'dark' : 'light'}}
*{box-sizing:border-box}body{margin:0;background:${_dark ? '#1c2026' : '#ffffff'};color:${_dark ? '#eceef2' : '#19232f'};font:14px/1.65 system-ui,sans-serif}
main{width:100%;padding:16px 8px}cap-widget{display:block;width:100%;--cap-widget-width:100%;--cap-border-radius:14px;--cap-background:${_dark ? '#1c2026' : '#ffffff'};--cap-color:${_dark ? '#eceef2' : '#19232f'};--cap-border-color:${_dark ? '#343b45' : '#e1e6ed'}}
p{margin:16px 0 0;text-align:center;overflow-wrap:anywhere}button{font:inherit;padding:10px 16px;border-radius:10px;cursor:pointer}
</style></head>
<body><main><cap-widget id="cap" data-cap-api-endpoint="${uri.path}/api/" data-cap-i18n-initial-state="点击开始验证" data-cap-i18n-verifying-label="正在验证…" data-cap-i18n-solved-label="验证成功" data-cap-i18n-error-label="验证失败，请重试" data-cap-i18n-verify-aria-label="点击完成人机验证" data-cap-i18n-verified-aria-label="验证成功" data-cap-i18n-verifying-aria-label="正在验证，请稍候" data-cap-i18n-error-aria-label="验证失败，请重试"></cap-widget><p id="status" role="status" aria-live="polite">正在加载验证组件…</p><button id="reload" hidden>重新加载</button></main>
<script nonce="$_nonce">
const status = document.getElementById('status');
window.addEventListener('error', () => { status.textContent = '验证组件运行失败，请重新验证'; });
const retry = document.getElementById('reload');
retry.onclick = () => location.reload();
document.getElementById('cap').addEventListener('solve', async (event) => {
  const token = event.detail && event.detail.token;
  if (typeof token !== 'string' || !token) return;
  status.textContent = '正在回传验证结果…';
  try {
    const response = await fetch(location.pathname, {method:'POST',headers:{'Content-Type':'text/plain'},body:token});
    if (!response.ok) throw new Error('callback');
    status.textContent = '验证成功，正在继续…';
    document.getElementById('cap').hidden = true;
  } catch (_) { status.textContent = '验证已过期，请点击下方重新验证。'; retry.hidden = false; }
});
window.CAP_CUSTOM_WASM_URL = location.origin + '${uri.path}/wasm/cap_wasm.min.js';
const script = document.createElement('script');
script.src = '${uri.path}/cap.min.js';
script.onload = () => { status.textContent = '点击上方组件开始验证'; };
script.onerror = () => { status.textContent = '验证组件加载失败，请重试'; retry.hidden = false; };
document.head.appendChild(script);
</script></body></html>''';
}
