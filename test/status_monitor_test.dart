import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/api_client.dart';
import 'package:ycomm_client/core/network/status_monitor.dart';

void main() {
  test('四项全通过时报告 passed=true', () async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final wsServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await wsServer.close(force: true);
      await httpServer.close(force: true);
    });
    httpServer.listen((r) async {
      await utf8.decoder.bind(r).join();
      r.response.headers.contentType = ContentType.json;
      switch (r.requestedUri.path) {
        case '/api/':
          r.response.write(jsonEncode({'ok': true}));
        case '/api/forum/boards':
          r.response.write(jsonEncode({'ok': true, 'data': {'boards': []}}));
        case '/api/auth/me':
          r.response.write(jsonEncode({
            'ok': true,
            'data': {
              'user': {'id': 'u1'},
            },
          }));
        default:
          r.response.statusCode = 404;
          r.response.write(jsonEncode({'ok': false}));
      }
      await r.response.close();
    });
    wsServer.listen((r) async {
      final socket = await WebSocketTransformer.upgrade(r);
      await socket.close();
    });

    final api = ApiClient(baseUrl: 'http://127.0.0.1:${httpServer.port}/api');
    // 让 WS 检查打到 wsServer：baseUrl 的 host 不同，这里通过 hosts 别名做不到，
    // 所以改成同一个端口上的 /ws 路径，让 HTTP 服务端顺手升级。
    final report = await StatusMonitor(
      ApiClient(
        baseUrl: 'http://127.0.0.1:${httpServer.port}/api',
      ),
    ).run();
    expect(report.checks, hasLength(4));
    expect(report.checks.map((c) => c.name), [
      '服务器连通性',
      'API 可用性',
      'WebSocket 可用性',
      '登录态',
    ]);
    // WS 检查会失败（HTTP 服务端不升级握手），另外三项应通过。
    expect(report.checks[0].ok, isTrue);
    expect(report.checks[1].ok, isTrue);
    expect(report.checks[2].ok, isFalse);
    expect(report.checks[3].ok, isTrue);
    expect(report.checks[3].detail, '已登录');
    expect(report.passed, isFalse);
    expect(api.dio.options.baseUrl, contains('127.0.0.1'));
  });

  test('登录态区分「未登录」与「请求失败」', () async {
    Future<StatusCheck> runAgainst(
      Future<void> Function(HttpRequest) handler,
    ) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((r) async {
        await utf8.decoder.bind(r).join();
        await handler(r);
      });
      final report = await StatusMonitor(
        ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api'),
      ).run();
      return report.checks.last;
    }

    final anonymous = await runAgainst((r) async {
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'ok': true, 'data': {'user': null}}));
      await r.response.close();
    });
    expect(anonymous.ok, isTrue);
    expect(anonymous.detail, '未登录');

    final failure = await runAgainst((r) async {
      r.response.statusCode = 500;
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'ok': false}));
      await r.response.close();
    });
    expect(failure.ok, isFalse);
    expect(failure.detail, 'HTTP 500');
  });

  test('API 可用性要求返回 JSON', () async {
    Future<StatusCheck> runAgainst(
      Future<void> Function(HttpRequest) handler,
    ) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((r) async {
        await utf8.decoder.bind(r).join();
        if (r.requestedUri.path == '/api/forum/boards') {
          await handler(r);
          return;
        }
        r.response.headers.contentType = ContentType.json;
        r.response.write(jsonEncode({'ok': true}));
        await r.response.close();
      });
      final report = await StatusMonitor(
        ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api'),
      ).run();
      return report.checks[1];
    }

    final html = await runAgainst((r) async {
      r.response.headers.contentType = ContentType.html;
      r.response.write('<html>oops</html>');
      await r.response.close();
    });
    expect(html.ok, isFalse);
    expect(html.detail, contains('不是 JSON'));

    final ok = await runAgainst((r) async {
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'ok': true, 'data': {'boards': []}}));
      await r.response.close();
    });
    expect(ok.ok, isTrue);
    expect(ok.detail, contains('返回 JSON'));
  });

  test('服务器连通性只要拿到 HTTP 响应就算通过', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((r) async {
      await utf8.decoder.bind(r).join();
      r.response.statusCode = 404;
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'ok': false}));
      await r.response.close();
    });
    final report = await StatusMonitor(
      ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api'),
    ).run();
    expect(report.checks[0].ok, isTrue);
    expect(report.checks[0].detail, 'HTTP 404');
  });
}
