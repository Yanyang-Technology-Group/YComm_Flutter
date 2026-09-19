// 应用版本信息。
//
// 发布构建由 CI 注入规范版本号（yyyy.mm.dd.<commits>，与 YComm_WebSite 同格式）：
//   flutter build ... --dart-define=YCOMM_VERSION=2026.09.19.9
// 详见 .github/workflows/release.yml。
//
// 本地构建没有注入时，退回 Flutter 依据 pubspec.yaml 自动生成的
// FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER；仓库里提交的是占位值
// 0.0.0+0，这种情况会显示「开发版」。

/// CI 注入的规范版本号，形如 `2026.09.19.9`；未注入时为空串。
const String kCanonicalVersion = String.fromEnvironment('YCOMM_VERSION');

/// Flutter 自动注入的 build-name（取自 pubspec.yaml 的 version 前段）。
const String kFlutterBuildName = String.fromEnvironment('FLUTTER_BUILD_NAME');

/// Flutter 自动注入的 build-number（取自 pubspec.yaml 的 `+` 之后）。
const String kFlutterBuildNumber = String.fromEnvironment('FLUTTER_BUILD_NUMBER');

/// 仓库中提交的版本号占位值，表示「未由 CI 注入」。
const String _placeholderBuildName = '0.0.0';

/// 关于页展示用的版本号。
String get appVersionLabel {
  if (kCanonicalVersion.isNotEmpty) {
    return kCanonicalVersion;
  }
  if (kFlutterBuildName.isEmpty || kFlutterBuildName == _placeholderBuildName) {
    return '开发版';
  }
  return kFlutterBuildNumber.isEmpty
      ? kFlutterBuildName
      : '$kFlutterBuildName+$kFlutterBuildNumber';
}
