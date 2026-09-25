// 更新相关的界面：手动检查结果、自动提示、下载并交给系统安装器。
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_info.dart';
import '../../core/network/community_api.dart';
import '../../core/update/update_controller.dart';
import '../../core/update/update_service.dart';
import '../../core/widgets/design.dart';

/// 「关于」页的手动检查更新。
Future<void> checkForUpdates(BuildContext context, WidgetRef ref) async {
  final state = await ref.read(updateControllerProvider.notifier).check();
  if (!context.mounted) {
    return;
  }
  await _showResult(context, ref, state);
}

/// 启动与回到前台时的自动检查：只有发现新版本、且用户没点过「不再提醒」才弹窗。
Future<void> autoCheckForUpdates(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(updateControllerProvider.notifier);
  final state = await controller.autoCheck();
  final info = state?.info;
  if (state?.status != UpdateStatus.found || info == null) {
    return;
  }
  if (await controller.isDismissed(info.version) || !context.mounted) {
    return;
  }
  await _showFound(context, ref, info);
}

Future<void> _showResult(
  BuildContext context,
  WidgetRef ref,
  UpdateState state,
) async {
  switch (state.status) {
    case UpdateStatus.found:
      final info = state.info;
      if (info != null) {
        await _showFound(context, ref, info, manual: true);
      }
    case UpdateStatus.upToDate:
      await _simple(
        context,
        title: '已是最新版本',
        message: '当前版本 $appVersionLabel。',
      );
    case UpdateStatus.unavailable:
      final info = state.info;
      await _simple(
        context,
        title: '无法自动检查',
        message: state.message ?? '暂时拿不到更新信息，请到社区下载区查看。',
        secondary: info == null
            ? null
            : () => _download(context, ref, info),
        secondaryLabel: info == null ? null : '仍要下载 ${info.version}',
      );
    case UpdateStatus.failed:
      await _simple(
        context,
        title: '检查更新失败',
        message: state.message ?? '网络异常，请稍后重试。',
        secondary: () => checkForUpdates(context, ref),
        secondaryLabel: '重试',
      );
    case null:
      break;
  }
}

Future<void> _showFound(
  BuildContext context,
  WidgetRef ref,
  UpdateInfo info, {
  bool manual = false,
}) async {
  final controller = ref.read(updateControllerProvider.notifier);
  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(manual ? '发现新版本' : '有新版本可用'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('线上版本：${info.version}'),
          const SizedBox(height: 6),
          Text(
            '当前版本：$appVersionLabel',
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
          if (info.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(info.note),
          ],
          const SizedBox(height: 12),
          Text(
            info.fileName,
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        if (info.checksumUrl != null)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              externalLink(dialogContext, info.checksumUrl!);
            },
            child: const Text('校验文件'),
          ),
        TextButton(
          onPressed: () async {
            await controller.dismiss(info.version);
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
          child: const Text('不再提醒'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop('download'),
          child: const Text('下载安装'),
        ),
      ],
    ),
  );
  if (action == 'download' && context.mounted) {
    await _download(context, ref, info);
  }
}

Future<void> _simple(
  BuildContext context, {
  required String title,
  required String message,
  VoidCallback? secondary,
  String? secondaryLabel,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      if (secondary != null && secondaryLabel != null)
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            secondary();
          },
          child: Text(secondaryLabel),
        ),
      FilledButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('好'),
      ),
    ],
  ),
);

