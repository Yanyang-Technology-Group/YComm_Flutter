import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/update/installer_download.dart';

class InstallerAdapter implements HttpClientAdapter {
  int downloads = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelled,
  ) async {
    if (options.method == 'HEAD') return ResponseBody.fromString('', 200);
    downloads++;
    return ResponseBody.fromString(
      'installer-binary',
      200,
      headers: {
        'content-length': ['16'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a completed installer is reused without HTTP, and redownload stays available', () async {
    final directory = await Directory.systemTemp.createTemp('ycomm-cache-test');
    addTearDown(() => directory.delete(recursive: true));
    final adapter = InstallerAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    Future<File> download({bool force = false}) => downloadInstaller(
      url: 'https://example.test/client.exe',
      fileName: 'client.exe',
      version: '2026.10.7.1',
      cancelToken: CancelToken(),
      onProgress: (_) {},
      client: dio,
      documentsDirectory: () async => directory,
      forceDownload: force,
    );
    final first = await download();
    expect((await download()).path, first.path);
    expect(adapter.downloads, 1);
    expect((await download(force: true)).path, isNot(first.path));
    expect(adapter.downloads, 2);
  });

  test(
    'truncated, altered and other-version installers are never reused',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ycomm-cache-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final dio = Dio()..httpClientAdapter = InstallerAdapter();
      addTearDown(() => dio.close(force: true));
      final file = await downloadInstaller(
        url: 'https://example.test/client.exe',
        fileName: 'client.exe',
        version: '1',
        cancelToken: CancelToken(),
        onProgress: (_) {},
        client: dio,
        documentsDirectory: () async => directory,
      );
      Future<File?> cache(String version) => cachedInstaller(
        url: 'https://example.test/client.exe',
        fileName: 'client.exe',
        version: version,
        documentsDirectory: () async => directory,
      );
      expect(await cache('2'), isNull);
      await file.writeAsString('altered-content!');
      expect(await cache('1'), isNull);
      await file.writeAsString('partial');
      expect(await cache('1'), isNull);
    },
  );
}
