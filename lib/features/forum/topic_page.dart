import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/widgets/design.dart';
import '../auth/auth_gate.dart';
import '../profile/user_page.dart';
import '../../core/widgets/inline_composer.dart';

class TopicPage extends ConsumerStatefulWidget {
  const TopicPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends ConsumerState<TopicPage> {
  final draft = TextEditingController();
  final replyFocus = FocusNode();
  Json? replyTarget;
  bool sending = false, allowExit = false;
  @override
  void dispose() {
    draft.dispose();
    replyFocus.dispose();
    super.dispose();
  }

  Json? topic;
  List<Json> posts = [];
  Set<String> liked = {}, busyLikes = {};
  Object? error;
  bool busy = true, more = false, hasMore = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool append = false}) async {
    final ticket = ++generation;
    setState(() {
      error = null;
      if (append) {
        more = true;
      } else {
        busy = true;
      }
    });
    try {
      final data = await ref
          .read(communityProvider)
          .get(
            '/forum/topics/${widget.id}',
            query: {'offset': append ? posts.length : 0},
          );
      if (!mounted || ticket != generation) return;
      final batch = jsonList(data['posts']);
      setState(() {
        topic = Json.from(data['topic']);
        posts = append ? [...posts, ...batch] : batch;
        hasMore = batch.length == 50;
        final next = (data['likedPostIds'] as List? ?? [])
            .map((e) => e.toString())
            .toSet();
        liked = append ? {...liked, ...next} : next;
      });
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    } finally {
      if (mounted && ticket == generation) {
        setState(() {
          busy = false;
          more = false;
        });
      }
    }
  }

  void reply([Json? post]) {
    if (sending) return;
    setState(() => replyTarget = post);
    replyFocus.requestFocus();
  }

  Future<void> sendReply() async {
    if (sending || draft.text.trim().isEmpty || topic?['is_locked'] == true) {
      return;
    }
    setState(() => sending = true);
    try {
      if (!await requireSession(context, ref) || !mounted) return;
      final result = await ref.read(communityProvider).post(
        '/forum/topics/${widget.id}/posts',
        {
          'content': draft.text.trim(),
          if (replyTarget != null) 'replyToPostId': replyTarget!['id'],
        },
      );
      if (!mounted) return;
      draft.clear();
      setState(() => replyTarget = null);
      replyFocus.unfocus();
      notice(
        context,
        result['needsReview'] == true || result['post']?['status'] == 'pending'
            ? '已提交，等待审核'
            : '回复成功',
      );
      await load();
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> toggleLike(Json post) async {
    final id = str(post['id']);
    if (busyLikes.contains(id)) return;
    if (!await requireSession(context, ref) || !mounted) return;
    setState(() => busyLikes.add(id));
    try {
      await ref
          .read(communityProvider)
          .post('/forum/posts/$id/${liked.contains(id) ? 'unlike' : 'like'}');
      if (mounted) {
        setState(() => liked.contains(id) ? liked.remove(id) : liked.add(id));
      }
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busyLikes.remove(id));
    }
  }

  Future<void> confirmExit() async {
    if (sending) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('放弃回复？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('放弃内容'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: draft,
    builder: (context, value, _) => PopScope(
      canPop: allowExit || (!sending && value.text.isEmpty),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('讨论详情'),
          actions: [
            IconButton(
              tooltip: '复制讨论链接',
              onPressed: topic == null
                  ? null
                  : () async {
                      try {
                        final boards = await ref
                            .read(communityProvider)
                            .boards();
                        final board = boards.firstWhere(
                          (b) => b['id'] == topic!['board_id'],
                        );
                        if (context.mounted) {
                          await copyLink(
                            context,
                            '/forum/${board['slug']}/${widget.id}',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) notice(context, e);
                      }
                    },
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: PageWidth(
            child: RefreshIndicator(
              onRefresh: () => load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (busy && topic == null)
                    const LoadingRows()
                  else if (topic == null && error != null)
                    ErrorPanel(error!, () => load())
                  else if (topic != null) ...[
                    if (busy) const LinearProgressIndicator(minHeight: 2),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              const SmallTag('社区讨论'),
                              if (topic!['is_pinned'] == true)
                                const SmallTag('置顶'),
                              if (topic!['is_locked'] == true)
                                const SmallTag('已锁定'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            str(topic!['title']),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '${dateLabel(topic!['created_at'])}  ·  ${topic!['view_count'] ?? 0} 次浏览',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    ...posts.asMap().entries.map((entry) {
                      final p = entry.value;
                      final first = entry.key == 0;
                      final author = str(
                        p['authorDisplayName'],
                        str(p['authorUsername'], '访客'),
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(24),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                PersonAvatar(author, size: 38),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: p['authorUsername'] == null
                                        ? null
                                        : () => openPage(
                                            context,
                                            UserPage(
                                              username: str(
                                                p['authorUsername'],
                                              ),
                                            ),
                                          ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            author,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            dateLabel(p['created_at']),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SmallTag(first ? '楼主' : '${entry.key + 1} 楼'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (p['reply_to_post_id'] != null) ...[
                              const SmallTag('回复讨论中的一条留言'),
                              const SizedBox(height: 12),
                            ],
                            MarkdownContent(str(p['content_md'])),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: busyLikes.contains(str(p['id']))
                                      ? null
                                      : () => toggleLike(p),
                                  icon: Icon(
                                    liked.contains(str(p['id']))
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 19,
                                  ),
                                  label: Text(
                                    liked.contains(str(p['id'])) ? '已赞' : '点赞',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: topic!['is_locked'] == true
                                      ? null
                                      : () => reply(p),
                                  icon: const Icon(
                                    Icons.reply_rounded,
                                    size: 20,
                                  ),
                                  label: const Text('回复'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    if (error != null)
                      ErrorPanel(error!, () => load(append: posts.isNotEmpty)),
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: OutlinedButton(
                          onPressed: more ? null : () => load(append: true),
                          child: Text(more ? '正在加载…' : '查看更多回复'),
                        ),
                      ),
                    if (posts.length == 1)
                      const StatePanel(
                        title: '暂无回复',
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: topic == null
            ? null
            : Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: InlineComposer(
                  controller: draft,
                  focusNode: replyFocus,
                  inputKey: const ValueKey('reply-composer'),
                  hint: topic!['is_locked'] == true ? '此讨论已锁定' : '说点什么…',
                  enabled: topic!['is_locked'] != true,
                  busy: sending,
                  target: replyTarget == null
                      ? null
                      : str(
                          replyTarget!['authorDisplayName'],
                          str(replyTarget!['authorUsername'], '访客'),
                        ),
                  onCancelTarget: () => setState(() => replyTarget = null),
                  onSend: sendReply,
                ),
              ),
      ),
    ),
  );
}
