import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';

import '../../core/network/community_api.dart';
import '../admin/admin_access.dart';

bool canModerateTopics(Json? user) => AdminAccess(user).isStaff;
bool canDeleteTopic(Json? user, String? authorId) =>
    AdminAccess(user).isStaff || AdminAccess(user).owns(authorId);
bool canDeleteReply(Json? user, String? authorId) =>
    canDeleteTopic(user, authorId);
bool canEditReply(Json? user, String? authorId) =>
    AdminAccess(user).owns(authorId);
bool canWithdrawResource(Json? user, String? authorId) =>
    AdminAccess(user).canWithdraw(authorId);

String? contentAuthorId(Json value) {
  final raw = value['author_id'] ?? value['authorId'] ?? value['user_id'];
  return raw == null ? null : str(raw);
}

class ContentIdentity {
  const ContentIdentity._(this.identity);
  factory ContentIdentity.capture(Json? user) =>
      ContentIdentity._(AdminAccess(user).identity);
  final String identity;
  bool matches(Json? user) =>
      AdminAccess(user).usable && AdminAccess(user).identity == identity;
}

Future<bool> confirmContentAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async =>
    await appShowDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          AppTextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: destructive
                ? TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ==
    true;

Future<bool> editReplyDialog(
  BuildContext context,
  String initial, {
  required Future<void> Function(String) onSave,
}) async {
  return await appShowDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditReplyDialog(initial: initial, onSave: onSave),
      ) ??
      false;
}

class _EditReplyDialog extends StatefulWidget {
  const _EditReplyDialog({required this.initial, required this.onSave});
  final String initial;
  final Future<void> Function(String) onSave;

  @override
  State<_EditReplyDialog> createState() => _EditReplyDialogState();
}

class _EditReplyDialogState extends State<_EditReplyDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initial,
  );
  bool exiting = false, busy = false;
  Object? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> cancel() async {
    if (busy) return;
    if (controller.text == widget.initial) {
      Navigator.pop(context);
      return;
    }
    final discard = await confirmContentAction(
      context,
      title: '放弃修改？',
      message: '尚未保存的回复修改将会丢失。',
      confirmLabel: '放弃修改',
    );
    if (!discard || !mounted) return;
    setState(() => exiting = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> save() async {
    final value = controller.text.trim();
    if (busy || value.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave(value);
      if (!mounted) return;
      setState(() {
        busy = false;
        exiting = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: exiting || (!busy && controller.text == widget.initial),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) cancel();
    },
    child: AppAlertDialog(
      title: const Text('编辑回复'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: controller,
            enabled: !busy,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            maxLength: 100000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: '回复内容'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        AppTextButton(onPressed: busy ? null : cancel, child: const Text('取消')),
        AppFilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? '正在保存…' : '保存'),
        ),
      ],
    ),
  );
}
