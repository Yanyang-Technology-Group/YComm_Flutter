import '../../core/design/adaptive.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import '../downloads/resource_page.dart';
import 'admin_access.dart';
import 'admin_widgets.dart';

class AdminResourcesPage extends StatefulWidget {
  const AdminResourcesPage({super.key});
  @override
  State<AdminResourcesPage> createState() => _AdminResourcesPageState();
}

class _AdminResourcesPageState extends State<AdminResourcesPage> {
  String status = '';
  @override
  Widget build(BuildContext context) => AdminPage(
    title: '资源管理',
    child: AdminCollection(
      path: '/admin/resources',
      listKey: 'resources',
      query: {if (status.isNotEmpty) 'status': status},
      header: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in {
              '': '全部',
              'pending': '待审核',
              'published': '已发布',
              'withdrawn': '已撤回',
              'rejected': '已驳回',
            }.entries)
              AppChoiceChip(
                label: Text(entry.value),
                selected: status == entry.key,
                onSelected: (_) => setState(() => status = entry.key),
              ),
          ],
        ),
      ),
      itemBuilder: (c, row, refresh) => AdminTile(
        title: str(row['title']),
        markdownTitle: true,
        subtitle:
            '${str(row['versionLabel'], '未标注版本')} · ${row['downloadCount'] ?? 0} 次下载',
        status: adminStatus(row['status']),
        icon: Icons.inventory_2_outlined,
        onTap: () async {
          await openPage<bool>(c, _AdminResourceDetail(resource: row));
          if (c.mounted) await refresh();
        },
      ),
    ),
  );
}

class _AdminResourceDetail extends ConsumerStatefulWidget {
  const _AdminResourceDetail({required this.resource});
  final Json resource;
  @override
  ConsumerState<_AdminResourceDetail> createState() =>
      _AdminResourceDetailState();
}

