import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/api_client.dart';
import 'package:ycomm_client/core/network/community_api.dart';

void main() {
  test('PATCH preserves body and DELETE accepts null success data', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <String>[];
    server.listen((r) async {
      requests.add('${r.method} ${r.uri.path}');
      if (r.method == 'PATCH') {
        expect(jsonDecode(await utf8.decodeStream(r)), {'role': 'member'});
      } else {
        expect(await utf8.decodeStream(r), isEmpty);
      }
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'ok': true, 'data': null}));
      await r.response.close();
    });
    final api = CommunityApi(
      client: ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api'),
    );
    expect(await api.patch('/admin/users/u/role', {'role': 'member'}), isEmpty);
    expect(await api.delete('/forum/posts/p'), isEmpty);
    expect(requests, [
      'PATCH /api/admin/users/u/role',
      'DELETE /api/forum/posts/p',
    ]);
  });
  test(
    'DELETE preserves authorization failure instead of treating it as success',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((r) async {
        r.response.statusCode = 403;
        r.response.headers.contentType = ContentType.json;
        r.response.write(
          jsonEncode({
            'ok': false,
            'error': {'code': 'FORBIDDEN', 'message': '权限不足'},
          }),
        );
        await r.response.close();
      });
      final api = CommunityApi(
        client: ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api'),
      );
      await expectLater(
        api.delete('/forum/posts/p'),
        throwsA(
          isA<RequestFailure>().having((e) => e.code, 'code', 'FORBIDDEN'),
        ),
      );
    },
  );
}
