import 'dart:convert';

/// API 浏览器一次调试请求的原始响应。
class ApiDebugResponse {
  const ApiDebugResponse({
    required this.method,
    required this.route,
    required this.statusCode,
    required this.elapsedMs,
    required this.body,
    required this.decoded,
  });

  final String method;
  final String route;
  final int statusCode;
  final int elapsedMs;

  /// 原始响应体。
  final String body;

  /// 解析成功时的 JSON 对象；解析失败为 null。
  final Object? decoded;

  /// 展示用文本：能解析成 JSON 就缩进打印，否则回落到原始 body。
  String get prettyBody {
    if (decoded != null) {
      try {
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        /* 落到下面的原始 body。 */
      }
    }
    return body;
  }
}
