import '../../core/design/adaptive.dart';

// 更新相关的界面：手动检查结果、自动提示、下载并交给系统安装器。
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_info.dart';
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
        secondary: info == null ? null : () => _download(context, ref, info),
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
  final action = await appShowDialog<String>(
    context: context,
    builder: (dialogContext) => AppAlertDialog(
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
          AppTextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              externalLink(dialogContext, info.checksumUrl!);
            },
            child: const Text('校验文件'),
          ),
        AppTextButton(
          onPressed: () async {
            await controller.dismiss(info.version);
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
          child: const Text('不再提醒'),
        ),
        AppTextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('稍后'),
        ),
        AppFilledButton(
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
}) => appShowDialog<void>(
  context: context,
  builder: (dialogContext) => AppAlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      if (secondary != null && secondaryLabel != null)
        AppTextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            secondary();
          },
          child: Text(secondaryLabel),
        ),
      AppFilledButton(
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
  final path = await appShowDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(info: info),
  );
  if (!context.mounted) {
    return;
  }
  if (path == null) {
    // 下载失败时 _DownloadDialog 已经关掉自己，这里给浏览器兜底。
    await externalLink(context, info.downloadUrl);
    return;
  }
  final result = await OpenFilex.open(path);
  if (result.type != ResultType.done && context.mounted) {
    notice(context, '没有找到能打开该安装包的应用，已改为浏览器下载');
    await externalLink(context, info.downloadUrl);
  }
}

/// 下载进度的模态框；成功时 pop 出保存路径，失败时 pop 出 null。
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
      // 用独立的 Dio：这是第三方镜像地址，不该带上社区站的 Cookie。
      final response = await Dio().get<ResponseBody>(
        widget.info.downloadUrl,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
        ),
        cancelToken: cancel,
      );
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
        Navigator.of(context).pop(file.path);
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

  @override
  Widget build(BuildContext context) => AppAlertDialog(
    title: Text('正在下载 ${widget.info.version}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.info.fileName,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (failure == null)
          AppProgress(value: progress)
        else
          Text(
            failure!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
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
        AppTextButton(
          onPressed: () {
            cancel.cancel();
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        )
      else
        AppFilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
    ],
  );
}
