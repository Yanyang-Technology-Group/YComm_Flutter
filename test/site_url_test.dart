import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/widgets/design.dart';

void main() {
  group('resolveSiteUrl：服务端给的相对路径要补成绝对地址', () {
    test('以 / 开头的站内路径', () {
      expect(
        resolveSiteUrl('/uploads/images/abc.png').toString(),
        'https://community.yanyn.cn/uploads/images/abc.png',
      );
    });

    test('漏了斜杠的相对路径', () {
      expect(
        resolveSiteUrl('uploads/images/abc.png').toString(),
        'https://community.yanyn.cn/uploads/images/abc.png',
      );
    });

    test('协议相对地址沿用 https', () {
      expect(
        resolveSiteUrl('//cdn.example.com/a.png').toString(),
        'https://cdn.example.com/a.png',
      );
    });

    test('已经是绝对地址的原样返回', () {
      expect(
        resolveSiteUrl('https://other.example/a.png').toString(),
        'https://other.example/a.png',
      );
      expect(
        resolveSiteUrl('http://other.example/a.png').toString(),
        'http://other.example/a.png',
      );
    });

    test('去掉首尾空白', () {
      expect(
        resolveSiteUrl('  /a.png  ').toString(),
        'https://community.yanyn.cn/a.png',
      );
    });

    test('空值与空白返回 null，交给调用方走占位', () {
      expect(resolveSiteUrl(null), isNull);
      expect(resolveSiteUrl(''), isNull);
      expect(resolveSiteUrl('   '), isNull);
    });

    test('解析结果一定是 http/https，不会是别的 scheme', () {
      for (final raw in ['/a.png', 'a.png', '//cdn.x/a.png']) {
        final uri = resolveSiteUrl(raw)!;
        expect(['http', 'https'], contains(uri.scheme));
      }
    });
  });
}
