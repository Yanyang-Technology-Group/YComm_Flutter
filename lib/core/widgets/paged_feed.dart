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
    this.appleTitle,
    this.appleTrailing,
    this.appleBottom,
    this.appleAutomaticallyImplyLeading = true,
    this.refreshRevision = 0,
  });
  final String path, listKey, emptyTitle, emptyMessage;
  final Json query;
  final Widget Function(Json) itemBuilder;
  final Widget? header;
  final EdgeInsets padding;
  final String? appleTitle;
  final Widget? appleTrailing;
  final PreferredSizeWidget? appleBottom;
  final int refreshRevision;
  final bool appleAutomaticallyImplyLeading;
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

  @override
  void didUpdateWidget(covariant PagedFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision) load();
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
              'limit': !append && rows.length > 20 ? rows.length : 20,
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
  Widget build(BuildContext context) {
    if (isApple(context)) return _appleFeed(context);
    return AppRefresh(
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
              StatePanel(
                title: widget.emptyTitle,
                message: widget.emptyMessage,
              ),
            ...rows.map(widget.itemBuilder),
            if (error != null)
              ErrorPanel(error!, () => load(append: lastAppend)),
            if (error == null && rows.length < total)
              Padding(
                padding: const EdgeInsets.all(24),
                child: AppOutlinedButton(
                  onPressed: more ? null : () => load(append: true),
                  child: Text(
                    more ? '正在加载…' : '继续加载 · ${rows.length} / $total',
                  ),
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
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _appleFeed(BuildContext context) {
    final slivers = <Widget>[
      if (widget.header != null) SliverToBoxAdapter(child: widget.header),
      if (loading && rows.isEmpty)
        const SliverToBoxAdapter(child: LoadingRows())
      else if (error != null && rows.isEmpty)
        SliverToBoxAdapter(child: ErrorPanel(error!, () => load()))
      else ...[
        if (loading) const SliverToBoxAdapter(child: AppProgress(minHeight: 2)),
        if (rows.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: StatePanel(
              title: widget.emptyTitle,
              message: widget.emptyMessage,
            ),
          )
        else
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) => widget.itemBuilder(rows[index]),
          ),
        if (error != null)
          SliverToBoxAdapter(
            child: ErrorPanel(error!, () => load(append: lastAppend)),
          ),
        if (error == null && rows.length < total)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: more
                    ? const AppSpinner()
                    : AppTextButton(
                        onPressed: () => load(append: true),
                        child: Text('继续加载 · ${rows.length} / $total'),
                      ),
              ),
            ),
          ),
        if (rows.isNotEmpty && rows.length >= total)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '已显示全部内容',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    ];
    if (widget.appleTitle != null) {
      return AppleScrollPage(
        key: PageStorageKey('${widget.path}${widget.query}'),
        title: widget.appleTitle!,
        trailing: widget.appleTrailing,
        bottom: widget.appleBottom,
        automaticallyImplyLeading: widget.appleAutomaticallyImplyLeading,
        onRefresh: () => load(),
        slivers: slivers,
      );
    }
    return AppRefresh(
      onRefresh: () => load(),
      child: CustomScrollView(
        key: PageStorageKey('${widget.path}${widget.query}'),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: widget.padding,
            sliver: SliverMainAxisGroup(slivers: slivers),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }
}
