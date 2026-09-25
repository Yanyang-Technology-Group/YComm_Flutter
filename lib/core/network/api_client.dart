import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'api_debug.dart';
import 'api_result.dart';

import 'package:path_provider/path_provider.dart';

/// 原生请求的可识别 User-Agent：固定格式，仅客户端名 + 平台，不含任何个人信息。
/// 后端只用它做「登录设备」的展示推断，不参与鉴权。
///
/// Flutter Web 返回 null —— 浏览器禁止脚本改写 `User-Agent` 请求头。
String? nativeUserAgent() {
  if (kIsWeb) return null;
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
  return 'YCommFlutter/$platform';
}

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
          headers: {
            // 原生附带可识别 UA；Web 上不设置（浏览器禁止改写 User-Agent）。
            if (nativeUserAgent() != null) 'User-Agent': nativeUserAgent(),
          },
        ),
      ) {
    dio.interceptors.add(CookieManager(_sessionCookies));
  }
  final Dio dio;

  Future<ApiResult<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _request('GET', path, queryParameters: queryParameters);

  Future<ApiResult<dynamic>> post(String path, {Map<String, dynamic>? data}) =>
      _request('POST', path, data: data);

  Future<ApiResult<dynamic>> patch(String path, {Map<String, dynamic>? data}) =>
      _request('PATCH', path, data: data);

  Future<ApiResult<dynamic>> delete(String path) => _request('DELETE', path);

  /// API 浏览器的调试请求。
  ///
  /// 与 [_request] 不同：不解析成功/失败信封，把原始状态码、响应体和耗时原样
  /// 返回给界面展示；HTTP 错误也照样返回，由调用方决定怎么显示。
  ///
  /// [method] 之外的取值会被当成 GET；GET 的 [data] 进 query，其余进 body。
  Future<ApiDebugResponse> runDebugRequest({
    required String method,
    required String route,
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    final verb = switch (method.toUpperCase()) {
      'POST' => 'POST',
      'PATCH' => 'PATCH',
      'DELETE' => 'DELETE',
      _ => 'GET',
    };
    final cleanRoute = route.trim();
    final cleanQuery = <String, dynamic>{
      for (final entry in (query ?? const {}).entries)
        if (entry.value != null && '${entry.value}'.trim().isNotEmpty)
          entry.key: '${entry.value}'.trim(),
    };
    final cleanData = <String, dynamic>{
      for (final entry in (data ?? const {}).entries)
        if (entry.value != null && '${entry.value}'.trim().isNotEmpty)
          entry.key: '${entry.value}'.trim(),
    };
    final timer = Stopwatch()..start();
    final response = await dio.request<dynamic>(
      cleanRoute,
      data: verb == 'GET' ? null : cleanData,
      queryParameters: verb == 'GET'
          ? {...cleanQuery, ...cleanData}
          : cleanQuery,
      options: Options(method: verb, responseType: ResponseType.plain),
    );
    timer.stop();
    final body = response.data is String
        ? response.data as String
        : (response.data == null ? '' : jsonEncode(response.data));
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      /* 非 JSON 响应直接展示原文。 */
    }
    return ApiDebugResponse(
      method: verb,
      route: cleanRoute,
      statusCode: response.statusCode ?? 0,
      elapsedMs: timer.elapsedMilliseconds,
      body: body,
      decoded: decoded,
    );
  }

  Future<ApiResult<dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method),
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
}
