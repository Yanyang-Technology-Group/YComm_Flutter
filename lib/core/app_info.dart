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

/// 把 `yyyy.mm.dd.commits` 解析成可逐段比较的整数数组；格式不符时返回 null。
List<int>? parseVersionParts(String raw) {
  final match = RegExp(
    r'^(\d{4})\.(\d{1,2})\.(\d{1,2})\.(\d+)$',
  ).firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  return [for (var i = 1; i <= 4; i++) int.parse(match.group(i)!)];
}

/// 当前构建用于比较更新的版本号。
///
/// 只有拿到 CI 注入的 `YCOMM_VERSION` 才有意义；开发构建返回 null，
/// 调用方据此跳过比较（不能拿 `0.0.0+0` 去和线上版本比大小）。
List<int>? get appVersionParts =>
    kCanonicalVersion.isEmpty ? null : parseVersionParts(kCanonicalVersion);