class _AdminResourceDetailState extends ConsumerState<_AdminResourceDetail> {
  late Json resource = Json.from(widget.resource);
  @override
  Widget build(BuildContext context) {
    final access = AdminAccess(ref.watch(sessionProvider).value);
    return AdminPage(
      title: '资源详情',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          MarkdownText(
            str(resource['title']),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SmallTag(adminStatus(resource['status'])),
              SmallTag(str(resource['sourceType'])),
            ],
          ),
          const SizedBox(height: 24),
          AppSelectableText(
            '资源 ID：${resource['id']}\n作者 ID：${str(resource['authorId'])}\n版本：${str(resource['versionLabel'], '未提供')}\n下载次数：${resource['downloadCount'] ?? 0}\n创建时间：${str(resource['createdAt'])}',
          ),
          const SizedBox(height: 24),
          AppOutlinedButton.icon(
            onPressed: () => openPage(
              context,
              ResourcePage(
                id: str(resource['id']),
                onChanged: () {
                  if (mounted) {
                    setState(
                      () => resource = {...resource, 'status': 'withdrawn'},
                    );
                  }
                },
              ),
            ),
            icon: const AppIcon(Icons.open_in_new),
            label: const Text('查看资源页面'),
          ),
          if (access.canWithdraw(resource['authorId']) &&
              !['withdrawn', 'deleted'].contains(resource['status'])) ...[
            const SizedBox(height: 16),
            AppOutlinedButton.icon(
              icon: const AppIcon(Icons.remove_circle_outline),
              label: const Text('撤回资源'),
              onPressed: () async {
                final api = ref.read(communityProvider);
                final done = await confirmAdminAction(
                  context,
                  title: '撤回资源？',
                  message: '“${str(resource['title'])}”撤回后将不再公开提供下载。',
                  confirmLabel: '确认撤回',
                  onConfirm: () async {
                    if (access.identity !=
                        AdminAccess(ref.read(sessionProvider).value).identity) {
                      throw const RequestFailure('账号已变更');
                    }
                    await api.post(
                      '/downloads/resources/${adminId(resource['id'])}/withdraw',
                    );
                  },
                );
                if (done && context.mounted) {
                  notice(context, '资源已撤回');
                  Navigator.pop(context, true);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});
  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  String action = '';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: '审计记录',
    child: AdminCollection(
      path: '/admin/audit',
      listKey: 'entries',
      query: {if (action.isNotEmpty) 'action': action},
      header: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: AppTextField(
          controller: search,
          decoration: InputDecoration(
            labelText: '按操作前缀筛选',
            hintText: '输入操作名称前缀',
            prefixIcon: const AppIcon(Icons.search),
            suffixIcon: AppIconButton(
              tooltip: '筛选',
              icon: const AppIcon(Icons.arrow_forward),
              onPressed: () => setState(() => action = search.text.trim()),
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => setState(() => action = v.trim()),
        ),
      ),
      itemBuilder: (c, row, refresh) {
        final actor = row['actor'] is Map
            ? Json.from(row['actor'])
            : <String, dynamic>{};
        final name = str(
          row['actorDisplayName'] ??
              row['actorUsername'] ??
              actor['displayName'] ??
              actor['username'],
          str(row['actorId'] ?? row['actor_id'], '系统'),
        );
        return AdminTile(
          title: str(row['action'], '操作记录'),
          subtitle:
              '$name · ${dateLabel(row['createdAt'] ?? row['created_at'])}',
          icon: Icons.history_rounded,
          onTap: () => openPage(
            c,
            AdminPage(
              title: '审计详情',
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    str(row['action']),
                    style: Theme.of(c).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  AppSelectableText(prettyJson(row)),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const AdminPage(title: '站点设置', child: _SettingsBody());
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody();
  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late Future<Json> future;
  @override
  void initState() {
    super.initState();
    future = fetch();
  }

  Future<Json> fetch() => ref.read(communityProvider).get('/admin/settings');
  Future<void> reload() async {
    setState(() {
      future = fetch();
    });
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: future,
    builder: (c, s) {
      if (s.connectionState != ConnectionState.done) {
        return const SingleChildScrollView(child: LoadingRows());
      }
      if (s.hasError) return ListView(children: [ErrorPanel(s.error!, reload)]);
      final raw = s.data?['settings'];
      final rows = raw is Map
          ? raw.entries
                .map(
                  (e) => <String, dynamic>{'key': str(e.key), 'value': e.value},
                )
                .toList()
          : jsonList(raw);
      return AppRefresh(
        onRefresh: reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 20),
              child: Text('修改已有设置后立即生效，可编辑范围由站点配置决定。'),
            ),
            if (rows.isEmpty) const StatePanel(title: '暂无运行时设置'),
            for (final row in rows)
              AdminTile(
                title: str(row['key']),
                subtitle: prettyJson(row['value']),
                icon: Icons.tune_rounded,
                onTap: row.containsKey('value') && str(row['key']).isNotEmpty
                    ? () async {
                        final changed = await openPage<bool>(
                          context,
                          _SettingEditor(setting: row),
                        );
                        if (changed == true && mounted) await reload();
                      }
                    : null,
              ),
          ],
        ),
      );
    },
  );
}

class _SettingEditor extends ConsumerStatefulWidget {
  const _SettingEditor({required this.setting});
  final Json setting;
  @override
  ConsumerState<_SettingEditor> createState() => _SettingEditorState();
}

class _SettingEditorState extends ConsumerState<_SettingEditor> {
  late final TextEditingController input;
  late final String identity;
  bool boolValue = false, busy = false, dirty = false, exiting = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    final value = widget.setting['value'];
    boolValue = value == true;
    input = TextEditingController(
      text: value is String
          ? value
          : const JsonEncoder.withIndent('  ').convert(value),
    );
    identity = AdminAccess(ref.read(sessionProvider).value).identity;
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy ||
        identity != AdminAccess(ref.read(sessionProvider).value).identity) {
      return;
    }
    final old = widget.setting['value'];
    dynamic value;
    try {
      value = old is bool
          ? boolValue
          : old is String
          ? input.text
          : jsonDecode(input.text);
      if (old is num && value is! num) throw const FormatException('请输入有效数字');
      if (old is Map && value is! Map) {
        throw const FormatException('请保留 JSON 对象格式');
      }
      if (old is List && value is! List) {
        throw const FormatException('请保留 JSON 数组格式');
      }
    } catch (_) {
      setState(() => error = '设置值格式不正确，请检查后重试');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(communityProvider).patch('/admin/settings', {
        'key': widget.setting['key'],
        'value': value,
      });
      if (mounted) {
        setState(() {
          busy = false;
          exiting = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> back() async {
    if (busy) return;
    final discard = await appShowDialog<bool>(
      context: context,
      builder: (c) => AppAlertDialog(
        title: const Text('放弃未保存的设置？'),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('继续编辑'),
          ),
          AppTextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => exiting = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, false);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: exiting || (!dirty && !busy),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) back();
    },
    child: AdminPage(
      title: '编辑设置',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            str(widget.setting['key']),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          if (widget.setting['value'] is bool)
            AppSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用'),
              value: boolValue,
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      boolValue = v;
                      dirty = true;
                    }),
            )
          else
            AppTextField(
              controller: input,
              enabled: !busy,
              minLines: widget.setting['value'] is num ? 1 : 4,
              maxLines: 12,
              onChanged: (_) => setState(() => dirty = true),
              decoration: InputDecoration(
                labelText: widget.setting['value'] is String
                    ? '设置内容'
                    : widget.setting['value'] is num
                    ? '数值'
                    : 'JSON 内容',
                alignLabelWithHint: true,
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          AppFilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? '正在保存…' : '保存'),
          ),
        ],
      ),
    ),
  );
}
