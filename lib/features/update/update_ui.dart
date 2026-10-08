import '../../core/design/adaptive.dart';

// 更新相关的界面：手动检查结果、自动提示、下载并交给系统安装器。
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/app_info.dart';
import '../../core/update/update_controller.dart';
import '../../core/update/update_service.dart';
import '../../core/update/installer_download.dart';
import '../../core/widgets/design.dart';
import '../../core/window/desktop_shell.dart';

/// 「关于」页的手动检查更新。
Future<void> checkForUpdates(BuildContext context, WidgetRef ref) async {
  final state = await ref.read(updateControllerProvider.notifier).check();
  if (!context.mounted) {
    return;
  }
  await _showResult(context, ref, state);
}

/// 自动检查：只有发现新版本、且用户没点过「不再提醒」才弹窗。
///
/// [onLaunch] 为 true 表示「这次是应用启动」，每次启动都真的请求一遍；
/// 回到前台则走节流版本，避免每切一次窗口就打一次接口。
Future<void> autoCheckForUpdates(
  BuildContext context,
  WidgetRef ref, {
  bool onLaunch = false,
}) async {
  final controller = ref.read(updateControllerProvider.notifier);
  final state = onLaunch
      ? await controller.checkOnLaunch()
      : await controller.autoCheck();
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
  final cached = await cachedInstaller(
    url: info.downloadUrl,
    fileName: info.fileName,
    version: info.version,
  );
  if (!context.mounted) return;
  final action = await appShowDialog<String>(
    context: context,
    builder: (dialogContext) => AppAlertDialog(
      title: Text(manual ? '发现新版本' : '有新版本可用'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('线上版本：${info.version}'),
          if (cached != null) const Text('安装包已下载，可直接安装。'),
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
          child: Text(cached == null ? '下载安装' : '直接安装'),
        ),
        if (cached != null)
          AppTextButton(
            onPressed: () => Navigator.of(dialogContext).pop('redownload'),
            child: const Text('重新下载'),
          ),
      ],
    ),
  );
  if ((action == 'download' || action == 'redownload') && context.mounted) {
    await _download(context, ref, info, forceDownload: action == 'redownload');
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
  UpdateInfo info, {
  bool forceDownload = false,
}) async {
  final result = await appShowDialog<_DownloadResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(info: info, forceDownload: forceDownload),
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
  // 优先静默安装：不弹安装向导。
  if (_supportsSilentInstall(result.path!)) {
    // 成功启动安装器后主动退出，释放文件并绕开关闭到托盘的拦截。
    if (context.mounted && await _runInstallerSilently(result.path!)) {
      await showRestartNotice();
      await exitForUpdate();
      return;
    }
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

/// 这个安装包能不能静默安装。
///
/// 只有 Windows 的 Inno Setup 包（.exe）和 MSI 支持无人值守；
/// .deb 要 sudo、.apk 走系统安装器、.dmg 要用户拖进「应用程序」，
/// 这些都没法静默，只能交给系统。
bool _supportsSilentInstall(String path) {
  if (!Platform.isWindows) {
    return false;
  }
  final lower = path.toLowerCase();
  return lower.endsWith('.exe') || lower.endsWith('.msi');
}

/// 无安装向导地运行安装包。
///
/// Inno Setup 显示安装进度，并在安装完成后启动新版本。
///   /SUPPRESSMSGBOXES   连错误提示框也不弹
///   /NORESTART          不自动重启系统
///   /CLOSEAPPLICATIONS  需要替换文件时把本应用关掉
/// 安装包是「按用户安装」（PrivilegesRequired=lowest），所以不会弹 UAC。
Future<bool> _runInstallerSilently(String path) async {
  try {
    if (path.toLowerCase().endsWith('.msi')) {
      await Process.start('msiexec', [
        '/i',
        path,
        '/qn',
        '/norestart',
      ], mode: ProcessStartMode.detached);
    } else {
      await Process.start(path, const [
        '/SILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
      ], mode: ProcessStartMode.detached);
    }
    return true;
  } catch (error) {
    debugPrint('静默安装启动失败：$error');
    return false;
  }
}

/// 下载结果。必须区分「用户取消」「下载失败」「已保存」三种，
/// 否则取消也会被当成失败去跳浏览器。
class _DownloadResult {
  const _DownloadResult.saved(this.path) : cancelled = false, error = null;
  const _DownloadResult.cancelled()
    : path = null,
      cancelled = true,
      error = null;
  const _DownloadResult.failed(this.error) : path = null, cancelled = false;

  final String? path;
  final bool cancelled;
  final String? error;
}

/// 下载进度的模态框。
class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.info, this.forceDownload = false});
  final UpdateInfo info;
  final bool forceDownload;
  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  final cancel = CancelToken();
  double? progress;
  String? failure;
  String? failureDetails;

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
      final file = await downloadInstaller(
        url: widget.info.downloadUrl,
        fileName: widget.info.fileName,
        version: widget.info.version,
        forceDownload: widget.forceDownload,
        cancelToken: cancel,
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
      );
      if (mounted) {
        Navigator.of(context).pop(_DownloadResult.saved(file.path));
      }
    } catch (error, stack) {
      if (!mounted) return;
      final cancelled = error is DioException && CancelToken.isCancel(error);
      if (!cancelled) {
        debugPrint('安装包下载失败：$error');
        debugPrintStack(
          stackTrace: error is InstallerDownloadFailure
              ? error.stackTrace
              : stack,
        );
      }
      setState(() {
        failure = cancelled ? '下载已取消' : '$error';
        failureDetails = cancelled
            ? null
            : error is InstallerDownloadFailure
            ? error.details
            : '${error.runtimeType}: $error\n\n$stack';
      });
    }
  }

  void _close() => Navigator.of(context).pop(
    failure == '下载已取消'
        ? const _DownloadResult.cancelled()
        : _DownloadResult.failed(failure),
  );

  @override
  Widget build(BuildContext context) => AppAlertDialog(
    title: Text('正在下载 ${widget.info.version}'),
    scrollable: true,
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
        if (failureDetails != null)
          AppTextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: failureDetails!));
              if (context.mounted) notice(context, '错误详情已复制');
            },
            child: const Text('复制错误详情'),
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
            Navigator.of(context).pop(const _DownloadResult.cancelled());
          },
          child: const Text('取消'),
        )
      else
        AppFilledButton(onPressed: _close, child: const Text('关闭')),
    ],
  );
}
