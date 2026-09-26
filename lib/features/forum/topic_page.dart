import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/apple_chrome.dart';
import '../../core/design/tokens.dart';
import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/auth_gate.dart';
import '../profile/user_page.dart';
import '../../core/widgets/inline_composer.dart';
import 'content_actions.dart';

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
  bool contentActionBusy = false;
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

  Future<void> topicAction(String action) async {
    if (contentActionBusy || topic == null) return;
    final user = ref.read(sessionProvider).value;
    final identity = ContentIdentity.capture(user);
    if (action != 'delete' && !canModerateTopics(user)) return;
    if (action == 'delete') {
      final confirmed = await confirmContentAction(
        context,
        title: '删除这个讨论？',
        message: '讨论及其全部回复将不再公开显示。此操作没有可用的恢复入口。',
        confirmLabel: '删除讨论',
      );
      if (!confirmed || !mounted) return;
      final current = ref.read(sessionProvider).value;
      if (!identity.matches(current) ||
          !canDeleteTopic(current, contentAuthorId(topic!))) {
        notice(context, '账号状态已变化，请重新操作');
        return;
      }
    }
    String? boardId;
    if (action == 'move') {
      List<Json> boards;
      try {
        boards = await ref.read(communityProvider).boards();
      } catch (e) {
        if (mounted) notice(context, e);
        return;
      }
      if (!mounted || !identity.matches(ref.read(sessionProvider).value)) {
        return;
      }
      boardId = await appShowDialog<String>(
        context: context,
        builder: (c) => AppSimpleDialog(
          title: const Text('移动到版块'),
          children: boards
              .where((b) => str(b['id']) != str(topic!['board_id']))
              .map(
                (b) => AppSimpleDialogOption(
                  onPressed: () => Navigator.pop(c, str(b['id'])),
                  child: MarkdownText(str(b['name'])),
                ),
              )
              .toList(),
        ),
      );
      if (boardId == null || !mounted) return;
    }
    if (!identity.matches(ref.read(sessionProvider).value)) {
      notice(context, '账号状态已变化，请重新操作');
      return;
    }
    setState(() => contentActionBusy = true);
    try {
      if (action == 'delete') {
        await ref.read(communityProvider).delete('/forum/topics/${widget.id}');
        if (mounted) {
          setState(() => allowExit = true);
          Navigator.pop(context, true);
        }
        return;
      }
      final data = await ref.read(communityProvider).post(
        '/forum/topics/${widget.id}/action',
        {'action': action, 'boardId': ?boardId},
      );
      if (!mounted) return;
      setState(() {
        topic = Json.from(data['topic']);
      });
      notice(context, '操作成功');
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => contentActionBusy = false);
    }
  }

  Future<void> postAction(Json post, String action) async {
    if (contentActionBusy) return;
    final user = ref.read(sessionProvider).value;
    final identity = ContentIdentity.capture(user);
    final postId = str(post['id']);
    if (action == 'edit') {
      await editReplyDialog(
        context,
        str(post['content_md']),
        onSave: (content) async {
          if (!mounted ||
              !identity.matches(ref.read(sessionProvider).value) ||
              !canEditReply(
                ref.read(sessionProvider).value,
                contentAuthorId(post),
              )) {
            throw const RequestFailure('账号状态已变化，请重新操作');
          }
          final data = await ref.read(communityProvider).patch(
            '/forum/posts/$postId',
            {'content': content},
          );
          if (!mounted) return;
          setState(() {
            final index = posts.indexWhere((p) => str(p['id']) == postId);
            if (index >= 0) posts[index] = Json.from(data['post']);
          });
        },
      );
      return;
    }
    final confirmed = await confirmContentAction(
      context,
      title: '删除这条回复？',
      message: '这条回复将不再公开显示，引用它的上下文也可能变得不完整。',
      confirmLabel: '删除回复',
    );
    if (!confirmed || !mounted) return;
    final current = ref.read(sessionProvider).value;
    if (!identity.matches(current) ||
        !canDeleteReply(current, contentAuthorId(post))) {
      notice(context, '账号状态已变化，请重新操作');
      return;
    }
    setState(() => contentActionBusy = true);
    try {
      await ref.read(communityProvider).delete('/forum/posts/$postId');
      if (!mounted) return;
      setState(() {
        posts.removeWhere((p) => str(p['id']) == postId);
        if (str(replyTarget?['id']) == postId) replyTarget = null;
      });
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => contentActionBusy = false);
    }
  }

  Future<void> confirmExit() async {
    if (sending) return;
    final discard = await appShowDialog<bool>(
      context: context,
      builder: (c) => AppAlertDialog(
        title: const Text('放弃回复？'),
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
    builder: (context, value, _) {
      final apple = appleTokensOf(context) != null;
      final actions = <Widget>[
        if (topic != null &&
            (canModerateTopics(ref.watch(sessionProvider).value) ||
                canDeleteTopic(
                  ref.watch(sessionProvider).value,
                  contentAuthorId(topic!),
                )))
          AppPopupMenuButton<String>(
            destructiveValues: const {'delete'},
            tooltip: '管理讨论',
            enabled: !contentActionBusy,
            onSelected: topicAction,
            itemBuilder: (_) => [
              if (canModerateTopics(ref.read(sessionProvider).value)) ...[
                PopupMenuItem(
                  value: topic!['is_pinned'] == true ? 'unpin' : 'pin',
                  child: Text(topic!['is_pinned'] == true ? '取消置顶' : '置顶'),
                ),
                PopupMenuItem(
                  value: topic!['is_locked'] == true ? 'unlock' : 'lock',
                  child: Text(topic!['is_locked'] == true ? '解锁讨论' : '锁定讨论'),
                ),
                const PopupMenuItem(value: 'move', child: Text('移动版块')),
              ],
              const PopupMenuItem(value: 'delete', child: Text('删除讨论')),
            ],
          ),
        AppIconButton(
          tooltip: '复制讨论链接',
          onPressed: topic == null
              ? null
              : () async {
                  try {
                    final boards = await ref.read(communityProvider).boards();
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
          icon: const AppIcon(Icons.ios_share_rounded),
        ),
      ];
      final children = <Widget>[
        if (busy && topic == null)
          const LoadingRows()
        else if (topic == null && error != null)
          ErrorPanel(error!, () => load())
        else if (topic != null) ...[
          if (busy) const AppProgress(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    if (!apple) const SmallTag('社区讨论'),
                    if (topic!['is_pinned'] == true) const SmallTag('置顶'),
                    if (topic!['is_locked'] == true) const SmallTag('已锁定'),
                  ],
                ),
                if (!apple ||
                    topic!['is_pinned'] == true ||
                    topic!['is_locked'] == true)
                  const SizedBox(height: 18),
                MarkdownText(
                  str(topic!['title']),
                  style: apple
                      ? AppleType.title2.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        )
                      : Theme.of(context).textTheme.headlineMedium,
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
            // 楼层标签跟 position 字段走（与网页版一致）：position 1
            // 是楼主帖，可能在列表最下方（接口按时间倒序返回），
            // 不能用列表下标当楼层。
            final floor = (p['position'] as num?)?.toInt();
            final author = str(
              p['authorDisplayName'],
              str(p['authorUsername'], '访客'),
            );
            final apple = appleTokensOf(context) != null;
            final scheme = Theme.of(context).colorScheme;
            return Container(
              // Apple：平铺在分组底色上，楼与楼之间用内缩发丝线分开，
              // 不给每层套卡片——卡片会把长正文挤窄，也会让相邻楼层
              // 看起来像彼此独立的模块，而它们本是一条连续的对话。
              margin: EdgeInsets.only(bottom: apple ? 0 : 10),
              padding: EdgeInsets.fromLTRB(
                apple ? AppleSpacing.gutter : 24,
                apple ? AppleSpacing.lg : 24,
                apple ? AppleSpacing.gutter : 24,
                apple ? 0 : 24,
              ),
              decoration: apple
                  ? null
                  : BoxDecoration(color: scheme.surfaceContainerLowest),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        author,
                        size: 38,
                        path: p['authorAvatarPath'] as String?,
                        username: p['authorUsername'] as String?,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTap(
                          onTap: p['authorUsername'] == null
                              ? null
                              : () => openPage(
                                  context,
                                  UserPage(username: str(p['authorUsername'])),
                                ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  author,
                                  style: apple
                                      ? AppleType.subheadline.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                          fontFamilyFallback: appleFontFallback,
                                        )
                                      : const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                ),
                                Text(
                                  dateLabel(p['created_at']),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (apple)
                        Text(
                          floor == 1 ? '楼主' : '${floor ?? entry.key + 1} 楼',
                          style: AppleType.footnote.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      else
                        SmallTag(
                          floor == 1 ? '楼主' : '${floor ?? entry.key + 1} 楼',
                        ),
                      if (canEditReply(
                            ref.watch(sessionProvider).value,
                            contentAuthorId(p),
                          ) ||
                          canDeleteReply(
                            ref.watch(sessionProvider).value,
                            contentAuthorId(p),
                          ))
                        AppPopupMenuButton<String>(
                          destructiveValues: const {'delete'},
                          tooltip: '管理回复',
                          enabled: !contentActionBusy,
                          onSelected: (action) => postAction(p, action),
                          itemBuilder: (_) => [
                            if (canEditReply(
                              ref.read(sessionProvider).value,
                              contentAuthorId(p),
                            ))
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('编辑回复'),
                              ),
                            if (canDeleteReply(
                              ref.read(sessionProvider).value,
                              contentAuthorId(p),
                            ))
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('删除回复'),
                              ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: apple ? 14 : 20),
                  if (p['reply_to_post_id'] != null) ...[
                    const SmallTag('回复讨论中的一条留言'),
                    const SizedBox(height: 12),
                  ],
                  MarkdownContent(str(p['content_md'])),
                  SizedBox(height: apple ? 6 : 18),
                  Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      AppTextButton.icon(
                        onPressed: busyLikes.contains(str(p['id']))
                            ? null
                            : () => toggleLike(p),
                        icon: AppIcon(
                          liked.contains(str(p['id']))
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          // 已赞时用系统红：点赞在 iOS 上是语义动作，
                          // 用品牌色会读成「另一个可点按钮」。
                          color: apple && liked.contains(str(p['id']))
                              ? const Color(0xFFFF3B30)
                              : null,
                          size: 19,
                        ),
                        label: Text(liked.contains(str(p['id'])) ? '已赞' : '点赞'),
                      ),
                      AppTextButton.icon(
                        onPressed: topic!['is_locked'] == true
                            ? null
                            : () => reply(p),
                        icon: const AppIcon(Icons.reply_rounded, size: 20),
                        label: const Text('回复'),
                      ),
                    ],
                  ),
                  if (apple)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: AppleSeparator(inset: 0),
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
              child: AppOutlinedButton(
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
      ];
      return PopScope(
        canPop: allowExit || (!sending && value.text.isEmpty),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) confirmExit();
        },
        child: AppScaffold(
          backgroundColor: appleTokensOf(context)?.cardBackground,
          appBar: apple
              ? null
              : AppNavigationBar(title: const Text('讨论详情'), actions: actions),
          body: apple
              ? AppleScrollPage(
                  title: '讨论详情',
                  largeTitle: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions,
                  ),
                  onRefresh: () => load(),
                  slivers: [SliverList.list(children: children)],
                )
              : SafeArea(
                  bottom: false,
                  child: PageWidth(
                    child: AppRefresh(
                      onRefresh: () => load(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: children,
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
      );
    },
  );
}
