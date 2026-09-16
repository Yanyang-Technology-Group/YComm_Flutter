import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/api_result.dart';

void main() {
  test('shows the actionable field issue instead of validation summary', () {
    final result = ApiResult.fromJson({
      'ok': false,
      'error': {
        'code': 'VALIDATION_FAILED',
        'messageKey': 'VALIDATION_FAILED',
        'message': 'Request validation failed',
        'meta': {
          'issues': [
            {'path': 'captchaToken', 'message': '请完成人机验证'},
          ],
        },
      },
    });
    expect(result.errorMessage, '请完成人机验证');
  });
}