/// 下载安装包，然后交给系统安装器打开；打不开就退回浏览器下载。
Future<void> _download(
  BuildContext context,
  WidgetRef ref,
  UpdateInfo info,
) async {
  final result = await showDialog<_DownloadResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(info: info),
  );
  if (!context.mounted || result == null || result.cancelled) {
    // 用户主动取消（或直接关掉对话框）时什么都不做 ——
    // 以前这里会当成失败去跳浏览器，很难理解。
    return;
  }
  if (result.path == null) {
    // 下载失败：把真正的错误告诉用户，是否改用浏览器由他决定，不自动跳。
    await _simple(
      context,
      title: '应用内下载失败',
      message: result.error ?? '请稍后重试。',
      secondary: () => externalLink(context, info.downloadUrl),
      secondaryLabel: '用浏览器下载',
    );
    return;
  }
  final opened = await OpenFilex.open(result.path!);
  if (opened.type == ResultType.done || !context.mounted) {
    return;
  }
  // 下载成功但系统里没有能打开它的应用：告诉用户文件在哪，别偷偷跳浏览器。
  await _simple(
    context,
    title: '已下载完成',
    message: '系统里没有能打开 ${info.fileName} 的应用。\n文件已保存到：\n${result.path}',
    secondary: () => externalLink(context, info.downloadUrl),
    secondaryLabel: '用浏览器下载',
  );
}

/// 浏览器 User-Agent：镜像站按它放行非浏览器请求。
const String _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

/// 下载结果。必须区分「用户取消」「下载失败」「已保存」三种，
/// 否则取消也会被当成失败去跳浏览器。
class _DownloadResult {
  const _DownloadResult.saved(this.path)
    : cancelled = false,
      error = null;
  const _DownloadResult.cancelled()
    : path = null,
      cancelled = true,
      error = null;
  const _DownloadResult.failed(this.error)
    : path = null,
      cancelled = false;

  final String? path;
  final bool cancelled;
  final String? error;
}

/// 下载进度的模态框。
class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.info});
  final UpdateInfo info;
  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  final cancel = CancelToken();
  double? progress;
  String? failure;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    cancel.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final name = widget.info.fileName.replaceAll(
        RegExp(r'[/\\\x00-\x1f]'),
        '_',
      );
      final file = File('${directory.path}/$name');
      // 用独立的 Dio：这是第三方镜像地址（ghproxy），不该带上社区站的 Cookie。
      //
      // 必须伪装成浏览器：ghproxy 会按 User-Agent 拦非浏览器请求，Dio 默认的
      // "Dio/5.x" 会被拒。那正是「应用内下载总失败、只能退到浏览器」的原因。
      final response = await Dio().get<ResponseBody>(
        widget.info.downloadUrl,
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
        cancelToken: cancel,
      );
      // 非 2xx 要显式报出来，否则会把错误页当成安装包存下来。
      if (response.statusCode != null &&
          (response.statusCode! < 200 || response.statusCode! >= 300)) {
        throw RequestFailure('下载失败（HTTP ${response.statusCode}）');
      }
      final length =
          int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
      var received = 0;
      final sink = file.openWrite();
      try {
        await sink.addStream(
          response.data!.stream.map((chunk) {
            received += chunk.length;
            if (mounted && length > 0) {
              setState(() => progress = received / length);
            }
            return chunk;
          }),
        );
      } finally {
        await sink.close();
      }
      if (mounted) {
        Navigator.of(context).pop(_DownloadResult.saved(file.path));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        failure = error is DioException && CancelToken.isCancel(error)
            ? '下载已取消'
            : '$error';
      });
    }
  }

  void _close() => Navigator.of(
    context,
  ).pop(failure == '下载已取消'
      ? const _DownloadResult.cancelled()
      : _DownloadResult.failed(failure));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('正在下载 ${widget.info.version}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.info.fileName, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        if (failure == null)
          LinearProgressIndicator(value: progress)
        else
          Text(failure!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        Text(
          failure == null
              ? (progress == null
                    ? '正在连接…'
                    : '${(progress! * 100).toStringAsFixed(0)}%')
              : '',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
    actions: [
      if (failure == null)
        TextButton(
          onPressed: () {
            cancel.cancel();
            Navigator.of(context).pop(const _DownloadResult.cancelled());
          },
          child: const Text('取消'),
        )
      else
        FilledButton(onPressed: _close, child: const Text('关闭')),
    ],
  );
}
