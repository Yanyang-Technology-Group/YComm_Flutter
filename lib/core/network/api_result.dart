class ApiResult<T> {
  const ApiResult._({
    required this.isSuccess,
    this.data,
    this.code,
    this.errorMessage,
    this.fieldErrors = const {},
  });

  final bool isSuccess;
  final T? data;
  final String? code;
  final String? errorMessage;
  final Map<String, String> fieldErrors;

  factory ApiResult.fromJson(Map<String, dynamic> json) {
    final ok = json['ok'] == true;
    if (ok) return ApiResult._(isSuccess: true, data: json['data'] as T?);
    final error = json['error'] is Map
        ? Map<String, dynamic>.from(json['error'] as Map)
        : const <String, dynamic>{};
    final fields = <String, String>{};
    final meta = error['meta'];
    if (meta is Map && meta['issues'] is List) {
      for (final issue in meta['issues'] as List) {
        if (issue is Map && issue['message'] is String) {
          final path = issue['path'];
          fields[path is List ? path.join('.') : (path?.toString() ?? '')] =
              issue['message'] as String;
        }
      }
    }
    return ApiResult._(
      isSuccess: false,
      fieldErrors: Map.unmodifiable(fields),
      code: error['code']?.toString(),
      errorMessage:
          (fields.isNotEmpty ? fields.values.join('\n') : null) ??
          error['message']?.toString() ??
          error['messageKey']?.toString() ??
          '请求失败',
    );
  }
}
