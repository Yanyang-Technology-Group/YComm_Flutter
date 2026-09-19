import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/app_info.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/update/update_service.dart';

/// 与社区下载区线上结构一致的卡片树（社区客户端APP → 平台 → 版本 → 文件）。
List<Json> cards({
  String checksum =
      '各平台安装包见下方；校验文件：[SHA256SUMS.txt](https://dl.example/SHA256SUMS.txt)',
}) => [
  {
    'id': kClientCardId,
    'parentId': null,
    'title': '社区客户端APP',
    'kind': 'container',
    'subtitle': checksum,
  },
  {
    'id': 'win',
    'parentId': kClientCardId,
    'title': 'Windows',
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
  {
    'id': 'win-11',
    'parentId': 'win',
    'title': '2026.09.19.11',
    'kind': 'container',
    'subtitle': '旧版本',
  },
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
  {
    'id': 'linux',
    'parentId': kClientCardId,
    'title': 'Linux',
    'kind': 'container',
    'subtitle': '',
  },
  {
    'id': 'linux-12',
    'parentId': 'linux',
    'title': '2026.09.19.12',
    'kind': 'container',
    'subtitle': '',
  },
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
  // 版本卡片下一个可下载文件都没有
  {
    'id': 'macos',
    'parentId': kClientCardId,
    'title': 'macOS',
    'kind': 'container',
    'subtitle': '',
  },
  {
    'id': 'macos-12',
    'parentId': 'macos',
    'title': '2026.09.19.12',
    'kind': 'container',
    'subtitle': '',
  },
];

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
      // 跨月/跨年
      expect(compareVersions([2026, 10, 1, 1], [2026, 9, 30, 999]), greaterThan(0));
      expect(compareVersions([2027, 1, 1, 1], [2026, 12, 31, 5]), greaterThan(0));
      // 段数不同时按 0 补齐
      expect(compareVersions([2026, 9, 19], [2026, 9, 19, 0]), 0);
    });
  });

  group('resolveUpdate', () {
    test('picks the newest version card and prefers the installer', () {
      final info = resolveUpdate(
        cards: cards(),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(info, isNotNull);
      expect(info!.version, '2026.09.19.12');
      expect(info.fileName, 'ycomm-windows-2026.09.19.12-setup.exe');
      expect(info.downloadUrl, 'https://dl.example/setup.exe');
      expect(info.note, contains('安装版'));
      expect(info.checksumUrl, 'https://dl.example/SHA256SUMS.txt');
    });

    test('prefers .deb on Linux', () {
      final info = resolveUpdate(
        cards: cards(),
        platformName: 'Linux',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(info!.fileName, 'ycomm-linux-2026.09.19.12.deb');
    });

    test('returns null when already up to date', () {
      expect(
        resolveUpdate(
          cards: cards(),
          platformName: 'Windows',
          currentVersion: [2026, 9, 19, 12],
        ),
        isNull,
      );
    });

    test('returns null when the local build is newer', () {
      expect(
        resolveUpdate(
          cards: cards(),
          platformName: 'Windows',
          currentVersion: [2026, 9, 20, 1],
        ),
        isNull,
      );
    });

    test('without a current version it reports the latest without comparing', () {
      final info = resolveUpdate(
        cards: cards(),
        platformName: 'Windows',
        currentVersion: null,
      );
      expect(info!.version, '2026.09.19.12');
    });

    test('returns null for unsupported platforms', () {
      expect(
        resolveUpdate(
          cards: cards(),
          platformName: null,
          currentVersion: [2026, 9, 19, 11],
        ),
        isNull,
      );
    });

    test('returns null when the platform card is missing', () {
      expect(
        resolveUpdate(
          cards: cards(),
          platformName: 'iOS',
          currentVersion: [2026, 9, 19, 11],
        ),
        isNull,
      );
    });

    test('returns null when the version card has no downloadable file', () {
      expect(
        resolveUpdate(
          cards: cards(),
          platformName: 'macOS',
          currentVersion: [2026, 9, 19, 11],
        ),
        isNull,
      );
    });

    test('without a checksum link the field stays null', () {
      final info = resolveUpdate(
        cards: cards(checksum: '各平台安装包见下方'),
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(info!.checksumUrl, isNull);
    });

    test('ignores redirect cards whose url is empty', () {
      final broken = cards()..add({
        'id': 'win-empty',
        'parentId': 'win-12',
        'title': 'ycomm-windows-2026.09.19.12-空链接.exe',
        'kind': 'redirect',
        'redirectUrl': '',
      });
      final info = resolveUpdate(
        cards: broken,
        platformName: 'Windows',
        currentVersion: [2026, 9, 19, 11],
      );
      expect(info!.downloadUrl, 'https://dl.example/setup.exe');
    });
  });
}
