import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import 'content_actions.dart';
import 'topic_page.dart';

class MyPostsPage extends ConsumerStatefulWidget {
  const MyPostsPage({super.key});

  @override
  ConsumerState<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends ConsumerState<MyPostsPage> {
  late Future<Json> future;
  final Set<String> busy = {};
  ContentIdentity? identity;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => future = ref.read(communityProvider).get('/auth/me/posts');

  Future<void> edit(Json post) async {
    final id = str(post['id']);
    if (busy.contains(id)) return;
    final user = ref.read(sessionProvider).value;
    final identity = ContentIdentity.capture(user);
    final saved = await editReplyDialog(
      context,
      str(post['content_md'] ?? post['contentMd']),
      onSave: (value) async {
        if (!mounted ||
            !identity.matches(ref.read(sessionProvider).value) ||
            !canEditReply(
              ref.read(sessionProvider).value,
              contentAuthorId(post),
            )) {
          throw const RequestFailure('账号状态已变化，请重新操作');
        }
        await ref.read(communityProvider).patch('/forum/posts/$id', {
          'content': value,
        });
      },
    );
    if (saved && mounted) setState(reload);
  }

  Future<void> delete(Json post) async {
    final id = str(post['id']);
    if (busy.contains(id)) return;
    final user = ref.read(sessionProvider).value;
    final identity = ContentIdentity.capture(user);
    final confirmed = await confirmContentAction(
      context,
      title: '删除这条回复？',
      message: '回复将不再公开显示。此操作没有可用的恢复入口。',
      confirmLabel: '删除回复',
    );
    if (!confirmed || !mounted) return;
    final current = ref.read(sessionProvider).value;
    if (!identity.matches(current) ||
        !canDeleteReply(current, contentAuthorId(post))) {
      notice(context, '账号状态已变化，请重新操作');
      return;
    }
    setState(() => busy.add(id));
    try {
      await ref.read(communityProvider).delete('/forum/posts/$id');
      if (!mounted) return;
      setState(reload);
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session.value != null) {
      identity ??= ContentIdentity.capture(session.value);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('我的回复')),
      body: SafeArea(
        child: PageWidth(
          child: session.isLoading
              ? const LoadingRows()
              : identity == null || !identity!.matches(session.value)
              ? const StatePanel(
                  title: '账号状态已变化',
                  message: '请返回后重新进入我的回复。',
                  icon: Icons.lock_outline,
                )
              : FutureBuilder<Json>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingRows();
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        children: [
                          ErrorPanel(snapshot.error!, () => setState(reload)),
                        ],
                      );
                    }
                    final posts = jsonList(snapshot.data!['posts']);
                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(reload);
                        await future;
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        children: posts.isEmpty
                            ? const [
                                StatePanel(
                                  title: '暂无回复',
                                  icon: Icons.chat_bubble_outline_rounded,
                                ),
                              ]
                            : posts.map(_postTile).toList(),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _postTile(Json post) {
    final id = str(post['id']);
    final topicId = str(post['topic_id'] ?? post['topicId']);
    final status = str(post['status'], 'published');
    final canOpen = topicId.isNotEmpty && status == 'published';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: canOpen
              ? () async {
                  await openPage(context, TopicPage(id: topicId));
                  if (mounted) setState(reload);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          SmallTag(status == 'pending' ? '待审核' : '回复'),
                          if (str(post['topicTitle'] ?? post['topic_title'])
                              .isNotEmpty)
                            SmallTag(
                              str(post['topicTitle'] ?? post['topic_title']),
                              markdown: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      MarkdownText(
                        str(post['content_md'] ?? post['contentMd']),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status == 'pending'
                            ? '审核通过后可在公开讨论中查看'
                            : dateLabel(
                                post['created_at'] ?? post['createdAt'],
                              ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !busy.contains(id),
                  tooltip: '管理回复',
                  onSelected: (action) =>
                      action == 'edit' ? edit(post) : delete(post),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑回复')),
                    PopupMenuItem(value: 'delete', child: Text('删除回复')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
