import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
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
      final result = await openPage<bool>(
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
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
      child: Row(
        children: [
          const AppLogo(),
          const Spacer(),
          IconButton(
            tooltip: '搜索讨论',
            onPressed: () => openPage(context, const SearchPage()),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageWidth(
          child: Column(
            children: [
              header,
              Expanded(
                child: boards.when(
                  loading: () =>
                      const SingleChildScrollView(child: LoadingRows()),
                  error: (e, s) => SingleChildScrollView(
                    child: ErrorPanel(e, () => ref.invalidate(boardsProvider)),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const SingleChildScrollView(
                        child: StatePanel(
                          title: '暂无版块',

                          icon: Icons.forum_outlined,
                        ),
                      );
                    }
                    final board = items.firstWhere(
                      (e) => e['slug'] == selected,
                      orElse: () => items.first,
                    );
                    return PagedFeed(
                      key: ValueKey(
                        '${board['slug']}:$revision:${ref.watch(sessionProvider).value?['id']}',
                      ),
                      path:
                          '/forum/boards/${Uri.encodeComponent(str(board['slug']))}/topics',
                      listKey: 'topics',
                      emptyTitle: '暂无讨论',
                      emptyMessage: '',
                      header: Column(
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
                                      child: ChoiceChip(
                                        label: Text(str(b['name'])),
                                        selected: b['slug'] == board['slug'],
                                        showCheckmark: false,
                                        onSelected: (_) => setState(
                                          () => selected = str(b['slug']),
                                        ),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
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
                        onTap: () =>
                            openPage(context, TopicPage(id: str(t['id']))),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: boards.value?.isNotEmpty == true
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
    final excerpt = preview is Map
        ? str(preview['contentExcerpt'])
              .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '[图片]')
              .replaceAll(RegExp(r'[#*`>]'), '')
        : '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PersonAvatar(author),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    dateLabel(
                      topic['last_post_at'] ??
                          topic['created_at'] ??
                          topic['createdAt'],
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              if (topic['is_pinned'] == true) ...[
                const SmallTag('置顶'),
                const SizedBox(height: 7),
              ],
              Text(
                str(topic['title']),
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (excerpt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
              const SizedBox(height: 15),
              Wrap(
                spacing: 18,
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
              const SizedBox(height: 20),
              const Divider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(BuildContext c, IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Theme.of(c).colorScheme.onSurfaceVariant),
      const SizedBox(width: 5),
      Text(text, style: Theme.of(c).textTheme.bodySmall),
    ],
  );
}
