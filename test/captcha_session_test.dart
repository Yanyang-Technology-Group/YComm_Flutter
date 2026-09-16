import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/features/auth/captcha_session.dart';
import 'package:ycomm_client/features/auth/captcha_transport.dart';

void main() {
  test('verification page is sized and worded for an embedded view', () async {
    final session = await CaptchaSession.start();
    final http = HttpClient();
    addTearDown(() async {
      http.close(force: true);
      await session.close();
    });
    final response = await (await http.getUrl(session.uri)).close();
    final html = await utf8.decodeStream(response);
    expect(html, contains('验证成功，正在继续'));
    expect(html, isNot(contains('返回客户端')));
    expect(html, contains('color-scheme'));
    expect(
      response.headers.value('content-security-policy'),
      contains("frame-ancestors 'none'"),
    );
  });
  test('accepts one token only with matching path and origin', () async {
    final session = await CaptchaSession.start();
    final http = HttpClient();
    addTearDown(() async {
      http.close(force: true);
      await session.close();
    });
    var request = await http.postUrl(session.uri.resolve('/wrong'));
    request.write('token');
    var response = await request.close();
    expect(response.statusCode, 404);
    await response.drain<void>();
    request = await http.postUrl(session.uri);
    request.headers.set('origin', 'https://unrelated.example');
    request.write('token');
    response = await request.close();
    expect(response.statusCode, 403);
    await response.drain<void>();
    request = await http.postUrl(session.uri);
    request.headers.set('origin', session.uri.origin);
    request.write('one-use-test-token');
    response = await request.close();
    expect(response.statusCode, 200);
    await response.drain<void>();
    expect(await session.token, 'one-use-test-token');
    request = await http.postUrl(session.uri);
    request.headers.set('origin', session.uri.origin);
    request.write('replayed');
    response = await request.close();
    expect(response.statusCode, 409);
    await response.drain<void>();
  });
  test(
    'CAP relay restricts URLs, methods and origins and preserves requests',
    () async {
      final calls = <(Uri, String, List<int>)>[];
      final session = await CaptchaSession.start(
        resourceLoader: (uri, method, body) async {
          calls.add((uri, method, body));
          return CaptchaResource(200, utf8.encode('{"fixture":true}'));
        },
      );
      final http = HttpClient();
      addTearDown(() async {
        http.close(force: true);
        await session.close();
      });
      Future<HttpClientResponse> request(
        String path, {
        String method = 'GET',
        String? origin,
        String body = '',
      }) async {
        final r = await http.openUrl(method, Uri.parse('${session.uri}/$path'));
        if (origin != null) r.headers.set('origin', origin);
        if (body.isNotEmpty) r.write(body);
        return r.close();
      }

      for (final (path, method, origin, expected) in [
        ('https://example.com', 'GET', null, 404),
        ('cap.min.js?url=https://example.com', 'GET', null, 404),
        ('api/redeem', 'GET', null, 405),
        ('api/redeem', 'POST', 'https://unrelated.example', 403),
        ('api/redeem', 'POST', null, 403),
      ]) {
        final r = await request(path, method: method, origin: origin);
        expect(r.statusCode, expected);
        await r.drain<void>();
      }
      expect(calls, isEmpty);
      var response = await request('cap.min.js');
      expect(response.statusCode, 200);
      expect(response.headers.contentType!.mimeType, 'application/javascript');
      await response.drain<void>();
      expect(calls.single.$1.toString(), 'https://cap.yanyn.cn/cap.min.js');
      response = await request(
        'api/redeem',
        method: 'POST',
        origin: session.uri.origin,
        body: '{"test":"fixture"}',
      );
      expect(response.statusCode, 200);
      expect(await utf8.decodeStream(response), '{"fixture":true}');
      expect(calls.last.$1.toString(), 'https://cap.yanyn.cn/api/redeem');
      expect(calls.last.$2, 'POST');
      expect(utf8.decode(calls.last.$3), '{"test":"fixture"}');
    },
  );
  test('failed CAP resource can be retried within the same session', () async {
    var attempts = 0;
    final session = await CaptchaSession.start(
      resourceLoader: (_, _, _) async {
        if (++attempts == 1) throw const SocketException('offline');
        return CaptchaResource(200, utf8.encode('fixture'));
      },
    );
    final http = HttpClient();
    addTearDown(() async {
      http.close(force: true);
      await session.close();
    });
    final resource = Uri.parse('${session.uri}/cap.min.js');
    var response = await (await http.getUrl(resource)).close();
    expect(response.statusCode, 502);
    await response.drain<void>();
    response = await (await http.getUrl(resource)).close();
    expect(response.statusCode, 200);
    await response.drain<void>();
  });
  test('cancel safely aborts a resource that is still loading', () async {
    final started = Completer<void>();
    final resource = Completer<CaptchaResource>();
    final session = await CaptchaSession.start(
      resourceLoader: (_, _, _) {
        started.complete();
        return resource.future;
      },
    );
    final http = HttpClient();
    addTearDown(() {
      http.close(force: true);
    });
    final request = await http.getUrl(Uri.parse('${session.uri}/cap.min.js'));
    final response = request.close();
    final assertion = expectLater(response, throwsA(isA<HttpException>()));
    await started.future;
    await session.close();
    resource.complete(CaptchaResource(200, utf8.encode('fixture')));
    await assertion;
    expect(await session.token, isNull);
  });
  test('closing a cancelled session unblocks the waiting form', () async {
    final session = await CaptchaSession.start();
    await session.close();
    expect(await session.token, isNull);
  });
}
