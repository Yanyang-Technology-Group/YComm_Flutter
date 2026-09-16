import 'package:flutter/material.dart';

import '../../core/widgets/design.dart';
import 'admin_widgets.dart';
import 'moderation_page.dart';
import 'admin_users_page.dart';
import 'admin_catalog_pages.dart';
import 'admin_system_pages.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});
  @override
  Widget build(BuildContext context) => AdminPage(
    title: '管理中心',
    maxWidth: 1080,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 4,
          ),
          leading: Icon(
            Icons.fact_check_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text('内容审核', style: Theme.of(context).textTheme.titleLarge),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openPage(context, const ModerationPage()),
        ),
        const Divider(),
        const SizedBox(height: 28),
        _Section(
          title: '日常管理',
          entries: [
            _Entry(
              '用户管理',
              '搜索账号、禁言与封禁',
              Icons.people_outline_rounded,
              const AdminUsersPage(),
            ),
            _Entry(
              '资源管理',
              '审核状态与资源撤回',
              Icons.inventory_2_outlined,
              const AdminResourcesPage(),
            ),
            _Entry(
              '审计记录',
              '查看操作记录',
              Icons.history_rounded,
              const AdminAuditPage(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Section(
          title: '内容与社区',
          entries: [
            _Entry(
              '论坛版块',
              '版块设置、归档与恢复',
              Icons.forum_outlined,
              const AdminBoardsPage(),
            ),
            _Entry(
              '下载卡片',
              '目录层级、排序与审核',
              Icons.dashboard_outlined,
              const AdminCardsPage(),
            ),
            _Entry(
              '社区徽章',
              '创建与管理徽章',
              Icons.workspace_premium_outlined,
              const AdminBadgesPage(),
            ),
            _Entry(
              '邀请码',
              '创建邀请与查看使用记录',
              Icons.confirmation_number_outlined,
              const AdminInvitesPage(),
            ),
            _Entry(
              '站点设置',
              '调整运行时配置',
              Icons.tune_rounded,
              const AdminSettingsPage(),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Entry {
  const _Entry(this.title, this.subtitle, this.icon, this.page);
  final String title, subtitle;
  final IconData icon;
  final Widget page;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.entries});
  final String title;
  final List<_Entry> entries;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 2 : 1;
          return Wrap(
            spacing: 24,
            runSpacing: 4,
            children: [
              for (final e in entries)
                SizedBox(
                  width: (constraints.maxWidth - (columns - 1) * 24) / columns,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    leading: Icon(
                      e.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      e.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => openPage(context, e.page),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
