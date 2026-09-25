import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/features/api/api_doc.dart';

void main() {
  test('清单非空且分组齐全', () {
    expect(apiDocEndpoints, isNotEmpty);
    expect(
      apiDocEndpoints.map((e) => e.group).toSet(),
      containsAll(<String>{
        'Auth',
        'Users',
        'Forum',
        'Downloads',
        'Notifications',
      }),
    );
  });

  test('route + method 唯一', () {
    final keys = apiDocEndpoints
        .map((e) => '${e.methodLabel} ${e.route}')
        .toList();
    expect(keys.toSet().length, keys.length);
  });

  test('每个接口都有摘要与描述', () {
    for (final endpoint in apiDocEndpoints) {
      expect(endpoint.summary, isNotEmpty, reason: endpoint.route);
      expect(endpoint.description, isNotEmpty, reason: endpoint.route);
    }
  });

  test('必填参数都有示例值', () {
    for (final endpoint in apiDocEndpoints) {
      for (final param in endpoint.params.where((p) => p.required)) {
        expect(
          param.example,
          isNotEmpty,
          reason: '${endpoint.route}#${param.name}',
        );
      }
    }
  });

  test('参数名在同一个接口内唯一', () {
    for (final endpoint in apiDocEndpoints) {
      final names = endpoint.params.map((p) => p.name).toList();
      expect(
        names.toSet().length,
        names.length,
        reason: '${endpoint.route} 参数名重复',
      );
    }
  });

  test('methodLabel 覆盖四种方法', () {
    const endpoint = ApiDocEndpoint(
      group: 'X',
      route: '/x',
      method: ApiDocMethod.delete,
      summary: 's',
      description: 'd',
    );
    expect(endpoint.methodLabel, 'DELETE');
    for (final method in ApiDocMethod.values) {
      final label = ApiDocEndpoint(
        group: 'X',
        route: '/x',
        method: method,
        summary: 's',
        description: 'd',
      ).methodLabel;
      expect(label, isNotEmpty);
    }
  });
}
