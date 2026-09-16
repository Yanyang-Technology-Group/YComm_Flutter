import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/api_client.dart';
import 'package:ycomm_client/core/network/community_api.dart';

void main() {
  test('API rejection is not presented as an empty public list', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((r) async {
      r.response.statusCode = 403;
      r.response.headers.contentType = ContentType.json;
      r.response.write(
        jsonEncode({
          'ok': false,
          'error': {'code': 'FORBIDDEN', 'message': '请登录后访问'},
        }),
      );
      await r.response.close();
    });
    final api = CommunityApi(
      client: ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api'),
    );
    await expectLater(
      api.boards(),
      throwsA(
        isA<RequestFailure>().having((e) => e.message, 'message', '请登录后访问'),
      ),
    );
  });
}
