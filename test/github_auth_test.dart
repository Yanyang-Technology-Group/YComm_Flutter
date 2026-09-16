import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/features/auth/github_auth.dart';
import 'package:ycomm_client/core/network/api_client.dart';

// The adapter replaces only the remote service; Dio redirects, real cookie
// handling, state validation and session confirmation remain production code.
class OAuthServer implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String? failure;
  String? authorizationOverride;
  String? cookieOverride;
  bool authenticated = true;
  Completer<void>? pendingMe;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    if (path == '/api/auth/github') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            authorizationOverride ?? 'https://github.com/login/oauth/authorize?client_id=fixture&redirect_uri=https%3A%2F%2Fcommunity.yanyn.cn%2Fapi%2Fauth%2Fgithub%2Fcallback&state=fixture-state',
          ],
          'set-cookie': [
            cookieOverride ?? 'oauth_state=fixture-state; Secure; HttpOnly; Path=/; SameSite=Lax',
          ],
        },
      );
    }
    if (path == '/api/auth/github/callback') {
      expect(
        options.headers['cookie'].toString(),
        contains('oauth_state=fixture-state'),
      );
      expect(options.followRedirects, false);
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [failure == null ? '/' : '/login?oauth=$failure'],
          'set-cookie': [
            'oauth_state=; Secure; HttpOnly; Path=/; Max-Age=0',
            if (failure == null) '__Host-ycomm_session=fixture-session; Secure; HttpOnly; Path=/; SameSite=Lax',
          ],
        },
      );
    }
    if (path == '/api/auth/me') {
      if (pendingMe != null) await pendingMe!.future;
      expect(
        options.headers['cookie'].toString(),
        contains('__Host-ycomm_session=fixture-session'),
      );
      return ResponseBody.fromString(
        jsonEncode(
          authenticated
              ? {
                  'ok': true,
                  'data': {
                    'user': {'id': 'fixture-user', 'username': 'fixture'},
                  },
                }
              : {
                  'ok': false,
                  'error': {'code': 'UNAUTHENTICATED'},
                },
        ),
        authenticated ? 200 : 401,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    throw StateError('Unexpected endpoint $path');
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const callback =
      'https://community.yanyn.cn/api/auth/github/callback?state=fixture-state&code=fixture-code';
  late OAuthServer server;
  late GithubAuth auth;
  setUp(() {
    server = OAuthServer();
    auth = GithubAuth(transport: Dio()..httpClientAdapter = server);
  });
  tearDown(() => auth.close());

  test('existing web OAuth creates a confirmed native session without browser cookie scraping', () async {
    final authorize = await auth.start();
    expect(authorize.host, 'github.com');
    final cookies = await auth.finish(Uri.parse(callback));
    expect(cookies.single.name, '__Host-ycomm_session');
    expect(cookies.single.value, 'fixture-session');
    final api = ApiClient();
    addTearDown(() async {
      await api.clearSession();
      api.dio.close(force: true);
    });
    await api.clearSession();
    expect((await api.socketHeaders())['Cookie'], isEmpty);
    await api.acceptGithubSession(cookies);
    final another = ApiClient();
    addTearDown(() => another.dio.close(force: true));
    expect(
      (await another.socketHeaders())['Cookie'],
      '__Host-ycomm_session=fixture-session',
    );
    expect(server.requests.map((r) => r.uri.path), [
      '/api/auth/github',
      '/api/auth/github/callback',
      '/api/auth/me',
    ]);
    await expectLater(
      auth.finish(Uri.parse(callback)),
      throwsA(isA<GithubAuthException>()),
    );
  });
  test(
    'rejects a provider URL or state cookie substituted at startup',
    () async {
      server.authorizationOverride = 'https://github.com.evil.test/login/oauth/authorize?state=fixture-state';
      await expectLater(auth.start(), throwsA(isA<GithubAuthException>()));
      auth.close();
      server.authorizationOverride = null;
      server.cookieOverride =
          'oauth_state=another-state; Secure; HttpOnly; Path=/';
      auth = GithubAuth(transport: Dio()..httpClientAdapter = server);
      await expectLater(auth.start(), throwsA(isA<GithubAuthException>()));
    },
  );
  test('navigation accepts only the official HTTPS GitHub origin', () {
    expect(
      GithubAuth.isGithubPage(Uri.parse('https://github.com/login')),
      true,
    );
    for (final value in [
      'https://github.com.evil.test/login',
      'https://github.com:444/login',
      'http://github.com/login',
      'https://user@github.com/login',
      'file:///etc/passwd',
      'intent://github.com',
    ]) {
      expect(GithubAuth.isGithubPage(Uri.parse(value)), false);
    }
  });
  test('rejects wrong state and never exchanges its code', () async {
    await auth.start();
    await expectLater(
      auth.finish(Uri.parse(callback.replaceFirst('fixture-state', 'wrong'))),
      throwsA(isA<GithubAuthException>()),
    );
    expect(server.requests.length, 1);
  });
  test(
    'rejects lookalike callback origins and duplicate query parameters',
    () async {
      await auth.start();
      for (final url in [
        callback.replaceFirst(
          'community.yanyn.cn',
          'community.yanyn.cn.evil.test',
        ),
        callback.replaceFirst('https:', 'http:'),
        callback.replaceFirst('/callback?', '/callback/extra?'),
        '$callback&state=other',
        '$callback#fragment',
      ]) {
        await expectLater(
          auth.finish(Uri.parse(url)),
          throwsA(isA<GithubAuthException>()),
        );
      }
      expect(server.requests.length, 1);
    },
  );
  test(
    'denied authorization and backend failures have readable errors',
    () async {
      await auth.start();
      await expectLater(
        auth.finish(
          Uri.parse(
            callback.replaceFirst('code=fixture-code', 'error=access_denied'),
          ),
        ),
        throwsA(
          isA<GithubAuthException>().having(
            (e) => e.message,
            'message',
            contains('取消'),
          ),
        ),
      );
      expect(server.requests.length, 1);
      auth.close();
      auth = GithubAuth(transport: Dio()..httpClientAdapter = server);
      server.failure = 'banned';
      await auth.start();
      await expectLater(
        auth.finish(Uri.parse(callback)),
        throwsA(
          isA<GithubAuthException>().having(
            (e) => e.message,
            'message',
            contains('封禁'),
          ),
        ),
      );
    },
  );
  test('redirect alone does not count as a signed-in session', () async {
    server.authenticated = false;
    await auth.start();
    await expectLater(
      auth.finish(Uri.parse(callback)),
      throwsA(isA<GithubAuthException>()),
    );
  });
  test(
    'cancellation during session verification cannot yield cookies',
    () async {
      server.pendingMe = Completer<void>();
      await auth.start();
      final result = auth.finish(Uri.parse(callback));
      final assertion = expectLater(
        result,
        throwsA(isA<GithubAuthException>()),
      );
      while (!server.requests.any((r) => r.uri.path.endsWith('/me'))) {
        await Future<void>.delayed(Duration.zero);
      }
      auth.close();
      server.pendingMe!.complete();
      await assertion;
    },
  );
}
