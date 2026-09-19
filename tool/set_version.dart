// 把 pubspec.yaml 的顶层 `version:` 改写成给定值。
//
// 为什么需要它：Web 产物的 version.json（Service Worker 判断是否需要更新）只从
// pubspec.yaml 读取版本，桌面平台的 generated_config.cmake / Generated.xcconfig
// 同样以 pubspec.yaml 为准。因此发布时必须先把版本号写进 pubspec.yaml，再执行构建。
//
// 用正则只替换该行的内容、不碰行尾，保证 CRLF/LF 原样保留。
//
// 用法：
//   dart run tool/set_version.dart 2026.09.19+9
import 'dart:io';

/// 匹配顶层的 `version:` 行，但不吃进行尾的 \r / \n。
final RegExp _versionLine = RegExp(r'^version:[^\r\n]*', multiLine: true);

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('用法: dart run tool/set_version.dart <version>');
    exit(64);
  }

  final version = args.single;
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    stderr.writeln('找不到 pubspec.yaml，请在项目根目录运行。');
    exit(66);
  }

  final content = file.readAsStringSync();
  if (!_versionLine.hasMatch(content)) {
    stderr.writeln('pubspec.yaml 中没有顶层 version: 行。');
    exit(65);
  }

  file.writeAsStringSync(
    content.replaceFirst(_versionLine, 'version: $version'),
  );
  stdout.writeln('pubspec.yaml version → $version');
}
