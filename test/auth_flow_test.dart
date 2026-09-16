import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/api_client.dart';
import 'package:ycomm_client/features/auth/auth_flow.dart';

void main() {
  test(
    'captcha requirement retries with token and preserves credential error',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final bodies = <Map<String, dynamic>>[];
      server.listen((request) async {
        final body = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        bodies.add(body);
        request.response.headers.contentType = ContentType.json;
        request.response.statusCode = bodies.length == 1 ? 400 : 401;
        request.response.write(
          jsonEncode(
            bodies.length == 1
                ? {
                    'ok': false,
                    'error': {
                      'code': 'VALIDATION_FAILED',
                      'message': 'Request validation failed',
                      'meta': {
                        'issues': [
                          {'path': 'captchaToken', 'message': '请完成人机验证'},
                        ],
                      },
                    },
                  }
                : {
                    'ok': false,
                    'error': {'code': 'UNAUTHENTICATED', 'message': '用户名或密码错误'},
                  },
          ),
        );
        await request.response.close();
      });
      final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
      addTearDown(() => api.dio.close(force: true));
      final result = await AuthFlow(api).submit('/auth/login', {
        'login': 'tester',
        'password': ' spaces ',
        'agreeTerms': true,
      }, verify: () async => 'test-one-use-token');
      expect(result.errorMessage, '用户名或密码错误');
      expect(bodies, [
        {'login': 'tester', 'password': ' spaces ', 'agreeTerms': true},
        {
          'login': 'tester',
          'password': ' spaces ',
          'agreeTerms': true,
          'captchaToken': 'test-one-use-token',
        },
      ]);
    },
  );
  test(
    'cancelled verification does not submit another login request',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var count = 0;
      server.listen((request) async {
        count++;
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.statusCode = 400;
        request.response.write(
          jsonEncode({
            'ok': false,
            'error': {
              'code': 'VALIDATION_FAILED',
              'meta': {
                'issues': [
                  {'path': 'captchaToken', 'message': '请完成人机验证'},
                ],
              },
            },
          }),
        );
        await request.response.close();
      });
      final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
      addTearDown(() => api.dio.close(force: true));
      final result = await AuthFlow(api).submit('/auth/login', {
        'login': 'tester',
        'password': 'pw',
      }, verify: () async => null);
      expect(result.code, 'CAPTCHA_CANCELLED');
      expect(count, 1);
    },
  );

  test(
    'registration stops after an invalid token rather than looping',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var count = 0;
      server.listen((request) async {
        count++;
        expect(request.uri.path, '/api/auth/register');
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.statusCode = 400;
        request.response.write(
          jsonEncode({
            'ok': false,
            'error': {
              'code': 'VALIDATION_FAILED',
              'meta': {
                'issues': [
                  {'path': 'captchaToken', 'message': '人机验证失败，请重试'},
                ],
              },
            },
          }),
        );
        await request.response.close();
      });
      final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
      addTearDown(() => api.dio.close(force: true));
      var prompts = 0;
      final result = await AuthFlow(api).submit(
        '/auth/register',
        {
          'username': 'tester',
          'email': 'test@example.invalid',
          'password': 'pw',
        },
        verify: () async {
          prompts++;
          return 'expired-test-token';
        },
      );
      expect(result.errorMessage, '人机验证失败，请重试');
      expect(count, 2);
      expect(prompts, 1);
    },
  );

  test('login cookie is available to another API client', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('/login')) {
        request.response.cookies.add(
          Cookie('test_session', 'local-test-only')
            ..httpOnly = true
            ..path = '/',
        );
        request.response.write(
          jsonEncode({
            'ok': true,
            'data': {
              'user': {'id': 'test'},
            },
          }),
        );
      } else {
        final authenticated = request.cookies.any(
          (c) => c.name == 'test_session' && c.value == 'local-test-only',
        );
        request.response.write(
          jsonEncode({
            'ok': authenticated,
            'data': {
              'user': {'id': 'test'},
            },
          }),
        );
        request.response.cookies.add(
          Cookie('test_session', '')
            ..path = '/'
            ..maxAge = 0,
        );
      }
      await request.response.close();
    });
    final base = 'http://127.0.0.1:${server.port}/api';
    final login = ApiClient(baseUrl: base);
    final profile = ApiClient(baseUrl: base);
    addTearDown(() {
      login.dio.close(force: true);
      profile.dio.close(force: true);
    });
    final result = await AuthFlow(login).submit(
      '/auth/login',
      {'login': 'tester', 'password': 'pw'},
      verify: () async {
        fail('Server did not request CAPTCHA');
      },
    );
    expect(result.isSuccess, isTrue);
    expect((await profile.get('/auth/me')).data['user']['id'], 'test');
  });
}
