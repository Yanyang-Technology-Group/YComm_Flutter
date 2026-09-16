import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'api_result.dart';

import 'package:path_provider/path_provider.dart';

class ApiClient {
  static CookieJar _sessionCookies = CookieJar();
  static Future<void> initialize() async {
    final directory = await getApplicationSupportDirectory();
    _sessionCookies = PersistCookieJar(
      storage: FileStorage('${directory.path}/session/'),
    );
  }

  Future<Map<String, String>> socketHeaders() async {
    final uri = Uri.parse(dio.options.baseUrl);
    final cookies = await _sessionCookies.loadForRequest(
      uri.replace(path: '${uri.path}/ws'),
    );
    return {
      'Origin': uri.origin,
      'Cookie': cookies.map((c) => '${c.name}=${c.value}').join('; '),
    };
  }

  /// Receives only the community session confirmed by the isolated OAuth flow.
  Future<void> acceptGithubSession(List<Cookie> cookies) async {
    final origin = Uri.parse('https://community.yanyn.cn');
    if (cookies.isEmpty ||
        cookies.any(
          (cookie) =>
              !cookie.secure ||
              !cookie.httpOnly ||
              cookie.path != '/' ||
              (cookie.domain != null && cookie.domain!.isNotEmpty) ||
              cookie.name.startsWith('oauth_') ||
              cookie.value.isEmpty,
        )) {
      throw const FormatException('Invalid community session');
    }
    await _sessionCookies.saveFromResponse(origin, cookies);
  }

  Future<void> clearSession() => _sessionCookies.deleteAll();
  ApiClient({String? baseUrl})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? 'https://community.yanyn.cn/api',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          validateStatus: (status) => status != null && status < 500,
        ),
      ) {
    dio.interceptors.add(CookieManager(_sessionCookies));
  }
  final Dio dio;

  Future<ApiResult<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      if (response.data is Map<String, dynamic>) {
        return ApiResult.fromJson(response.data as Map<String, dynamic>);
      }
      return ApiResult.fromJson({
        'ok': false,
        'error': {'code': 'INVALID_RESPONSE', 'message': '服务器返回了无法识别的内容，请稍后重试'},
      });
    } on DioException catch (error) {
      final response = error.response?.data;
      if (response is Map<String, dynamic> && response['ok'] == false) {
        return ApiResult.fromJson(response);
      }
      return ApiResult.fromJson({
        'ok': false,
        'error': {
          'code': error.response?.statusCode?.toString() ?? 'NETWORK',
          'message': error.response?.statusCode != null
              ? '服务暂时不可用（${error.response!.statusCode}），请稍后重试'
              : error.type == DioExceptionType.connectionTimeout ||
                    error.type == DioExceptionType.receiveTimeout
              ? '连接超时，请检查网络后重试'
              : '网络暂时不可用，请检查连接后重试',
        },
      });
    }
  }

  Future<ApiResult<dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await dio.post<dynamic>(path, data: data);
      if (response.data is Map<String, dynamic>) {
        return ApiResult.fromJson(response.data as Map<String, dynamic>);
      }
      return ApiResult.fromJson({
        'ok': false,
        'error': {'code': 'INVALID_RESPONSE', 'message': '服务器返回了无法识别的内容，请稍后重试'},
      });
    } on DioException catch (error) {
      final response = error.response?.data;
      if (response is Map<String, dynamic> && response['ok'] == false) {
        return ApiResult.fromJson(response);
      }
      return ApiResult.fromJson({
        'ok': false,
        'error': {
          'code': error.response?.statusCode?.toString() ?? 'NETWORK',
          'message': error.response?.statusCode != null
              ? '服务暂时不可用（${error.response!.statusCode}），请稍后重试'
              : error.type == DioExceptionType.connectionTimeout ||
                    error.type == DioExceptionType.receiveTimeout
              ? '连接超时，请检查网络后重试'
              : '网络暂时不可用，请检查连接后重试',
        },
      });
    }
  }
}
