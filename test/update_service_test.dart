import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/app_info.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/update/update_service.dart';

/// 与社区下载区线上结构一致的卡片树（社区客户端APP → 平台 → 版本 → 文件）。
///
/// 默认用「一个新的根卡片 ID」——线上站长重建过卡片，ID 每次都会变，
/// 固定 ID 只在没重建时命中，所以用例必须覆盖这种情况。
List<Json> cards({
  String rootId = 'ac8760f3-068e-4f4a-bc65-787b296cae70',
  String rootTitle = kClientCardTitle,
  String platformTitle = 'Windows',
  bool withClientCard = true,
  bool withPlatformCard = true,
  bool withFiles = true,
  String checksum =
      '各平台安装包见下方；校验文件：[SHA256SUMS.txt](https://dl.example/SHA256SUMS.txt)',
}) => [
  if (withClientCard)
    {
      'id': rootId,
      'parentId': null,
      'title': rootTitle,
      'kind': 'container',
      'subtitle': checksum,
    },
  // 与本客户端无关的另一个根卡片，用来验证不会认错
  {'id': 'jdk', 'parentId': null, 'title': 'Java 25', 'kind': 'container', 'subtitle': ''},
  {'id': 'jdk-win', 'parentId': 'jdk', 'title': 'Windows', 'kind': 'container'},
  {
    'id': 'jdk-win-msi',
    'parentId': 'jdk-win',
    'title': 'zulu25-win_x64.msi',
    'kind': 'redirect',
    'redirectUrl': 'https://cdn.example/zulu.msi',
  },
  if (withPlatformCard)
    {
      'id': 'win',
      'parentId': rootId,
      'title': platformTitle,
      'kind': 'container',
      'subtitle': '',
    },
  {
    'id': 'win-12',
    'parentId': 'win',
    'title': '2026.09.19.12',
    'kind': 'container',
    'subtitle': '2026.09.19.12 · 安装版 / 免安装版',
  },
  // 旧版本卡片：必须被忽略，不能因为排在前面就选中
  {'id': 'win-11', 'parentId': 'win', 'title': '2026.09.19.11', 'kind': 'container', 'subtitle': '旧版本'},
  if (withFiles)
    {
      'id': 'win-setup',
      'parentId': 'win-12',
      'title': 'ycomm-windows-2026.09.19.12-setup.exe',
      'kind': 'redirect',
      'redirectUrl': 'https://dl.example/setup.exe',
    },
  {
    'id': 'win-zip',
    'parentId': 'win-12',
    'title': 'ycomm-windows-2026.09.19.12.zip',
    'kind': 'redirect',
    'redirectUrl': 'https://dl.example/portable.zip',
  },
  {
    'id': 'win-old-file',
    'parentId': 'win-11',
    'title': 'ycomm-windows-2026.09.19.11.zip',
    'kind': 'redirect',
    'redirectUrl': 'https://dl.example/old.zip',
  },
  {'id': 'linux', 'parentId': rootId, 'title': 'Linux', 'kind': 'container', 'subtitle': ''},
  {'id': 'linux-12', 'parentId': 'linux', 'title': '2026.09.19.12', 'kind': 'container', 'subtitle': ''},
  {
    'id': 'linux-deb',
    'parentId': 'linux-12',
    'title': 'ycomm-linux-2026.09.19.12.deb',
    'kind': 'redirect',
    'redirectUrl': 'https://dl.example/app.deb',
  },
  {
    'id': 'linux-tar',
    'parentId': 'linux-12',
    'title': 'ycomm-linux-2026.09.19.12.tar.gz',
    'kind': 'redirect',
    'redirectUrl': 'https://dl.example/app.tar.gz',
  },
];

UpdateInfo? infoOf(UpdateResolution r) => r.info;

