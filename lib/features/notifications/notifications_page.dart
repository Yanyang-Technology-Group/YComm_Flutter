import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/auth_gate.dart';
import '../forum/topic_page.dart';
import '../downloads/resource_page.dart';
import '../downloads/card_directory.dart';
import '../profile/user_page.dart';

class NotificationController extends AsyncNotifier<List<Json>> {
  int _generation = 0;
  @override
  Future<List<Json>> build() async {
    final user = ref.watch(sessionProvider).value;
    if (user == null) return [];
    return ref.read(communityProvider).notifications();
  }

  Future<void> refresh() async {
    if (ref.read(sessionProvider).value == null) {
      state = const AsyncData([]);
      return;
    }
    final userId = ref.read(sessionProvider).value?['id'];
    final ticket = ++_generation;
    final next = await AsyncValue.guard(
      () => ref.read(communityProvider).notifications(),
    );
    if (ref.mounted &&
        ticket == _generation &&
        userId == ref.read(sessionProvider).value?['id']) {
      state = next;
    }
  }

  Future<void> read(List<String> keys) async {
    await ref.read(communityProvider).post('/notifications/read', {
      'keys': keys,
    });
    await refresh();
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationController, List<Json>>(
      NotificationController.new,
    );

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool unreadOnly = false, marking = false;
  Future<void> mark(List<String> keys) async {
    if (marking) return;
    setState(() => marking = true);
    try {
      await ref.read(notificationsProvider.notifier).read(keys);
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => marking = false);
    }
  }

  Future<void> visit(Json n) async {
    await mark([str(n['key'])]);
    if (!mounted) return;
    final link = str(n['linkUrl']);
    if (link.isEmpty) {
      await appShowDialog<void>(
        context: context,
        builder: (c) => AppAlertDialog(
          title: MarkdownText(str(n['title'])),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: MarkdownContent(str(n['body'])),
            ),
          ),
          actions: [
            AppTextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    final uri = Uri.parse(siteOrigin).resolve(link);
    final segments = uri.pathSegments;
    if (uri.origin == siteOrigin &&
        segments.length == 3 &&
        segments[0] == 'forum') {
      await openPage(context, TopicPage(id: segments[2]));
    } else if (uri.origin == siteOrigin &&
        segments.length == 3 &&
        segments[0] == 'downloads' &&
        segments[1] == 'card') {
      await openPage(context, CardDirectoryPage(id: segments[2]));
    } else if (uri.origin == siteOrigin &&
        segments.length == 2 &&
        segments[0] == 'downloads') {
      await openPage(context, ResourcePage(id: segments[1]));
    } else if (uri.origin == siteOrigin &&
        segments.length == 2 &&
        segments[0] == 'u') {
      await openPage(context, UserPage(username: segments[1]));
    } else {
      await externalLink(context, uri.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final feed = ref.watch(notificationsProvider);
    final unread = (feed.value ?? []).fold<int>(
      0,
      (sum, n) => sum + ((n['unreadCount'] as num?)?.toInt() ?? 0),
    );
    return SafeArea(
      bottom: false,
      child: PageWidth(
        child: AppRefresh(
          onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              PageIntro(
                '消息',
                action: session.value == null
                    ? null
                    : AppIconButton(
                        tooltip: '全部标记为已读',
                        onPressed: marking || unread == 0
                            ? null
                            : () => mark(['*']),
                        icon: const AppIcon(Icons.done_all_rounded),
                      ),
              ),
              if (session.value == null)
                StatePanel(
                  title: '登录后查看消息',
                  icon: Icons.mark_chat_unread_outlined,
                  action: AppFilledButton(
                    onPressed: () => requireSession(context, ref),
                    child: const Text('登录查看'),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: isApple(context)
                      ? SizedBox(
                          width: double.infinity,
                          child: AppSegmentedButton<bool>(
                            segments: [
                              const ButtonSegment(
                                value: false,
                                label: Text('全部消息'),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(
                                  '未读${unread > 0 ? ' · $unread' : ''}',
                                ),
                              ),
                            ],
                            selected: {unreadOnly},
                            onSelectionChanged: (value) =>
                                setState(() => unreadOnly = value.first),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          children: [
                            AppChoiceChip(
                              label: const Text('全部消息'),
                              selected: !unreadOnly,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => unreadOnly = false),
                            ),
                            AppChoiceChip(
                              label: Text(
                                '未读${unread > 0 ? ' · $unread' : ''}',
                              ),
                              selected: unreadOnly,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => unreadOnly = true),
                            ),
                          ],
                        ),
                ),
                feed.when(
                  loading: () => const LoadingRows(),
                  error: (e, s) => ErrorPanel(
                    e,
                    () => ref.read(notificationsProvider.notifier).refresh(),
                  ),
                  data: (items) {
                    final list = items
                        .where(
                          (e) =>
                              !unreadOnly ||
                              (e['unreadCount'] as num? ?? 0) > 0,
                        )
                        .toList();
                    if (list.isEmpty) {
                      return StatePanel(
                        title: unreadOnly ? '暂无未读消息' : '暂无消息',
                        icon: Icons.done_all_rounded,
                      );
                    }
                    return Column(
                      children: list.map((n) {
                        final fresh = (n['unreadCount'] as num? ?? 0) > 0;
                        final actor = jsonList(n['actors']).firstOrNull;
                        return AppSurface(
                          color: fresh
                              ? Theme.of(context).colorScheme.primaryContainer
                                    .withValues(alpha: .22)
                              : Colors.transparent,
                          child: AppTap(
                            onTap: marking ? null : () => visit(n),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppBadge(
                                    isLabelVisible: fresh,
                                    child: UserAvatar(
                                      actor == null
                                          ? '晏'
                                          : str(
                                              actor['displayName'],
                                              str(actor['username']),
                                            ),
                                      username: actor?['username'] as String?,
                                      size: 42,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        MarkdownText(
                                          str(n['title']),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        if (str(n['body']).isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          MarkdownText(
                                            str(n['body']),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          dateLabel(n['latestAt']),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
