import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import '../../core/widgets/paged_feed.dart';
import 'resource_page.dart';
import 'resource_tile.dart';

final cardsProvider = FutureProvider<List<Json>>((ref) async {
  ref.watch(sessionProvider);
  return jsonList(
    (await ref.read(communityProvider).get('/downloads/cards'))['cards'],
  );
});

class CardDirectoryPage extends ConsumerWidget {
  const CardDirectoryPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScaffold(
    appBar: AppNavigationBar(
      title: const Text('资源目录'),
      actions: [
        AppIconButton(
          tooltip: '复制目录链接',
          onPressed: () => copyLink(context, '/downloads/card/$id'),
          icon: const AppIcon(Icons.ios_share_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: PageWidth(child: DirectoryView(parentId: id)),
    ),
  );
}

class DirectoryView extends ConsumerStatefulWidget {
  const DirectoryView({super.key, this.parentId, this.header});
  final String? parentId;
  final Widget? header;
  @override
  ConsumerState<DirectoryView> createState() => _DirectoryViewState();
}

class _DirectoryViewState extends ConsumerState<DirectoryView> {
  int revision = 0;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(cardsProvider);
    Widget content;
    if (cards.isLoading) {
      content = ListView(children: [?widget.header, const LoadingRows()]);
    } else if (cards.hasError) {
      content = ListView(
        children: [
          ?widget.header,
          ErrorPanel(cards.error!, () => ref.invalidate(cardsProvider)),
        ],
      );
    } else {
      final items = cards.value ?? [];
      final parent = items.where((c) => c['id'] == widget.parentId).firstOrNull;
      final children =
          items.where((c) => c['parentId'] == widget.parentId).toList()..sort(
            (a, b) => ((a['position'] as num?) ?? 0).compareTo(
              (b['position'] as num?) ?? 0,
            ),
          );
      if (widget.parentId != null && parent == null) {
        return ListView(
          children: [
            ErrorPanel(
              const RequestFailure('这个目录不存在，或当前账号无权访问。'),
              () => ref.invalidate(cardsProvider),
            ),
          ],
        );
      }
      final intro =
          widget.header ?? PageIntro(str(parent?['title']), markdown: true);
      if (parent?['kind'] == 'redirect') {
        return ListView(
          children: [
            intro,
            StatePanel(
              title: '外部资源',
              message:
                  Uri.tryParse(str(parent?['redirectUrl']))?.host ?? '外部网站',
              icon: Icons.open_in_new_rounded,
              action: AppFilledButton.icon(
                onPressed: () =>
                    externalLink(context, str(parent?['redirectUrl'])),
                icon: const AppIcon(Icons.open_in_new_rounded),
                label: const Text('打开资源'),
              ),
            ),
          ],
        );
      }
      if (parent != null && children.isEmpty) {
        return PagedFeed(
          key: ValueKey('${widget.parentId}:$revision'),
          path: '/downloads/resources',
          listKey: 'resources',
          emptyTitle: '暂无资源',
          emptyMessage: '',
          header: intro,
          itemBuilder: (r) => ResourceTile(
            r,
            onTap: () async {
              await openPage(context, ResourcePage(id: str(r['id'])));
              if (mounted) setState(() => revision++);
            },
          ),
        );
      }
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          intro,
          if (children.isEmpty)
            const StatePanel(title: '暂无目录', icon: Icons.folder_open_rounded),
          ...children.map((card) {
            final external = card['kind'] == 'redirect';
            final count = items
                .where((c) => c['parentId'] == card['id'])
                .length;
            return Column(
              children: [
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  leading: AppIcon(
                    external
                        ? Icons.insert_drive_file_outlined
                        : Icons.folder_open_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: MarkdownText(
                    str(card['title']),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    external ? '外部资源' : '$count 个项目',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: AppIcon(
                    external
                        ? Icons.north_east_rounded
                        : Icons.chevron_right_rounded,
                    size: 21,
                  ),
                  onTap: () =>
                      openPage(context, CardDirectoryPage(id: str(card['id']))),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: AppDivider(),
                ),
              ],
            );
          }),
        ],
      );
    }
    return AppRefresh(
      onRefresh: () async {
        ref.invalidate(cardsProvider);
        try {
          await ref.read(cardsProvider.future);
        } catch (_) {
          /* Error panel owns feedback. */
        }
      },
      child: content,
    );
  }
}
