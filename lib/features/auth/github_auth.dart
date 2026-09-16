import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class GithubAuthException implements Exception {
  const GithubAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns one OAuth attempt. Only the official authorize page enters the WebView;
/// state and community cookies stay in this isolated native HTTP client.
class GithubAuth {
  GithubAuth({Dio? transport}) : _http = transport ?? Dio() {
    _http.options = BaseOptions(
      baseUrl: origin,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 70),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    );
    _http.interceptors.add(CookieManager(_cookies));
  }
  static const origin = 'https://community.yanyn.cn';
  static final callback = Uri.parse('$origin/api/auth/github/callback');
  final Dio _http;
  final CookieJar _cookies = CookieJar();
  final CancelToken _cancel = CancelToken();
  String? _state;
  bool _used = false, _closed = false, _started = false;
  DateTime? _expires;

  bool isCallback(Uri uri) =>
      uri.scheme == 'https' &&
      uri.origin == callback.origin &&
      uri.path == callback.path &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment;

  static bool isGithubPage(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'github.com' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty;

  void _checkOpen() {
    if (_closed) throw const GithubAuthException('已取消 GitHub 登录');
  }

  Future<Response<dynamic>> _get(String url) async {
    _checkOpen();
    try {
      final response = await _http.get<dynamic>(url, cancelToken: _cancel);
      _checkOpen();
      return response;
    } on DioException {
      _checkOpen();
      throw const GithubAuthException('连接授权服务失败，请检查网络后重新尝试');
    }
  }

  Uri _redirect(Response<dynamic> response) {
    final location = response.headers.value('location');
    if (response.statusCode != 302 || location == null) {
      throw GithubAuthException(
        response.statusCode == 404 ? '服务器尚未开启 GitHub 登录' : '授权服务返回异常，请重新尝试',
      );
    }
    return Uri.parse(origin).resolve(location);
  }

  Future<Uri> start() async {
    _checkOpen();
    if (_started) throw const GithubAuthException('请重新开始 GitHub 登录');
    _started = true;
    final url = _redirect(await _get('/api/auth/github'));
    final state = url.queryParametersAll['state'];
    final stateCookies = (await _cookies.loadForRequest(callback))
        .where((cookie) => cookie.name == 'oauth_state')
        .toList();
    if (!isGithubPage(url) ||
        url.path != '/login/oauth/authorize' ||
        url.hasFragment ||
        state == null ||
        state.length != 1 ||
        state.single.isEmpty ||
        url.queryParameters['redirect_uri'] != callback.toString() ||
        stateCookies.length != 1 ||
        stateCookies.single.value != state.single) {
      throw const GithubAuthException('授权地址校验失败，请稍后重试');
    }
    _state = state.single;
    _expires = DateTime.now().add(const Duration(minutes: 30));
    return url;
  }

  Future<List<Cookie>> finish(Uri uri) async {
    _checkOpen();
    final states = uri.queryParametersAll['state'];
    final codes = uri.queryParametersAll['code'];
    if (_used ||
        _state == null ||
        _expires!.isBefore(DateTime.now()) ||
        !isCallback(uri) ||
        states == null ||
        states.length != 1 ||
        states.single != _state ||
        uri.queryParametersAll.values.any((v) => v.length != 1)) {
      throw const GithubAuthException('授权状态不匹配或已过期，请重新登录');
    }
    if (uri.queryParameters.containsKey('error')) {
      _used = true;
      throw const GithubAuthException('你取消了 GitHub 授权，可重新尝试');
    }
    if (codes == null || codes.single.isEmpty) {
      throw const GithubAuthException('授权结果不完整，请重新登录');
    }
    _used = true;
    final destination = _redirect(await _get(uri.toString()));
    if (destination.origin != origin || destination.userInfo.isNotEmpty) {
      throw const GithubAuthException('授权回调地址异常，请重新尝试');
    }
    if (destination.path == '/login') {
      throw GithubAuthException(
        _errors[destination.queryParameters['oauth']] ?? 'GitHub 登录失败，请重新尝试',
      );
    }
    if (destination.path != '/' ||
        destination.hasQuery ||
        destination.hasFragment) {
      throw const GithubAuthException('授权结果异常，请重新尝试');
    }
    final me = await _get('/api/auth/me');
    final data = me.data;
    if (me.statusCode != 200 ||
        data is! Map ||
        data['ok'] != true ||
        data['data'] is! Map ||
        data['data']['user'] is! Map ||
        data['data']['user']['id'] is! String) {
      throw const GithubAuthException('未能确认社区登录状态，请重新登录');
    }
    final cookies =
        (await _cookies.loadForRequest(Uri.parse('$origin/api/auth/me')))
            .where(
              (cookie) =>
                  cookie.secure &&
                  cookie.httpOnly &&
                  cookie.path == '/' &&
                  (cookie.domain == null || cookie.domain!.isEmpty) &&
                  !cookie.name.startsWith('oauth_') &&
                  cookie.value.isNotEmpty,
            )
            .toList();
    _checkOpen();
    if (cookies.isEmpty) throw const GithubAuthException('未收到有效的社区会话，请重新登录');
    return cookies;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _cancel.cancel();
    _http.close(force: true);
  }

  static const _errors = {
    'denied': '你取消了 GitHub 授权，可重新尝试',
    'state': '授权已过期，请重新登录',
    'token': 'GitHub 授权校验失败，请重新尝试',
    'profile': '读取 GitHub 资料失败，请重新尝试',
    'network': '服务器连接 GitHub 超时，请稍后重试',
    'deleted': '该账号已注销，无法登录',
    'banned': '该账号已被封禁，无法登录',
  };
}
