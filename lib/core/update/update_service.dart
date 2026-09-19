// 客户端自动更新的数据来源：社区下载区里「社区客户端APP」那张卡片的树。
//
// 卡片结构（见 https://community.yanyn.cn/downloads/card/<id>）：
//   客户端卡片 157664f3-…            kind=container，subtitle 里有 SHA256SUMS 链接
//   ├── 平台卡片（Windows/Linux/Android…）  kind=container
//   │   └── 版本卡片（标题就是版本号 yyyy.mm.dd.commits）kind=container
//   │       ├── 安装包卡片  kind=redirect，redirectUrl 指向真实文件
//   │       └── 免安装卡片  kind=redirect
//
// 所以「有没有新版本」= 平台卡片下版本号最大的那张版本卡片，和当前版本比大小。
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../app_info.dart';
import '../network/community_api.dart';

/// 下载区里「社区客户端APP」卡片的固定 ID。
const String kClientCardId = '157664f3-7ae8-4509-b032-ebf1437b11ce';

/// 当前平台在下载区里对应的分类名；没有对应分类时返回 null。
///
/// Web 不参与自动更新，直接返回 null。用 [defaultTargetPlatform] 而不是
/// `dart:io` 的 `Platform`，这样 Web 构建也能编译。
String? updatePlatformName() {
  if (kIsWeb) {
    return null;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.android => 'Android',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.iOS => 'iOS',
    _ => null,
  };
}

/// 逐段比较版本号：a 更新返回正数，相同返回 0，更旧返回负数。
int compareVersions(List<int> a, List<int> b) {
  for (var i = 0; i < 4; i++) {
    final left = i < a.length ? a[i] : 0;
    final right = i < b.length ? b[i] : 0;
    if (left != right) {
      return left - right;
    }
  }
  return 0;
}

/// 各平台优先推荐的安装包后缀，安装版排在免安装版前面。
const Map<String, List<String>> _preferredSuffixes = {
  'Windows': ['.exe', '.msi', '.zip'],
  'Linux': ['.deb', '.rpm', '.tar.gz'],
  'Android': ['.apk', '.aab'],
  'macOS': ['.dmg', '.pkg', '.zip'],
  'iOS': ['.ipa'],
};

/// 一次可下载的更新。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.fileName,
    required this.downloadUrl,
    this.note = '',
    this.checksumUrl,
  });

  /// 线上版本号，形如 `2026.09.19.12`。
  final String version;

  /// 安装包文件名（用于下载后保存与展示）。
  final String fileName;

  /// 实际下载地址。
  final String downloadUrl;

  /// 版本卡片上的说明文字。
  final String note;

  /// 校验文件地址（卡片 subtitle 里的第一个链接），没有则为 null。
  final String? checksumUrl;
}

/// 从客户端卡片标题里取第一个 Markdown 链接，用作校验文件地址。
String? _firstLink(String markdown) {
  final match = RegExp(r'\]\((https?://[^)\s]+)\)').firstMatch(markdown);
  return match?.group(1);
}

/// 从下载区卡片里解析出比 [currentVersion] 更新的版本；没有则返回 null。
///
/// 纯函数，不碰网络，方便单测。返回 null 的几种情况：
/// 平台没有对应分类、没有版本卡片、已是最新、版本卡片下没有可下载文件。
UpdateInfo? resolveUpdate({
  required List<Json> cards,
  required String? platformName,
  required List<int>? currentVersion,
}) {
  if (platformName == null) {
    return null;
  }

  final clientCard = cards.where((c) => c['id'] == kClientCardId).firstOrNull;
  final platformCard = cards
      .where(
        (c) =>
            c['parentId'] == kClientCardId && str(c['title']) == platformName,
      )
      .firstOrNull;
  if (platformCard == null) {
    return null;
  }

  // 版本卡片：标题能解析成版本号的子卡片，取最大的那个。
  final versions =
      cards
          .where((c) => c['parentId'] == platformCard['id'])
          .map((c) => (card: c, parts: parseVersionParts(str(c['title']))))
          .where((e) => e.parts != null)
          .toList()
        ..sort((a, b) => compareVersions(b.parts!, a.parts!));
  if (versions.isEmpty) {
    return null;
  }

  final latest = versions.first;
  if (currentVersion != null &&
      compareVersions(latest.parts!, currentVersion) <= 0) {
    return null;
  }

  final files = cards
      .where(
        (c) =>
            c['parentId'] == latest.card['id'] &&
            str(c['redirectUrl']).isNotEmpty,
      )
      .toList();
  if (files.isEmpty) {
    return null;
  }

  Json? chosen;
  for (final suffix in _preferredSuffixes[platformName] ?? const <String>[]) {
    chosen = files
        .where((f) => str(f['title']).toLowerCase().endsWith(suffix))
        .firstOrNull;
    if (chosen != null) {
      break;
    }
  }
  chosen ??= files.first;

  return UpdateInfo(
    version: str(latest.card['title']),
    fileName: str(chosen['title']),
    downloadUrl: str(chosen['redirectUrl']),
    note: str(latest.card['subtitle']),
    checksumUrl: clientCard == null
        ? null
        : _firstLink(str(clientCard['subtitle'])),
  );
}

/// 拉取下载区卡片并解析出可下载的版本。
class UpdateService {
  UpdateService(this.api);

  final CommunityApi api;

  /// [currentVersion] 为 null 时不做比较，直接返回线上最新版本。
  Future<UpdateInfo?> fetch({required List<int>? currentVersion}) async {
    final cards = jsonList((await api.get('/downloads/cards'))['cards']);
    return resolveUpdate(
      cards: cards,
      platformName: updatePlatformName(),
      currentVersion: currentVersion,
    );
  }
}
