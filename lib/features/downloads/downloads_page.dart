import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import '../../core/widgets/paged_feed.dart';
import 'resource_page.dart';
import 'resource_tile.dart';
import 'card_directory.dart';

final categoriesProvider = FutureProvider<List<Json>>((ref) {
  ref.watch(sessionProvider);
  return ref.read(communityProvider).categories();
});

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});
  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  String? category;
  bool directory = true;
  int revision = 0;
  @override
  Widget build(BuildContext context) {
    final modeSwitch = Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: true,
            label: Text('资源目录'),
            icon: Icon(Icons.folder_open_rounded),
          ),
          ButtonSegment(
            value: false,
            label: Text('社区分享'),
            icon: Icon(Icons.inventory_2_outlined),
          ),
        ],
        selected: {directory},
        showSelectedIcon: false,
        onSelectionChanged: (v) => setState(() => directory = v.first),
      ),
    );
    if (directory) {
      return SafeArea(
        bottom: false,
        child: PageWidth(
          child: DirectoryView(
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const PageIntro('资源'), modeSwitch],
            ),
          ),
        ),
      );
    }
    final categories = ref.watch(categoriesProvider);
    final categoryId = categories.value?.any((c) => c['id'] == category) == true
        ? category
        : null;
    return SafeArea(
      bottom: false,
      child: PageWidth(
        child: PagedFeed(
          key: ValueKey(
            '$categoryId:${ref.watch(sessionProvider).value?['id']}:$revision',
          ),
          path: '/downloads/resources',
          listKey: 'resources',
          query: {'categoryId': ?categoryId},
          emptyTitle: '暂无资源',
          emptyMessage: '',
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageIntro('资源'),
              modeSwitch,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('全部资源'),
                      selected: categoryId == null,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => category = null),
                    ),
                    ...?(categories.value?.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: MarkdownText(str(c['name']), maxLines: 1),
                          selected: categoryId == c['id'],
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => category = str(c['id'])),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              if (categories.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(categoriesProvider),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('分类加载失败，点击重试'),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
          itemBuilder: (r) => ResourceTile(
            r,
            onTap: () async {
              await openPage(context, ResourcePage(id: str(r['id'])));
              if (mounted) setState(() => revision++);
            },
          ),
        ),
      ),
    );
  }
}
