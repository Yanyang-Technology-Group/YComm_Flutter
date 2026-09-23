// 客户端自动更新的数据来源：社区下载区里「社区客户端APP」那张卡片的树。
//
// 卡片结构（见 https://community.yanyn.cn/downloads/card/<id>）：
//   客户端卡片「社区客户端APP」          kind=container，subtitle 里有 SHA256SUMS 链接
//   ├── 平台卡片（Windows/Linux/Android…）  kind=container
//   │   └── 版本卡片（标题就是版本号 yyyy.mm.dd.commits）kind=container
//   │       ├── 安装包卡片  kind=redirect，redirectUrl 指向真实文件
//   │       └── 免安装卡片  kind=redirect
//
// 注意：卡片是站长在后台手工维护的，删掉重建之后 ID（甚至标题）都会变，
// 所以不能把 ID 写死 —— 见 _findClientCard 的三级查找。
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../app_info.dart';
import '../network/community_api.dart';

/// 客户端卡片在下载区里的标题。
const String kClientCardTitle = '社区客户端APP';

/// 早期版本的固定 ID：卡片没被重建时可以直接命中，只作快速路径。
const String kLegacyClientCardId = '157664f3-7ae8-4509-b032-ebf1437b11ce';

/// 客户端安装包的文件名前缀，用于在没有固定 ID / 标题时按结构识别。
const String _packagePrefix = 'ycomm-';

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

/// 检查更新的结论。
enum UpdateStatus {
  /// 线上有更新的版本。
  found,

  /// 确认已是最新。
  upToDate,

  /// 拿不到可比较的版本信息（卡片缺失、平台分类没了等）。
  ///
  /// 必须和 [upToDate] 分开：之前把「没找到」当成「已是最新」，
  /// 结果站长一重建卡片，就误报「已是最新」。
  unavailable,

  /// 请求失败。
  failed,
}

class UpdateResolution {
  const UpdateResolution(this.status, {this.info, this.message});

  const UpdateResolution.found(UpdateInfo this.info)
    : status = UpdateStatus.found,
      message = null;

  const UpdateResolution.upToDate()
    : status = UpdateStatus.upToDate,
      info = null,
      message = null;

  const UpdateResolution.unavailable(String this.message)
    : status = UpdateStatus.unavailable,
      info = null;

  final UpdateStatus status;
  final UpdateInfo? info;
  final String? message;
}

/// 各平台优先推荐的安装包后缀，安装版排在免安装版前面。
const Map<String, List<String>> _preferredSuffixes = {
  'Windows': ['.exe', '.msi', '.zip'],
  'Linux': ['.deb', '.rpm', '.tar.gz'],
  'Android': ['.apk', '.aab'],
  'macOS': ['.dmg', '.pkg', '.zip'],
  'iOS': ['.ipa'],
};

/// 从客户端卡片说明里取第一个 Markdown 链接，用作校验文件地址。
String? _firstLink(String markdown) {
  final match = RegExp(r'\]\((https?://[^)\s]+)\)').firstMatch(markdown);
  return match?.group(1);
}

/// 找出「社区客户端APP」那张卡片。
///
/// 三级查找，因为站长重建卡片后 ID 会变、标题也可能改：
///   1. 已知的固定 ID；
///   2. 根卡片里标题匹配的；
///   3. 结构识别：根卡片的子树里存在 `ycomm-*` 下载文件。
Json? _findClientCard(List<Json> cards) {
  for (final card in cards) {
    if (str(card['id']) == kLegacyClientCardId) {
      return card;
    }
  }
  for (final card in cards) {
    if (card['parentId'] == null && str(card['title']) == kClientCardTitle) {
      return card;
    }
  }

  final childrenOf = <String, List<Json>>{};
  for (final card in cards) {
    childrenOf.putIfAbsent(str(card['parentId']), () => []).add(card);
  }
  bool holdsPackages(String id) {
    for (final child in childrenOf[id] ?? const <Json>[]) {
      if (str(child['kind']) == 'redirect' &&
          str(child['title']).startsWith(_packagePrefix)) {
        return true;
      }
      if (holdsPackages(str(child['id']))) {
        return true;
      }
    }
    return false;
  }

  for (final card in cards) {
    if (card['parentId'] == null && holdsPackages(str(card['id']))) {
      return card;
    }
  }
  return null;
}

/// 在客户端的直接子卡片里找平台卡片：先精确匹配，再按包含匹配
/// （站长可能写成「Windows x64」这类名字）。
Json? _findPlatformCard(List<Json> cards, String clientId, String platform) {
  final children = cards.where((c) => str(c['parentId']) == clientId).toList();
  for (final card in children) {
    if (str(card['title']) == platform) {
      return card;
    }
  }
  final lower = platform.toLowerCase();
  for (final card in children) {
    if (str(card['title']).toLowerCase().contains(lower)) {
      return card;
    }
  }
  return null;
}

/// 从下载区卡片里解析出更新结论。
///
/// 纯函数，不碰网络，方便单测。[currentVersion] 为 null 时不做比较，
/// 直接给出线上最新版本（开发构建用）。
UpdateResolution resolveUpdate({
  required List<Json> cards,
  required String? platformName,
  required List<int>? currentVersion,
}) {
  if (platformName == null) {
    return const UpdateResolution.unavailable('当前平台不支持自动更新。');
  }

  final client = _findClientCard(cards);
  if (client == null) {
    return const UpdateResolution.unavailable(
      '下载区里没有找到「社区客户端APP」卡片，可能是站长改动了目录，请到社区下载区查看最新版本。',
    );
  }

  final platformCard = _findPlatformCard(cards, str(client['id']), platformName);
  if (platformCard == null) {
    return UpdateResolution.unavailable(
      '下载区里还没有 $platformName 分类，请到社区下载区查看。',
    );
  }

  final versions =
      cards
          .where((c) => str(c['parentId']) == str(platformCard['id']))
          .map((c) => (card: c, parts: parseVersionParts(str(c['title']))))
          .where((e) => e.parts != null)
          .toList()
        ..sort((a, b) => compareVersions(b.parts!, a.parts!));
  if (versions.isEmpty) {
    return UpdateResolution.unavailable(
      '$platformName 分类下还没有版本卡片，请到社区下载区查看。',
    );
  }

  final latest = versions.first;
  final version = str(latest.card['title']);
  if (currentVersion != null &&
      compareVersions(latest.parts!, currentVersion) <= 0) {
    return const UpdateResolution.upToDate();
  }

  final files = cards
      .where(
        (c) =>
            str(c['parentId']) == str(latest.card['id']) &&
            str(c['redirectUrl']).isNotEmpty,
      )
      .toList();
  if (files.isEmpty) {
    return UpdateResolution.unavailable('$version 下还没有可下载的文件。');
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

  return UpdateResolution.found(
    UpdateInfo(
      version: version,
      fileName: str(chosen['title']),
      downloadUrl: str(chosen['redirectUrl']),
      note: str(latest.card['subtitle']),
      checksumUrl: _firstLink(str(client['subtitle'])),
    ),
  );
}

/// 拉取下载区卡片并给出更新结论。
class UpdateService {
  UpdateService(this.api);

  final CommunityApi api;

  /// [currentVersion] 为 null 时不做比较，返回线上最新版本。
  Future<UpdateResolution> fetch({required List<int>? currentVersion}) async {
    final cards = jsonList((await api.get('/downloads/cards'))['cards']);
    return resolveUpdate(
      cards: cards,
      platformName: updatePlatformName(),
      currentVersion: currentVersion,
    );
  }
}
