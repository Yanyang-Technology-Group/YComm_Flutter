import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/api_client.dart';

void main() {
  test('GET 把 data 放进 query，写方法放进 body', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <({String method, String path, String body})>[];
    server.listen((r) async {
      requests.add((
        method: r.method,
        path: r.requestedUri.toString(),
        body: await utf8.decoder.bind(r).join(),
      ));
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'ok': true, 'data': {'n': 1}}));
      await r.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');

    await api.runDebugRequest(
      method: 'GET',
      route: '/forum/search',
      data: {'q': 'flutter', 'scope': 'topics'},
    );
    await api.runDebugRequest(
      method: 'POST',
      route: '/forum/topics/1/posts',
      data: {'content': '同意'},
    );

    expect(requests[0].method, 'GET');
    expect(requests[0].path, contains('q=flutter'));
    expect(requests[0].path, contains('scope=topics'));
    expect(requests[0].body, isEmpty);
    expect(requests[1].method, 'POST');
    expect(requests[1].path, isNot(contains('content=')));
    expect(jsonDecode(requests[1].body), {'content': '同意'});
  });

  test('未知方法退回 GET', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final methods = <String>[];
    server.listen((r) async {
      methods.add(r.method);
      await utf8.decoder.bind(r).join();
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'ok': true}));
      await r.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
    await api.runDebugRequest(method: 'PUT', route: '/x');
    expect(methods, ['GET']);
  });

  test('HTTP 错误与非 JSON 响应都被原样带回', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((r) async {
      await utf8.decoder.bind(r).join();
      r.response.statusCode = 404;
      r.response.headers.contentType = ContentType.text;
      r.response.write('not found');
      await r.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
    final response = await api.runDebugRequest(method: 'GET', route: '/missing');
    expect(response.statusCode, 404);
    expect(response.body, 'not found');
    expect(response.decoded, isNull);
    expect(response.prettyBody, 'not found');
  });

  test('JSON 响应被美化打印', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((r) async {
      await utf8.decoder.bind(r).join();
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'ok': true, 'data': {'n': 1}}));
      await r.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
    final response = await api.runDebugRequest(method: 'GET', route: '/x');
    expect(response.statusCode, 200);
    expect(response.decoded, isA<Map<String, dynamic>>());
    expect(response.prettyBody, contains('\n'));
  });

  test('空值参数不发出去', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    String? query;
    server.listen((r) async {
      query = r.requestedUri.query;
      await utf8.decoder.bind(r).join();
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'ok': true}));
      await r.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
    await api.runDebugRequest(
      method: 'GET',
      route: '/x',
      data: {'a': '', 'b': '  ', 'c': 'ok'},
    );
    expect(query, isNot(contains('a=')));
    expect(query, isNot(contains('b=')));
    expect(query, contains('c=ok'));
  });
}