void main() {
  group('parseVersionParts', () {
    test('accepts yyyy.mm.dd.commits', () {
      expect(parseVersionParts('2026.09.19.12'), [2026, 9, 19, 12]);
      expect(parseVersionParts(' 2026.9.5.1 '), [2026, 9, 5, 1]);
    });

    test('rejects anything else', () {
      expect(parseVersionParts('2026.09.19'), isNull);
      expect(parseVersionParts('v2026.09.19.12'), isNull);
      expect(parseVersionParts('开发版'), isNull);
      expect(parseVersionParts(''), isNull);
    });
  });

  group('compareVersions', () {
    test('orders by each segment', () {
      expect(compareVersions([2026, 9, 19, 12], [2026, 9, 19, 11]), greaterThan(0));
      expect(compareVersions([2026, 9, 19, 11], [2026, 9, 19, 12]), lessThan(0));
      expect(compareVersions([2026, 9, 19, 12], [2026, 9, 19, 12]), 0);
      expect(compareVersions([2026, 10, 1, 1], [2026, 9, 30, 999]), greaterThan(0));
      expect(compareVersions([2027, 1, 1, 1], [2026, 12, 31, 5]), greaterThan(0));
      expect(compareVersions([2026, 9, 19], [2026, 9, 19, 0]), 0);
    });
  });

  group('resolveUpdate 正常路径', () {
    test('取最大的版本卡片，安装版优先', () {
      final r = resolveUpdate(
        cards: cards(),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.found);
      final info = infoOf(r)!;
      expect(info.version, '2026.09.19.12');
      expect(info.fileName, 'ycomm-windows-2026.09.19.12-setup.exe');
      expect(info.downloadUrl, 'https://dl.example/setup.exe');
      expect(info.note, contains('安装版'));
      expect(info.checksumUrl, 'https://dl.example/SHA256SUMS.txt');
    });

    test('Linux 优先 .deb', () {
      // 用夹具里真正的 Linux 卡片（platformTitle 只改 Windows 那张的名字）
      final r = resolveUpdate(
        cards: cards(),
        platformName: 'Linux',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.found);
      expect(infoOf(r)!.fileName, 'ycomm-linux-2026.09.19.12.deb');
      expect(infoOf(r)!.downloadUrl, 'https://dl.example/app.deb');
    });

    test('已是最新', () {
      final r = resolveUpdate(
        cards: cards(),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 12],
      );
      expect(r.status, UpdateStatus.upToDate);
    });

    test('本机版本更新', () {
      final r = resolveUpdate(
        cards: cards(),
        platformName: 'Windows',
        currentVersion: [2026, 9, 20, 1],
      );
      expect(r.status, UpdateStatus.upToDate);
    });

    test('currentVersion 为 null 时不做比较，给出线上最新', () {
      final r = resolveUpdate(
        cards: cards(),
        platformName: 'Windows',
        currentVersion: null,
      );
      expect(r.status, UpdateStatus.found);
      expect(infoOf(r)!.version, '2026.09.19.12');
    });

    test('平台名带后缀也能匹配（Windows x64）', () {
      final r = resolveUpdate(
        cards: cards(platformTitle: 'Windows x64'),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.found);
    });

    test('不会把别的根卡片（Java 25）认成客户端', () {
      final r = resolveUpdate(
        cards: cards(withPlatformCard: false),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      // Java 卡片里也有 Windows，但文件名前缀不是 ycomm-，不该被当成客户端
      expect(r.status, UpdateStatus.unavailable);
    });
  });

  group('resolveUpdate 认卡片的方式（回归：站长重建卡片后 ID 会变）', () {
    test('固定 ID 变了、标题还在 —— 按标题找到', () {
      final r = resolveUpdate(
        cards: cards(rootId: 'brand-new-uuid'),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.found);
      expect(infoOf(r)!.version, '2026.09.19.12');
    });

    test('ID 和标题都变了 —— 按 ycomm- 文件结构找到', () {
      final r = resolveUpdate(
        cards: cards(rootId: 'brand-new-uuid', rootTitle: '客户端下载'),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.found);
    });

    test('老的固定 ID 仍然命中（快速路径）', () {
      final r = resolveUpdate(
        cards: cards(rootId: kLegacyClientCardId),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.found);
    });
  });

  group('resolveUpdate 拿不到信息时必须如实说明，不能报「已是最新」', () {
    test('客户端卡片整个不见了', () {
      final r = resolveUpdate(
        cards: cards(withClientCard: false),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.unavailable);
      expect(r.status, isNot(UpdateStatus.upToDate));
      expect(r.message, contains('社区客户端APP'));
    });

    test('平台分类不见了（例如 macOS 还没建）', () {
      final r = resolveUpdate(
        cards: cards(),
        platformName: 'iOS',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.unavailable);
      expect(r.message, contains('iOS'));
    });

    test('平台卡片存在但没有版本卡片', () {
      final broken = cards()..removeWhere((c) => c['id'] == 'win-12' || c['id'] == 'win-11');
      final r = resolveUpdate(
        cards: broken,
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.unavailable);
    });

    test('版本卡片下一个可下载文件都没有', () {
      final r = resolveUpdate(
        cards: cards(withFiles: false)..removeWhere((c) => c['id'] == 'win-zip'),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.unavailable);
    });

    test('平台为 null（Web）', () {
      final r = resolveUpdate(
        cards: cards(),
        platformName: null,
        currentVersion: [2026, 9, 19, 11],
      );
      expect(r.status, UpdateStatus.unavailable);
    });
  });

  group('其它', () {
    test('没有校验链接时 checksumUrl 为 null', () {
      final r = resolveUpdate(
        cards: cards(checksum: '各平台安装包见下方'),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(infoOf(r)!.checksumUrl, isNull);
    });

    test('忽略 redirectUrl 为空的文件卡片', () {
      final broken = cards()..add({
        'id': 'win-empty',
        'parentId': 'win-12',
        'title': 'ycomm-windows-2026.09.19.12-空链接.exe',
        'kind': 'redirect',
        'redirectUrl': '',
      });
      final r = resolveUpdate(
        cards: broken,
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(infoOf(r)!.downloadUrl, 'https://dl.example/setup.exe');
    });
  });
}
