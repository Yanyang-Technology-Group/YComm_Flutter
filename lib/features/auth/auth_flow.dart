import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';

/// CAP tokens are single-use. Never cache or replay one after a submission.
class AuthFlow {
  AuthFlow(this.api);
  final ApiClient api;

  Future<ApiResult<dynamic>> submit(
    String path,
    Map<String, dynamic> data, {
    required Future<String?> Function() verify,
  }) async {
    final result = await api.post(path, data: data);
    if (!result.fieldErrors.containsKey('captchaToken')) return result;
    final token = await verify();
    if (token == null || token.isEmpty) {
      return ApiResult.fromJson({
        'ok': false,
        'error': {'code': 'CAPTCHA_CANCELLED', 'message': '尚未完成人机验证，请重试'},
      });
    }
    return api.post(path, data: {...data, 'captchaToken': token});
  }
}
