import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

const _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

class InstallerDownloadFailure implements Exception {
  const InstallerDownloadFailure(this.stage, this.cause, this.stackTrace);

  final String stage;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => '$stage失败（${cause.runtimeType}）：$cause';

  String get details => '$this\n\n$stackTrace';
}

/// 每次下载使用独立目录，不覆盖可能正被安装器锁定的旧文件。
/// 独立 Dio 不携带社区登录信息。失败和取消时清理本次未完成文件。
Future<File> downloadInstaller({
  required String url,
  required String fileName,
  required CancelToken cancelToken,
  required void Function(double? progress) onProgress,
  Dio? client,
  Future<Directory> Function()? documentsDirectory,
}) async {
  final dio = client ?? Dio();
  void checkCancelled() {
    final error = cancelToken.cancelError;
    if (error != null) throw error;
  }
  Directory? attempt;
  var stage = '获取下载目录';
  try {
    final directory = await (documentsDirectory ?? getApplicationDocumentsDirectory)();
    checkCancelled();
    stage = '创建下载文件';
    final downloads = await Directory('${directory.path}/YComm-Updates').create(recursive: true);
    attempt = await downloads.createTemp('download-');
    var name = fileName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceFirst(RegExp(r'[. ]+$'), '');
    if (name.isEmpty || RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)', caseSensitive: false).hasMatch(name)) {
      name = 'installer-$name';
    }
    final file = File('${attempt.path}/$name');
    stage = '连接下载服务器';
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: const {
          'User-Agent': _browserUserAgent,
          'Accept': '*/*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 2),
      ),
      cancelToken: cancelToken,
    );
    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
      await response.data?.stream.drain<void>();
      throw HttpException('HTTP ${response.statusCode}');
    }
    final body = response.data;
    if (body == null) throw const HttpException('下载响应为空');
    final length = int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
    var received = 0;
    stage = '保存安装包';
    final sink = file.openWrite();
    try {
      await sink.addStream(body.stream.map((chunk) {
        checkCancelled();
        received += chunk.length;
        onProgress(length > 0 ? (received / length).clamp(0, 1) : null);
        return chunk;
      }));
      await sink.flush();
    } finally {
      await sink.close();
    }
    checkCancelled();
    if (received == 0) throw const HttpException('安装包为空');
    return file;
  } catch (error, stack) {
    if (attempt != null) {
      try {
        await attempt.delete(recursive: true);
      } catch (_) {
        // 保留原始错误；清理失败不应覆盖下载或文件系统诊断。
      }
    }
    if (error is DioException && CancelToken.isCancel(error)) rethrow;
    throw InstallerDownloadFailure(stage, error, stack);
  } finally {
    if (client == null) dio.close(force: true);
  }
}
