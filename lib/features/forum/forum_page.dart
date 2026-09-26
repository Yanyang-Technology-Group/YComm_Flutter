import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/apple_chrome.dart';
import '../../core/design/tokens.dart';
import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/paged_feed.dart';
import '../auth/auth_gate.dart';
import '../search/search_page.dart';
import 'topic_page.dart';
import 'compose_page.dart';
import '../../core/widgets/inline_composer.dart';

final boardsProvider = FutureProvider<List<Json>>((ref) {
  ref.watch(sessionProvider);
  return ref.read(communityProvider).boards();
});

class ForumPage extends ConsumerStatefulWidget {
  const ForumPage({super.key});
  @override
  ConsumerState<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends ConsumerState<ForumPage> {
  final draft = TextEditingController();
  bool composing = false;
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  Future<void> compose(List<Json> boards) async {
    if (composing) return;
    composing = true;
    try {
      FocusScope.of(context).unfocus();
      if (!await requireSession(context, ref) || !mounted) return;
      final result = await openTaskPage<bool>(
        context,
        ComposePage(
          boards: boards,
          initialSlug: selected,
          initialContent: draft.text,
          onContentChanged: (text) => draft.text = text,
        ),
      );
      if (result == true && mounted) {
        draft.clear();
        setState(() => revision++);
      }
    } finally {
      composing = false;
    }
  }

  String? selected;
  int revision = 0;
  @override
  Widget build(BuildContext context) {
    final boards = ref.watch(boardsProvider);
    final apple = appleTokensOf(context) != null;
    final search = AppIconButton(
      tooltip: '搜索讨论',
      onPressed: () => openPage(context, const SearchPage()),
      icon: const AppIcon(Icons.search_rounded),
    );
    final tools = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        search,
        AppIconButton(
          tooltip: '发起讨论',
          onPressed: boards.value?.isNotEmpty == true
              ? () => compose(boards.value!)
              : null,
          icon: const AppIcon(Icons.edit_outlined),
        ),
      ],
    );
    Widget statePage(Widget child) => apple
        ? AppleScrollPage(
            title: '社区',
            trailing: tools,
            automaticallyImplyLeading: false,
            slivers: [SliverToBoxAdapter(child: child)],
          )
        : SingleChildScrollView(child: child);
    final body = boards.when(
      loading: () => statePage(const LoadingRows()),
      error: (e, s) =>
          statePage(ErrorPanel(e, () => ref.invalidate(boardsProvider))),
      data: (items) {
        if (items.isEmpty) {
          return statePage(
            const StatePanel(title: '暂无版块', icon: Icons.forum_outlined),
          );
        }
        final board = items.firstWhere(
          (e) => e['slug'] == selected,
          orElse: () => items.first,
        );
        return PagedFeed(
          key: ValueKey(
            '${board['slug']}:${ref.watch(sessionProvider).value?['id']}',
          ),
          refreshRevision: revision,
          appleAutomaticallyImplyLeading: false,
          appleTitle: apple ? '社区' : null,
          appleTrailing: apple ? tools : null,
          appleBottom: apple
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AppleChoiceMenu<String>(
                              key: const ValueKey('apple-board-picker'),
                              semanticLabel: '切换版块',
                              value: str(board['slug']),
                              choices: {
                                for (final item in items)
                                  str(item['slug']): MarkdownText(
                                    str(item['name']),
                                  ),
                              },
                              onChanged: (value) =>
                                  setState(() => selected = value),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '最近更新',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          path:
              '/forum/boards/${Uri.encodeComponent(str(board['slug']))}/topics',
          listKey: 'topics',
          emptyTitle: '暂无讨论',
          emptyMessage: '',
          header: apple
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageIntro('社区'),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: items
                            .map(
                              (b) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: AppChoiceChip(
                                  label: MarkdownText(
                                    str(b['name']),
                                    maxLines: 1,
                                  ),
                                  selected: b['slug'] == board['slug'],
                                  showCheckmark: false,
                                  onSelected: (_) =>
                                      setState(() => selected = str(b['slug'])),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Row(
                        children: [
                          Text(
                            '版块讨论',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '最近更新',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          itemBuilder: (t) => TopicTile(
            t,
            onTap: () async {
              await openPage(context, TopicPage(id: str(t['id'])));
              if (mounted) setState(() => revision++);
            },
          ),
        );
      },
    );
    return AppScaffold(
      body: apple
          ? body
          : SafeArea(
              bottom: false,
              child: PageWidth(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
                      child: Row(
                        children: [const AppLogo(), const Spacer(), search],
                      ),
                    ),
                    Expanded(child: body),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: !apple && boards.value?.isNotEmpty == true
          ? InlineComposer(
              controller: draft,
              inputKey: const ValueKey('community-composer'),
              hint: '分享新鲜事…',
              sendLabel: '继续发布',
              onSend: () => compose(boards.value!),
            )
          : null,
    );
  }
}

class TopicTile extends StatelessWidget {
  const TopicTile(this.topic, {super.key, required this.onTap});
  final Json topic;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final preview = topic['preview'] is Map
        ? topic['preview']['firstPost']
        : null;
    final author = str(
      topic['authorDisplayName'],
      str(topic['authorUsername'], '访客'),
    );
    final excerpt = preview is Map ? str(preview['contentExcerpt']) : '';
    // 阅读列表按下立即高亮，保持文字位置稳定；
    // 行尾用内缩发丝线，不用通栏 Divider。
    if (appleTokensOf(context) != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PressableScale(
            onTap: onTap,
            pressedScale: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppleSpacing.gutter,
                AppleSpacing.lg,
                AppleSpacing.gutter,
                AppleSpacing.md,
              ),
              child: _appleContent(context, author, excerpt),
            ),
          ),
          const AppleSeparator(inset: AppleSpacing.gutter),
        ],
      );
    }
    return AppSurface(
      color: Colors.transparent,
      child: AppTap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _content(context, topic, author, excerpt, preview),
              const SizedBox(height: 20),
              const AppDivider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appleContent(BuildContext context, String author, String excerpt) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = AppleType.footnote.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topic['is_pinned'] == true) ...[
          Text('置顶', style: secondary),
          const SizedBox(height: 4),
        ],
        MarkdownText(
          str(topic['title']),
          style: AppleType.headline.copyWith(color: scheme.onSurface),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(author, style: secondary),
            Text(
              dateLabel(
                topic['last_post_at'] ??
                    topic['created_at'] ??
                    topic['createdAt'],
              ),
              style: secondary,
            ),
          ],
        ),
        if (excerpt.isNotEmpty) ...[
          const SizedBox(height: 8),
          MarkdownText(
            excerpt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppleType.subheadline.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (topic.containsKey('reply_count'))
              _metric(
                context,
                Icons.chat_bubble_outline_rounded,
                '${topic['reply_count'] ?? 0} 回复',
              ),
            if (topic['is_locked'] == true)
              _metric(context, Icons.lock_outline, '已锁定'),
          ],
        ),
      ],
    );
  }

  /// 行内容主体。两种风格共用结构，只是排版节奏不同。
  Widget _content(
    BuildContext context,
    Json topic,
    String author,
    String excerpt,
    Object? preview,
  ) {
    final apple = appleTokensOf(context) != null;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(
              author,
              // Apple 侧头像略大一点：iOS 列表的作者信息是一级信息，
              // 不靠缩小来降低视觉重量，而是靠颜色变浅。
              size: apple ? 34 : 32,
              path: preview is Map
                  ? preview['authorAvatarPath'] as String?
                  : null,
              username: topic['authorUsername'] as String?,
            ),
            SizedBox(width: apple ? 10 : 9),
            Expanded(
              child: Text(
                author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: apple
                    ? AppleType.subheadline.copyWith(
                        color: scheme.onSurface,
                        fontFamilyFallback: appleFontFallback,
                      )
                    : Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Text(
              dateLabel(
                topic['last_post_at'] ??
                    topic['created_at'] ??
                    topic['createdAt'],
              ),
              style: apple
                  ? AppleType.footnote.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFamilyFallback: appleFontFallback,
                    )
                  : Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        SizedBox(height: apple ? 12 : 13),
        if (topic['is_pinned'] == true) ...[
          const SmallTag('置顶'),
          const SizedBox(height: 7),
        ],
        MarkdownText(
          str(topic['title']),
          // iOS 列表中标题是行主文字：17pt 半粗。excerpt 降一档到 15pt 次级色。
          style: apple
              ? AppleType.headline.copyWith(
                  color: scheme.onSurface,
                  fontFamilyFallback: appleFontFallback,
                )
              : Theme.of(context).textTheme.titleMedium,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (excerpt.isNotEmpty) ...[
          SizedBox(height: apple ? 5 : 8),
          MarkdownText(
            excerpt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: apple
                ? AppleType.subheadline.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFamilyFallback: appleFontFallback,
                  )
                : TextStyle(color: scheme.onSurfaceVariant, height: 1.6),
          ),
        ],
        SizedBox(height: apple ? 12 : 15),
        Wrap(
          spacing: apple ? 16 : 18,
          runSpacing: 8,
          children: [
            if (topic.containsKey('reply_count'))
              _metric(
                context,
                Icons.chat_bubble_outline_rounded,
                '${topic['reply_count'] ?? 0} 回复',
              ),
            if (topic.containsKey('view_count'))
              _metric(
                context,
                Icons.visibility_outlined,
                '${topic['view_count'] ?? 0} 浏览',
              ),
            if (topic['is_locked'] == true)
              _metric(context, Icons.lock_outline, '已锁定'),
          ],
        ),
      ],
    );
  }

  Widget _metric(BuildContext c, IconData icon, String text) {
    final apple = appleTokensOf(c) != null;
    final colour = Theme.of(c).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: apple ? 14 : 15, color: colour),
        const SizedBox(width: 5),
        Text(
          text,
          style: apple
              ? AppleType.footnote.copyWith(
                  color: colour,
                  fontFamilyFallback: appleFontFallback,
                )
              : Theme.of(c).textTheme.bodySmall,
        ),
      ],
    );
  }
}
