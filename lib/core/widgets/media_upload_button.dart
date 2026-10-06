import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/adaptive.dart';
import '../network/community_api.dart';

const mediaExtensions = [
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
  'mp4',
  'webm',
  'mov',
];
const maxMediaBytes = 50 * 1024 * 1024;

final mediaPickerProvider = Provider<Future<PlatformFile?> Function()>(
  (ref) =>
      () => FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: mediaExtensions,
      ),
);

/// Replace the selection, or append when the editor has no active selection.
void insertUploadedMedia(TextEditingController controller, String url) {
  final value = controller.value;
  final selection = value.selection;
  final start = selection.isValid ? selection.start : value.text.length;
  final end = selection.isValid ? selection.end : value.text.length;
  final markdown = '\n![]($url)\n';
  controller.value = TextEditingValue(
    text: value.text.replaceRange(start, end, markdown),
    selection: TextSelection.collapsed(offset: start + markdown.length),
  );
}

class MediaUploadButton extends ConsumerStatefulWidget {
  const MediaUploadButton({
    super.key,
    required this.controller,
    required this.onBusyChanged,
    this.enabled = true,
    this.compact = false,
  });
  final TextEditingController controller;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled, compact;

  @override
  ConsumerState<MediaUploadButton> createState() => _MediaUploadButtonState();
}

class _MediaUploadButtonState extends ConsumerState<MediaUploadButton> {
  bool uploading = false;
  double? progress;
  String? error;

  Future<void> pickAndUpload() async {
    if (uploading || !widget.enabled) return;
    setState(() {
      uploading = true;
      progress = null;
      error = null;
    });
    widget.onBusyChanged(true);
    try {
      final selected = await ref.read(mediaPickerProvider)();
      if (!mounted || selected == null) return;
      final size = await selected.length();
      if (!mounted) return;
      if (size == null || size == 0 || size > maxMediaBytes) {
        throw const RequestFailure('请选择非空且不超过 50MB 的图片或视频');
      }
      final extension = selected.name.split('.').last.toLowerCase();
      if (!mediaExtensions.contains(extension)) {
        throw const RequestFailure('支持 PNG/JPEG/WebP/GIF 和 MP4/WebM/MOV');
      }
      final file = MultipartFile.fromStream(
        selected.readAsByteStream,
        size,
        filename: selected.name,
      );
      final uploaded = await ref
          .read(communityProvider)
          .uploadMedia(
            file,
            video: ['mp4', 'webm', 'mov'].contains(extension),
            onSendProgress: (sent, total) {
              if (mounted) {
                setState(() => progress = total > 0 ? sent / total : null);
              }
            },
          );
      if (!mounted) return;
      final url = str(uploaded['url']);
      if (!RegExp(
        r'^/api/uploads/(images|videos)/[A-Za-z0-9_-]+\.(png|jpe?g|webp|gif|mp4|webm|mov)$',
      ).hasMatch(url)) {
        throw const RequestFailure('上传返回的地址无效，请重试');
      }
      insertUploadedMedia(widget.controller, url);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() => uploading = false);
        widget.onBusyChanged(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = uploading
        ? progress == null
              ? '选择文件…'
              : progress! >= 1
              ? '正在保存…'
              : '上传 ${(progress! * 100).round()}%'
        : '上传图片或视频';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.compact)
          AppIconButton(
            tooltip: label,
            onPressed: uploading || !widget.enabled ? null : pickAndUpload,
            icon: uploading
                ? const SizedBox(width: 20, height: 20, child: AppSpinner())
                : const AppIcon(Icons.attach_file_rounded),
          )
        else
          AppTextButton(
            onPressed: uploading || !widget.enabled ? null : pickAndUpload,
            child: Text(label),
          ),
        if (uploading && widget.compact && progress != null)
          Text(
            '${(progress! * 100).round()}%',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        if (error != null)
          SizedBox(
            width: widget.compact ? 100 : null,
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
