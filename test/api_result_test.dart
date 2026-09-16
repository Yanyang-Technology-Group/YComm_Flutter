import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/api_result.dart';

void main() {
  test('parses standard success envelope', () {
    final result = ApiResult.fromJson({
      'ok': true,
      'data': {'count': 3},
    });
    expect(result.isSuccess, isTrue);
    expect(result.data, {'count': 3});
  });

  test('parses standard error envelope', () {
    final result = ApiResult.fromJson({
      'ok': false,
      'error': {'code': 'UNAUTHENTICATED', 'message': '请先登录'},
    });
    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, '请先登录');
  });
}
