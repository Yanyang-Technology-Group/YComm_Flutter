import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/widgets/design.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/auth_gate.dart';

class UserPage extends ConsumerStatefulWidget {
  const UserPage({super.key, required this.username});
  final String username;
  @override
  ConsumerState<UserPage> createState() => _UserPageState();
}

class _UserPageState extends ConsumerState<UserPage> {
  late Future<Json> future;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => future = ref
      .read(communityProvider)
      .get('/users/${Uri.encodeComponent(widget.username)}');
  @override
  Widget build(BuildContext context) {
    final apple = isApple(context);
    Widget content({
      required List<Widget> children,
      EdgeInsetsGeometry? padding,
    }) {
      if (apple) {
        return AppleScrollPage(
          title: '个人主页',
          largeTitle: false,
          trailing: null,
          slivers: [
            SliverPadding(
              padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
              sliver: SliverList.list(children: children),
            ),
          ],
        );
      }
      return ListView(padding: padding, children: children);
    }

    final body = FutureBuilder<Json>(
      future: future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return content(children: [const LoadingRows()]);
        }
        if (s.hasError) {
          return content(
            children: [ErrorPanel(s.error!, () => setState(reload))],
          );
        }
        final user = Json.from(s.data!['profile']);
        final name = str(user['displayName'], str(user['username']));
        return content(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: UserAvatar(
                name,
                size: 80,
                path: user['avatarPath'] as String?,
              ),
            ),
            const SizedBox(height: 20),
            Text(name, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text(
              '@${user['username']}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            if (str(user['bio']).isNotEmpty)
              Text(
                str(user['bio']),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            const SizedBox(height: 20),
            if (isApple(context))
              Row(
                children: [
                  for (final stat in <(String, String)>[
                    ('${user['postCount'] ?? 0}', '帖子'),
                    ('${user['likeReceivedCount'] ?? 0}', '获赞'),
                    ('${user['followerCount'] ?? 0}', '粉丝'),
                  ])
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.$1,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stat.$2,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SmallTag('${user['postCount'] ?? 0} 帖子'),
                  SmallTag('${user['likeReceivedCount'] ?? 0} 获赞'),
                  SmallTag('${user['followerCount'] ?? 0} 粉丝'),
                ],
              ),
            const SizedBox(height: 24),
            if (user['isSelf'] != true)
              AppFilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        if (!await requireSession(context, ref) || !mounted) {
                          return;
                        }
                        setState(() => busy = true);
                        try {
                          await ref
                              .read(communityProvider)
                              .post(
                                '/users/${Uri.encodeComponent(widget.username)}/${user['viewerFollowsTarget'] == true ? 'unfollow' : 'follow'}',
                              );
                          if (mounted) setState(reload);
                        } catch (e) {
                          if (context.mounted) notice(context, e);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                icon: AppIcon(
                  user['viewerFollowsTarget'] == true
                      ? Icons.check_rounded
                      : Icons.person_add_alt_rounded,
                ),
                label: Text(
                  busy
                      ? '处理中…'
                      : user['viewerFollowsTarget'] == true
                      ? '已关注 · 取消关注'
                      : '关注',
                ),
              ),
            const SizedBox(height: 28),
            const AppDivider(),
            const SizedBox(height: 28),
            Text('个人介绍', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            MarkdownContent(
              str(user['homepageMd']).isEmpty
                  ? '这位朋友还没有留下更多介绍。'
                  : str(user['homepageMd']),
            ),
          ],
        );
      },
    );
    return AppScaffold(
      appBar: apple ? null : AppNavigationBar(title: const Text('个人主页')),
      body: apple ? body : SafeArea(child: PageWidth(child: body)),
    );
  }
}
