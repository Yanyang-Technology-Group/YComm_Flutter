import '../design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/community_api.dart';
import 'design.dart';

class PagedFeed extends ConsumerStatefulWidget {
  const PagedFeed({
    super.key,
    required this.path,
    required this.listKey,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptyMessage,
    this.query = const {},
    this.header,
    this.padding = EdgeInsets.zero,
  });
  final String path, listKey, emptyTitle, emptyMessage;
  final Json query;
  final Widget Function(Json) itemBuilder;
  final Widget? header;
  final EdgeInsets padding;
  @override
  ConsumerState<PagedFeed> createState() => _PagedFeedState();
}

class _PagedFeedState extends ConsumerState<PagedFeed> {
  List<Json> rows = [];
  bool loading = true, more = false, lastAppend = false;
  int total = 0, generation = 0;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool append = false}) async {
    final ticket = ++generation;
    lastAppend = append;
    setState(() {
      error = null;
      if (append) {
        more = true;
      } else {
        loading = true;
      }
    });
    try {
      final data = await ref
          .read(communityProvider)
          .get(
            widget.path,
            query: {
              ...widget.query,
              'offset': append ? rows.length : 0,
              'limit': 20,
            },
          );
      if (!mounted || ticket != generation) return;
      final next = jsonList(data[widget.listKey]);
      setState(() {
        rows = append ? [...rows, ...next] : next;
        total = (data['total'] as num?)?.toInt() ?? rows.length;
        if (append && next.isEmpty) total = rows.length;
      });
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    } finally {
      if (mounted && ticket == generation) {
        setState(() {
          loading = false;
          more = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppRefresh(
    onRefresh: () => load(),
    child: ListView(
      key: PageStorageKey('${widget.path}${widget.query}'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: widget.padding,
      children: [
        ?widget.header,
        if (loading && rows.isEmpty)
          const LoadingRows()
        else if (error != null && rows.isEmpty)
          ErrorPanel(error!, () => load())
        else ...[
          if (loading) const AppProgress(minHeight: 2),
          if (rows.isEmpty)
            StatePanel(title: widget.emptyTitle, message: widget.emptyMessage),
          if (isApple(context))
            // Each row remains a separate sliver child. A single Column here
            // would eagerly lay out every page and load offscreen avatars.
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  i == 0 ? 8 : 0,
                  16,
                  i == rows.length - 1 ? 8 : 0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: i == 0 ? const Radius.circular(12) : Radius.zero,
                    bottom: i == rows.length - 1
                        ? const Radius.circular(12)
                        : Radius.zero,
                  ),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    child: widget.itemBuilder(rows[i]),
                  ),
                ),
              )
          else
            ...rows.map(widget.itemBuilder),
          if (error != null) ErrorPanel(error!, () => load(append: lastAppend)),
          if (error == null && rows.length < total)
            Padding(
              padding: const EdgeInsets.all(24),
              child: AppOutlinedButton(
                onPressed: more ? null : () => load(append: true),
                child: Text(more ? '正在加载…' : '继续加载 · ${rows.length} / $total'),
              ),
            ),
          if (rows.isNotEmpty && rows.length >= total)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                '已显示全部内容',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
        SizedBox(height: isApple(context) ? 16 : 90),
      ],
    ),
  );
}
