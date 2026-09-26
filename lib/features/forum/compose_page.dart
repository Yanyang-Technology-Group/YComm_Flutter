import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/widgets/design.dart';
import '../../core/design/apple_chrome.dart';

class ComposePage extends ConsumerStatefulWidget {
  const ComposePage({
    super.key,
    this.boards = const [],
    this.initialSlug,
    this.topicId,
    this.replyTo,
    this.replyName,
    this.initialContent = '',
    this.onContentChanged,
  });
  final String initialContent;
  final ValueChanged<String>? onContentChanged;
  final List<Json> boards;
  final String? initialSlug, topicId, replyTo, replyName;
  @override
  ConsumerState<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends ConsumerState<ComposePage> {
  final title = TextEditingController(), content = TextEditingController();
  final form = GlobalKey<FormState>();
  String? slug, error;
  bool busy = false, preview = false, allowExit = false;
  bool get reply => widget.topicId != null;
  @override
  void initState() {
    super.initState();
    slug = widget.boards.any((b) => b['slug'] == widget.initialSlug)
        ? widget.initialSlug
        : widget.boards.firstOrNull?['slug'];
    content.text = widget.initialContent;
    title.addListener(changed);
    content.addListener(changed);
  }

  void changed() {
    widget.onContentChanged?.call(content.text);
    setState(() {});
  }

  @override
  void dispose() {
    title.dispose();
    content.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (busy) return;
    if (title.text.isEmpty && content.text.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final discard = await appShowDialog<bool>(
      context: context,
      builder: (c) => AppAlertDialog(
        title: const Text('离开编辑？'),
        content: const Text('本次尚未发布的内容将不会保存。'),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('继续编辑'),
          ),
          AppTextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('放弃内容'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      widget.onContentChanged?.call('');
      setState(() => allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (content.text.trim().isEmpty) {
      setState(() {
        error = '请先写一点内容';
        preview = false;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref.read(communityProvider).post(
        reply
            ? '/forum/topics/${widget.topicId}/posts'
            : '/forum/boards/${Uri.encodeComponent(slug!)}/topics',
        {
          'content': content.text.trim(),
          if (!reply) 'title': title.text.trim(),
          if (widget.replyTo != null) 'replyToPostId': widget.replyTo,
        },
      );
      if (!mounted) return;
      notice(
        context,
        result['needsReview'] == true || result['post']?['status'] == 'pending'
            ? '已提交，审核通过后会显示'
            : '发布成功',
      );
      setState(() => allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apple = appleTokensOf(context) != null;
    return PopScope(
      canPop:
          allowExit || (!busy && title.text.isEmpty && content.text.isEmpty),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: AppScaffold(
        backgroundColor: appleTokensOf(context)?.cardBackground,
        appBar: AppNavigationBar(
          title: Text(reply ? '写回复' : '发起讨论'),
          leading: apple
              ? AppTextButton(
                  onPressed: busy ? null : leave,
                  child: const Text('取消'),
                )
              : null,
          actions: [
            if (apple)
              AppTextButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? '发布中' : '发布'),
              )
            else
              AppTextButton(
                onPressed: () => setState(() => preview = !preview),
                child: Text(preview ? '编辑' : '预览'),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: PageWidth(
            child: Form(
              key: form,
              child: ListView(
                padding: EdgeInsets.all(apple ? 20 : 24),
                children: [
                  if (!reply) ...[
                    AppDropdownButtonFormField<String>(
                      initialValue: slug,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '发布到版块'),
                      items: widget.boards
                          .map(
                            (b) => DropdownMenuItem(
                              value: str(b['slug']),
                              child: MarkdownText(
                                str(b['name']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: busy ? null : (v) => setState(() => slug = v),
                      validator: (v) => v == null ? '请选择版块' : null,
                    ),
                    const SizedBox(height: 20),
                    AppTextFormField(
                      controller: title,
                      autofocus: widget.initialContent.isNotEmpty,
                      enabled: !busy,
                      maxLength: 120,
                      maxLines: 2,
                      minLines: 1,
                      decoration: const InputDecoration(
                        labelText: '一个清晰的标题',
                        hintText: '你想和大家聊什么？',
                      ),
                      validator: (v) => v == null || v.trim().length < 2
                          ? '标题至少需要 2 个字符'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.replyName != null) ...[
                    SmallTag('回复 ${widget.replyName}'),
                    const SizedBox(height: 16),
                  ],
                  if (apple)
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppTextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => preview = !preview),
                        child: Text(preview ? '继续编辑' : '预览正文'),
                      ),
                    ),
                  if (preview)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: MarkdownContent(
                        content.text.isEmpty ? '预览会显示在这里。' : content.text,
                      ),
                    )
                  else
                    AppTextFormField(
                      controller: content,
                      enabled: !busy,
                      minLines: 10,
                      maxLines: null,
                      maxLength: 100000,
                      decoration: InputDecoration(
                        labelText: reply ? '回复内容' : '正文',
                        alignLabelWithHint: true,
                        hintText: '写下你的想法…\n\n支持 Markdown 格式。',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '请先写一点内容' : null,
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (!apple)
                    AppFilledButton.icon(
                      onPressed: busy ? null : submit,
                      icon: const AppIcon(Icons.arrow_upward_rounded),
                      label: Text(
                        busy
                            ? '正在发布…'
                            : reply
                            ? '发布回复'
                            : '发布讨论',
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    '友善表达，尊重每一种不同的声音。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
