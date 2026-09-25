import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/apple_chrome.dart';
import '../../core/design/tokens.dart';
import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/auth_gate.dart';
import '../forum/forum_page.dart';
import '../forum/topic_page.dart';
import '../downloads/resource_tile.dart';
import '../downloads/resource_page.dart';
import '../admin/admin_access.dart';
import '../admin/admin_page.dart';
import '../forum/my_posts_page.dart';
import 'settings_page.dart';
import 'user_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.value;
    final apple = appleTokensOf(context) != null;
    return SafeArea(
      bottom: false,
      child: PageWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const PageIntro('我的'),
            if (apple)
              SettingsGroup(
                children: [
                  AppleDisclosureRow(
                    key: const ValueKey('apple-account-row'),
                    leading: UserAvatar(
                      user == null
                          ? '晏'
                          : str(user['displayName'], str(user['username'])),
                      size: 56,
                      path: user?['avatarPath'] as String?,
                      username: user?['username'] as String?,
                    ),
                    title: Text(
                      user == null
                          ? '登录 / 注册'
                          : str(user['displayName'], str(user['username'])),
                    ),
                    detail: user == null ? null : Text('@${user['username']}'),
                    subtitle: Text(user == null ? '登录后参与讨论与分享' : '查看个人主页'),
                    onTap: () => user == null
                        ? requireSession(context, ref)
                        : openPage(
                            context,
                            UserPage(username: str(user['username'])),
                          ),
                  ),
                  if (session.isLoading) const AppProgress(minHeight: 2),
                  if (session.hasError)
                    AppListTile(
                      title: const Text('登录状态加载失败，重试'),
                      onTap: () => ref.read(sessionProvider.notifier).refresh(),
                    ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppSurface(
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
                            UserAvatar(
                              user == null
                                  ? '晏'
                                  : str(
                                      user['displayName'],
                                      str(user['username']),
                                    ),
                              size: 64,
                              path: user?['avatarPath'] as String?,
                              username: user?['username'] as String?,
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
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
                          child: AppFilledButton.icon(
                            onPressed: () => user == null
                                ? requireSession(context, ref)
                                : openPage(
                                    context,
                                    UserPage(username: str(user['username'])),
                                  ),
                            icon: AppIcon(
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
                            child: AppProgress(minHeight: 2),
                          ),
                        if (session.hasError)
                          AppTextButton.icon(
                            onPressed: () =>
                                ref.read(sessionProvider.notifier).refresh(),
                            icon: const AppIcon(Icons.refresh, size: 18),
                            label: const Text('登录状态加载失败，重试'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            SizedBox(height: apple ? 24 : 26),
            const SectionLabel('我的内容'),
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
                  icon: Icons.reply_all_rounded,
                  title: '我的回复',
                  onTap: () async {
                    if (await requireSession(context, ref) && context.mounted) {
                      openPage(context, const MyPostsPage());
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
            if (AdminAccess(user).isStaff) ...[
              SizedBox(height: apple ? 24 : 26),
              const SectionLabel('社区管理'),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.admin_panel_settings_outlined,
                    title: '管理中心',
                    subtitle: '内容审核与社区管理',
                    onTap: () => openPage(context, const AdminDashboardPage()),
                  ),
                ],
              ),
            ],
            SizedBox(height: apple ? 24 : 26),
            const SectionLabel('偏好与帮助'),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.settings_outlined,
                  title: '设置',
                  subtitle: '外观、开发者工具与关于',
                  onTap: () => openPage(context, const SettingsPage()),
                ),
              ],
            ),
            if (user != null)
              if (apple) ...[
                const SizedBox(height: 32),
                SettingsGroup(
                  children: [
                    AppListTile(
                      onTap: () => _logout(context, ref),
                      title: Text(
                        '退出登录',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppOutlinedButton(
                    onPressed: () => _logout(context, ref),
                    child: const Text('退出登录'),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final yes = await appShowDialog<bool>(
      context: context,
      builder: (c) => AppAlertDialog(
        title: const Text('退出当前账号？'),
        content: const Text('退出后仍然可以浏览公开讨论与资源。'),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          AppTextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
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
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    // Apple 风格：分组是一张圆角卡片，行之间是内缩发丝线（线从图标之后起笔）。
    // 这是 iOS 系统设置最典型的一组视觉信号。
    if (appleTokensOf(context) != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppleSpacing.gutter),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppleRadius.card),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1) const AppleSeparator(inset: 57),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AppSurface(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 70, right: 20),
                  child: AppDivider(),
                ),
            ],
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    if (appleTokensOf(context) != null) {
      final scheme = Theme.of(context).colorScheme;
      final tokens = appleTokensOf(context)!;
      return PressableScale(
        onTap: onTap,
        pressedScale: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppleSpacing.row,
            vertical: 8,
          ),
          child: Row(
            children: [
              // iOS 设置行是「图标 + 标题」一行，副标题换行到下方。
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: AppIcon(icon, size: 19, color: scheme.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppleType.body.copyWith(
                        color: scheme.onSurface,
                        fontFamilyFallback: appleFontFallback,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: AppleType.footnote.copyWith(
                          color: tokens.secondaryLabel,
                          fontFamilyFallback: appleFontFallback,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // iOS 的详情指示是**细**的灰色 chevron，不是粗描边图标。
              AppIcon(
                Icons.chevron_right_rounded,
                size: 15,
                color: tokens.tertiaryLabel,
              ),
            ],
          ),
        ),
      );
    }
    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: AppIcon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      trailing: const AppIcon(Icons.chevron_right_rounded, size: 21),
      onTap: onTap,
    );
  }
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
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppNavigationBar(title: Text(widget.resources ? '我的资源' : '我的讨论')),
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
            return AppRefresh(
              onRefresh: () async {
                setState(reload);
                await future;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: list.isEmpty
                    ? [StatePanel(title: widget.resources ? '暂无资源' : '暂无讨论')]
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
                                        onTap: () async {
                                          await openPage(
                                            context,
                                            ResourcePage(id: str(item['id'])),
                                          );
                                          if (mounted) setState(reload);
                                        },
                                      )
                                    : TopicTile(
                                        item,
                                        onTap: () async {
                                          await openPage(
                                            context,
                                            TopicPage(id: str(item['id'])),
                                          );
                                          if (mounted) setState(reload);
                                        },
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
