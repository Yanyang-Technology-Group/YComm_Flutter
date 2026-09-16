import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/design.dart';
import '../auth/auth_gate.dart';
import '../forum/forum_page.dart';
import '../forum/topic_page.dart';
import '../downloads/resource_tile.dart';
import '../downloads/resource_page.dart';
import 'about_page.dart';
import 'appearance_page.dart';
import 'user_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider),
        theme = ref.watch(themeControllerProvider);
    final user = session.value;
    return SafeArea(
      bottom: false,
      child: PageWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const PageIntro('我的'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PersonAvatar(
                            user == null
                                ? '晏'
                                : str(
                                    user['displayName'],
                                    str(user['username']),
                                  ),
                            size: 64,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user == null
                                      ? '未登录'
                                      : str(
                                          user['displayName'],
                                          str(user['username']),
                                        ),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                if (user != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '@${user['username']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => user == null
                              ? requireSession(context, ref)
                              : openPage(
                                  context,
                                  UserPage(username: str(user['username'])),
                                ),
                          icon: Icon(
                            user == null
                                ? Icons.login_rounded
                                : Icons.person_outline_rounded,
                            size: 19,
                          ),
                          label: Text(user == null ? '登录 / 注册' : '查看个人主页'),
                        ),
                      ),
                      if (session.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (session.hasError)
                        TextButton.icon(
                          onPressed: () =>
                              ref.read(sessionProvider.notifier).refresh(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('登录状态加载失败，重试'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            const _SectionLabel('我的内容'),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '我的讨论',
                  onTap: () async {
                    if (await requireSession(context, ref) && context.mounted) {
                      openPage(context, const MyContentPage(resources: false));
                    }
                  },
                ),
                SettingsRow(
                  icon: Icons.inventory_2_outlined,
                  title: '我的资源',
                  onTap: () async {
                    if (await requireSession(context, ref) && context.mounted) {
                      openPage(context, const MyContentPage(resources: true));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 26),
            const _SectionLabel('偏好与帮助'),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.palette_outlined,
                  title: '外观与主题',
                  subtitle:
                      '${theme.colour.label} · ${switch (theme.mode.id) {
                        'dark' => '深色模式',
                        'light' => '浅色模式',
                        _ => '跟随系统',
                      }}',
                  onTap: () => openPage(context, const AppearancePage()),
                ),
                SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: '关于晏阳',
                  onTap: () => openPage(context, const AboutPage()),
                ),
              ],
            ),
            if (user != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: OutlinedButton(
                  onPressed: () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('退出当前账号？'),
                        content: const Text('退出后仍然可以浏览公开讨论与资源。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('退出登录'),
                          ),
                        ],
                      ),
                    );
                    if (yes != true) return;
                    try {
                      await ref.read(sessionProvider.notifier).logout();
                      if (context.mounted) notice(context, '已退出登录');
                    } catch (e) {
                      if (context.mounted) notice(context, e);
                    }
                  },
                  child: const Text('退出登录'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 70, right: 20),
                child: Divider(),
              ),
          ],
        ],
      ),
    ),
  );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    subtitle: subtitle == null
        ? null
        : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
    trailing: const Icon(Icons.chevron_right_rounded, size: 21),
    onTap: onTap,
  );
}

class MyContentPage extends ConsumerStatefulWidget {
  const MyContentPage({super.key, required this.resources});
  final bool resources;
  @override
  ConsumerState<MyContentPage> createState() => _MyContentPageState();
}

class _MyContentPageState extends ConsumerState<MyContentPage> {
  late Future<Json> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => future = ref
      .read(communityProvider)
      .get('/auth/me/${widget.resources ? 'resources' : 'topics'}');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.resources ? '我的资源' : '我的讨论')),
    body: SafeArea(
      child: PageWidth(
        child: FutureBuilder<Json>(
          future: future,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) {
              return const LoadingRows();
            }
            if (s.hasError) {
              return ListView(
                children: [ErrorPanel(s.error!, () => setState(reload))],
              );
            }
            final list = jsonList(
              s.data![widget.resources ? 'resources' : 'topics'],
            );
            return RefreshIndicator(
              onRefresh: () async {
                setState(reload);
                await future;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: list.isEmpty
                    ? [
                        StatePanel(
                          title: widget.resources ? '暂无资源' : '暂无讨论',
                        ),
                      ]
                    : list
                          .map(
                            (item) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item['status'] != 'published')
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      8,
                                      24,
                                      8,
                                    ),
                                    child: SmallTag(
                                      item['status'] == 'pending'
                                          ? '待审核'
                                          : str(item['status']),
                                    ),
                                  ),
                                widget.resources
                                    ? ResourceTile(
                                        item,
                                        onTap: () => openPage(
                                          context,
                                          ResourcePage(id: str(item['id'])),
                                        ),
                                      )
                                    : TopicTile(
                                        item,
                                        onTap: () => openPage(
                                          context,
                                          TopicPage(id: str(item['id'])),
                                        ),
                                      ),
                              ],
                            ),
                          )
                          .toList(),
              ),
            );
          },
        ),
      ),
    ),
  );
}
