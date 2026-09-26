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
  Widget build(BuildContext context, WidgetRef ref) {
    if (isApple(context)) {
      return AppScaffold(
        body: DirectoryView(
          parentId: id,
          appleTitle: '资源目录',
          appleTrailing: AppIconButton(
            tooltip: '复制目录链接',
            onPressed: () => copyLink(context, '/downloads/card/$id'),
            icon: const AppIcon(Icons.ios_share_rounded),
          ),
        ),
      );
    }
    return AppScaffold(
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
}

class DirectoryView extends ConsumerStatefulWidget {
  const DirectoryView({
    super.key,
    this.parentId,
    this.header,
    this.appleTitle,
    this.appleTrailing,
  });
  final String? parentId;
  final Widget? header;
  final String? appleTitle;
  final Widget? appleTrailing;
  @override
  ConsumerState<DirectoryView> createState() => _DirectoryViewState();
}

class _DirectoryViewState extends ConsumerState<DirectoryView> {
  int revision = 0;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(cardsProvider);
    if (isApple(context)) return _appleDirectory(context, cards);
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
          key: ValueKey(widget.parentId),
          refreshRevision: revision,
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

  Future<void> _refresh() async {
    ref.invalidate(cardsProvider);
    try {
      await ref.read(cardsProvider.future);
    } catch (_) {
      // The directory error state provides the retry action.
    }
  }

  Widget _appleDirectory(BuildContext context, AsyncValue<List<Json>> cards) {
    final items = cards.value ?? <Json>[];
    final parent = items.where((c) => c['id'] == widget.parentId).firstOrNull;
    final title = parent == null
        ? (widget.appleTitle ?? '资源')
        : str(parent['title']);
    final children =
        items.where((c) => c['parentId'] == widget.parentId).toList()..sort(
          (a, b) => ((a['position'] as num?) ?? 0).compareTo(
            (b['position'] as num?) ?? 0,
          ),
        );
    Widget page(List<Widget> content) => AppleScrollPage(
      title: title,
      trailing: widget.appleTrailing,
      onRefresh: _refresh,
      slivers: [
        if (widget.header != null) SliverToBoxAdapter(child: widget.header!),
        SliverList.list(children: content),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
    if (cards.isLoading) return page([const LoadingRows()]);
    if (cards.hasError) return page([ErrorPanel(cards.error!, _refresh)]);
    if (widget.parentId != null && parent == null) {
      return page([
        ErrorPanel(const RequestFailure('这个目录不存在，或当前账号无权访问。'), _refresh),
      ]);
    }
    if (parent?['kind'] == 'redirect') {
      return page([
        StatePanel(
          title: '外部资源',
          message: Uri.tryParse(str(parent?['redirectUrl']))?.host ?? '外部网站',
          icon: Icons.insert_drive_file_outlined,
          action: AppFilledButton.icon(
            onPressed: () => externalLink(context, str(parent?['redirectUrl'])),
            icon: const AppIcon(Icons.open_in_new_rounded),
            label: const Text('打开资源'),
          ),
        ),
      ]);
    }
    if (parent != null && children.isEmpty) {
      return PagedFeed(
        key: ValueKey(widget.parentId),
        refreshRevision: revision,
        appleTitle: title,
        appleTrailing: widget.appleTrailing,
        path: '/downloads/resources',
        listKey: 'resources',
        emptyTitle: '暂无资源',
        emptyMessage: '',
        itemBuilder: (resource) => ResourceTile(
          resource,
          onTap: () async {
            await openPage(context, ResourcePage(id: str(resource['id'])));
            if (mounted) setState(() => revision++);
          },
        ),
      );
    }
    return page([
      if (children.isEmpty)
        const StatePanel(title: '暂无目录', icon: Icons.folder_open_rounded),
      if (children.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(
            '${children.length} 个项目',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      for (final card in children) ...[
        AppListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          leading: AppIcon(
            card['kind'] == 'redirect'
                ? Icons.insert_drive_file_outlined
                : Icons.folder_open_rounded,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: MarkdownText(
            str(card['title']),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            card['kind'] == 'redirect'
                ? '外部资源'
                : '${items.where((c) => c['parentId'] == card['id']).length} 个项目',
          ),
          trailing: const AppIcon(Icons.chevron_right_rounded, size: 16),
          onTap: () =>
              openPage(context, CardDirectoryPage(id: str(card['id']))),
        ),
        const Padding(padding: EdgeInsets.only(left: 68), child: AppDivider()),
      ],
    ]);
  }
}
