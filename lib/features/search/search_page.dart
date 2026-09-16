import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/widgets/design.dart';
import '../forum/forum_page.dart';
import '../forum/topic_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final query = TextEditingController();
  List<Json>? results;
  Object? error;
  bool busy = false;
  int generation = 0;
  String submitted = '';
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final value = query.text.trim();
    if (value.isEmpty) return;
    FocusScope.of(context).unfocus();
    final ticket = ++generation;
    setState(() {
      busy = true;
      error = null;
      submitted = value;
    });
    try {
      final data = await ref
          .read(communityProvider)
          .get('/forum/search', query: {'q': value, 'scope': 'topics'});
      if (mounted && ticket == generation) {
        setState(() => results = jsonList(data['topics']));
      }
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    } finally {
      if (mounted && ticket == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('搜索社区')),
    body: SafeArea(
      child: PageWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: TextField(
                controller: query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => search(),
                decoration: InputDecoration(
                  hintText: '搜索讨论标题与内容',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: '开始搜索',
                    onPressed: search,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (busy)
                    const LoadingRows()
                  else if (error != null)
                    ErrorPanel(error!, search)
                  else if (results == null)
                    const StatePanel(
                      title: '搜索讨论',
                      icon: Icons.travel_explore_rounded,
                    )
                  else if (results!.isEmpty)
                    StatePanel(
                      title: '没有找到相关讨论',
                      message: '试试其他关键词',
                      icon: Icons.search_off_rounded,
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      child: Text(
                        '“$submitted” 的相关讨论',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ...results!.map(
                      (t) => TopicTile(
                        t,
                        onTap: () =>
                            openPage(context, TopicPage(id: str(t['id']))),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '显示最相关的 ${results!.length} 条结果',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
