import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import '../forum/topic_page.dart';
import '../downloads/resource_page.dart';
import 'admin_access.dart';
import 'admin_widgets.dart';

class ModerationPage extends StatelessWidget {
  const ModerationPage({super.key});
  @override
  Widget build(BuildContext context) => AdminPage(
    title: '内容审核',
    child: AdminCollection(
      path: '/admin/moderation',
      listKey: 'items',
      emptyTitle: '暂时没有审核事项',
      itemBuilder: (context, item, refresh) => AdminTile(
        title: str(item['reason'], '内容审核'),
        subtitle:
            '${adminStatus(item['target_type'])} · ${dateLabel(item['created_at'])}\n${str(item['target_id'])}',
        status: adminStatus(item['status']),
        icon: Icons.fact_check_outlined,
        onTap: () async {
          final changed = await openPage<bool>(
            context,
            ModerationDetailPage(item: item),
          );
          if (changed == true && context.mounted) await refresh();
        },
      ),
    ),
  );
}

class ModerationDetailPage extends ConsumerStatefulWidget {
  const ModerationDetailPage({super.key, required this.item});
  final Json item;
  @override
  ConsumerState<ModerationDetailPage> createState() =>
      _ModerationDetailPageState();
}

class _ModerationDetailPageState extends ConsumerState<ModerationDetailPage> {
  final note = TextEditingController();
  bool deciding = false, exiting = false;
  late final String identity;
  @override
  void initState() {
    super.initState();
    identity = AdminAccess(ref.read(sessionProvider).value).identity;
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> decide(String decision) async {
    if (deciding) return;
    final approved = decision == 'approve';
    setState(() => deciding = true);
    final api = ref.read(communityProvider);
    final done = await confirmAdminAction(
      context,
      title: approved ? '通过此审核？' : '驳回此审核？',
      message:
          '处理对象：${adminStatus(widget.item['target_type'])} · ${str(widget.item['target_id'])}\n决定和备注将提交并记录到审计日志。',
      confirmLabel: approved ? '确认通过' : '确认驳回',
      danger: !approved,
      onConfirm: () async {
        if (identity != AdminAccess(ref.read(sessionProvider).value).identity) {
          throw const RequestFailure('账号已变更，请重新进入');
        }
        await api.post(
          '/admin/moderation/${adminId(widget.item['id'])}/decide',
          {
            'decision': decision,
            if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
          },
        );
      },
    );
    if (!mounted) return;
    setState(() => deciding = false);
    if (done) {
      setState(() => exiting = true);
      notice(context, approved ? '审核已通过' : '审核已驳回');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  Future<void> confirmExit() async {
    if (deciding) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('放弃未提交的审核备注？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('放弃备注'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => exiting = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final detail = item['detail'];
    final target = str(item['target_id']);
    final type = str(item['target_type']);
    final canOpenTopic = type == 'topic';
    final canOpenResource = ['resource', 'download_resource'].contains(type);
    final pending = item['status'] == 'pending';
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: note,
      builder: (context, value, _) => PopScope(
        canPop: exiting || (!deciding && value.text.isEmpty),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) confirmExit();
        },
        child: AdminPage(
          title: '审核详情',
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SmallTag(adminStatus(type)),
                  SmallTag(adminStatus(item['status'])),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                str(item['reason'], '内容审核'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SelectableText('目标：$target\n提交时间：${str(item['created_at'])}'),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '审核内容',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (detail == null || detail == '')
                      const Text('此事项未附正文，请结合审核原因和目标信息核对。')
                    else
                      _ReviewContent(detail: detail),
                  ],
                ),
              ),
              if (canOpenTopic || canOpenResource)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => openPage(
                      context,
                      canOpenTopic
                          ? TopicPage(id: target)
                          : ResourcePage(id: target),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('查看对应内容'),
                  ),
                ),
              const SizedBox(height: 24),
              if (pending) ...[
                TextField(
                  controller: note,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 6,
                  enabled: !deciding,
                  decoration: const InputDecoration(
                    labelText: '处理备注（可选）',
                    hintText: '填写说明，便于后续追溯',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: deciding ? null : () => decide('approve'),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('通过'),
                    ),
                    OutlinedButton.icon(
                      onPressed: deciding ? null : () => decide('reject'),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('驳回'),
                    ),
                  ],
                ),
              ] else ...[
                Text('此事项已处理', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(str(item['decision_note'], '未填写处理备注')),
                if (item['decided_at'] != null)
                  Text('处理时间：${item['decided_at']}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewContent extends StatelessWidget {
  const _ReviewContent({required this.detail});
  final dynamic detail;
  @override
  Widget build(BuildContext context) {
    if (detail is String) return MarkdownContent(detail);
    if (detail is! Map) return SelectableText(prettyJson(detail));
    final values = Map<String, dynamic>.from(detail);
    final contentKey = ['content', 'content_md', 'contentMd', 'descriptionMd']
        .where(
          (key) => values[key] is String && (values[key] as String).isNotEmpty,
        )
        .firstOrNull;
    if (contentKey == null) return SelectableText(prettyJson(detail));
    final content = values.remove(contentKey) as String;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownContent(content),
        if (values.isNotEmpty) ...[
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('附加信息'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(prettyJson(values)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
