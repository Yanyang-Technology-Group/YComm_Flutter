import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import 'admin_access.dart';
import 'admin_widgets.dart';

const _visibility = {'public': '公开', 'login': '登录可见', 'invite': '受邀可见'};
const _cardVisibility = {..._visibility, 'staff': '管理团队'};

String _date(dynamic value) =>
    str(value).replaceFirst('T', ' ').replaceFirst(RegExp(r'\.\d+Z$|Z$'), '');
bool _archived(Json row) =>
    row['archivedAt'] != null ||
    row['deletedAt'] != null ||
    row['archived'] == true;
String? _httpUrl(String value) {
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  return uri != null &&
          uri.hasAuthority &&
          (uri.scheme == 'http' || uri.scheme == 'https')
      ? null
      : '请输入有效的 http(s) 地址';
}

Json _withoutEmpty(Json data) => {
  for (final entry in data.entries)
    if (entry.value != '') entry.key: entry.value,
};

class AdminBoardsPage extends ConsumerStatefulWidget {
  const AdminBoardsPage({super.key});
  @override
  ConsumerState<AdminBoardsPage> createState() => _AdminBoardsPageState();
}

class _AdminBoardsPageState extends ConsumerState<AdminBoardsPage> {
  final key = GlobalKey<AdminCollectionState>();
  List<AdminField> get createFields => [
    AdminField(
      'slug',
      '标识',
      required: true,
      minLength: 2,
      maxLength: 40,
      hint: '小写字母、数字和连字符',
      validate: (v) =>
          RegExp(r'^[a-z0-9-]+$').hasMatch(v) ? null : '仅可使用小写字母、数字和连字符',
    ),
    const AdminField('name', '名称', required: true, minLength: 2, maxLength: 60),
    const AdminField('description', '说明', maxLength: 500, lines: 4),
    const AdminField('sortOrder', '排序', number: true),
    const AdminField('visibility', '可见范围', options: _visibility),
    const AdminField(
      'postingPolicy',
      '发帖权限',
      options: {'all': '所有用户', 'staff': '管理团队'},
    ),
  ];
  Future<void> create() async {
    final ok = await showAdminForm(
      context,
      title: '新建版块',
      submitLabel: '创建',
      fields: createFields,
      onSubmit: (data) => ref
          .read(communityProvider)
          .post('/admin/boards', _withoutEmpty(data)),
    );
    if (ok) await key.currentState?.refresh();
  }

  Future<void> menu(Json row) async {
    final identity = AdminAccess(ref.read(sessionProvider).value).identity;
    final archived = _archived(row);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            if (!archived)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑版块'),
                onTap: () => Navigator.pop(c, 'edit'),
              ),
            ListTile(
              leading: Icon(archived ? Icons.restore : Icons.archive_outlined),
              title: Text(archived ? '恢复版块' : '归档版块'),
              onTap: () => Navigator.pop(c, archived ? 'restore' : 'archive'),
            ),
          ],
        ),
      ),
    );
    if (!mounted ||
        choice == null ||
        identity != AdminAccess(ref.read(sessionProvider).value).identity) {
      return;
    }
    if (choice == 'edit') {
      final fields = createFields.where((f) => f.key != 'slug').toList();
      final ok = await showAdminForm(
        context,
        title: '编辑版块',
        fields: fields,
        initial: row,
        onSubmit: (data) => ref.read(communityProvider).patch(
          '/admin/boards/${adminId(row['id'])}',
          {..._withoutEmpty(data), 'description': data['description']},
        ),
      );
      if (ok) await key.currentState?.refresh();
      return;
    }
    final restoring = choice == 'restore';
    final ok = await confirmAdminAction(
      context,
      title: restoring ? '恢复版块' : '归档版块',
      message: restoring ? '恢复后用户可再次访问该版块。' : '归档后主题和回复会保留。',
      confirmLabel: restoring ? '恢复' : '归档',
      danger: !restoring,
      onConfirm: () => restoring
          ? ref
                .read(communityProvider)
                .post('/admin/boards/${adminId(row['id'])}/restore')
          : ref
                .read(communityProvider)
                .delete('/admin/boards/${adminId(row['id'])}'),
    );
    if (ok) await key.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: '版块管理',
    child: AdminCollection(
      key: key,
      path: '/admin/boards',
      listKey: 'boards',
      paginated: false,
      header: Align(
        alignment: Alignment.centerRight,
        child: IconButton.filledTonal(
          tooltip: '新建版块',
          onPressed: create,
          icon: const Icon(Icons.add),
        ),
      ),
      itemBuilder: (c, row, refresh) => AdminTile(
        title: str(row['name'], '未命名版块'),
        markdownTitle: true,
        description: str(row['description']),
        subtitle:
            '/${str(row['slug'])} · 排序 ${str(row['sortOrder'], '0')} · ${adminStatus(row['visibility'])} · ${row['postingPolicy'] == 'staff' ? '管理团队发帖' : '所有用户发帖'}',
        status: _archived(row) ? '已归档' : '正常',
        icon: Icons.forum_outlined,
        onTap: () => menu(row),
      ),
    ),
  );
}

class AdminCardsPage extends ConsumerStatefulWidget {
  const AdminCardsPage({super.key});
  @override
  ConsumerState<AdminCardsPage> createState() => _AdminCardsPageState();
}

class _AdminCardsPageState extends ConsumerState<AdminCardsPage> {
  List<Json> cards = [];
  Object? error;
  bool loading = true;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final ticket = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await ref.read(communityProvider).get('/admin/cards');
      if (mounted && ticket == generation) {
        setState(() => cards = jsonList(data['cards']));
      }
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    } finally {
      if (mounted && ticket == generation) setState(() => loading = false);
    }
  }

  Set<String> descendants(String id) {
    final found = <String>{};
    void visit(String parent) {
      for (final c in cards.where((e) => str(e['parentId']) == parent)) {
        final id = str(c['id']);
        if (found.add(id)) visit(id);
      }
    }

    visit(id);
    return found;
  }

  List<AdminField> fields(Json? row) {
    final own = str(row?['id']);
    final forbidden = row == null ? <String>{} : {own, ...descendants(own)};
    final parents = <String, String>{'': '顶层'};
    for (final c in cards) {
      if (!forbidden.contains(str(c['id']))) {
        parents[str(c['id'])] = str(c['title'], '未命名');
      }
    }
    return [
      const AdminField('title', '标题', required: true, maxLength: 80),
      AdminField('parentId', '父级', options: parents, markdownOptions: true),
      const AdminField('subtitle', '副标题', maxLength: 200),
      AdminField('subtitleUrl', '副标题链接', maxLength: 2000, validate: _httpUrl),
      const AdminField(
        'kind',
        '类型',
        options: {'container': '目录', 'redirect': '外部链接', 'resources': '资源列表'},
      ),
      AdminField('redirectUrl', '跳转地址', maxLength: 2000, validate: _httpUrl),
      const AdminField('w', '宽度', number: true, min: 1, max: 6),
      const AdminField('h', '高度', number: true, min: 1, max: 6),
      const AdminField('visibility', '可见范围', options: _cardVisibility),
      const AdminField('position', '位置', number: true),
    ];
  }

  Json normalized(Json data) => {
    ..._withoutEmpty(data),
    'parentId': str(data['parentId']).isEmpty ? null : data['parentId'],
    'subtitle': data['subtitle'],
    'subtitleUrl': str(data['subtitleUrl']).isEmpty
        ? null
        : data['subtitleUrl'],
    'redirectUrl': str(data['redirectUrl']).isEmpty
        ? null
        : data['redirectUrl'],
  };
  Future<void> create() async {
    final ok = await showAdminForm(
      context,
      title: '新建卡片',
      submitLabel: '创建',
      fields: fields(null),
      initial: const {
        'kind': 'container',
        'visibility': 'public',
        'w': 1,
        'h': 1,
      },
      description: '非站长创建的卡片可能需要站长审核。',
      onSubmit: (d) =>
          ref.read(communityProvider).post('/admin/cards', normalized(d)),
    );
    if (ok) await load();
  }

  Future<void> action(Json row) async {
    final access = AdminAccess(ref.read(sessionProvider).value);
    final identity = access.identity;
    final owner = access.isOwner;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: const Text('编辑卡片'),
              leading: const Icon(Icons.edit_outlined),
              onTap: () => Navigator.pop(c, 'edit'),
            ),
            ListTile(
              title: const Text('上移'),
              leading: const Icon(Icons.arrow_upward),
              onTap: () => Navigator.pop(c, 'up'),
            ),
            ListTile(
              title: const Text('下移'),
              leading: const Icon(Icons.arrow_downward),
              onTap: () => Navigator.pop(c, 'down'),
            ),
            if (owner && str(row['status']) == 'pending') ...[
              ListTile(
                title: const Text('通过审核'),
                leading: const Icon(Icons.check_circle_outline),
                onTap: () => Navigator.pop(c, 'approve'),
              ),
              ListTile(
                title: const Text('驳回审核'),
                leading: const Icon(Icons.cancel_outlined),
                onTap: () => Navigator.pop(c, 'reject'),
              ),
            ],
            ListTile(
              title: const Text('删除卡片'),
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(c).colorScheme.error,
              ),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted ||
        choice == null ||
        identity != AdminAccess(ref.read(sessionProvider).value).identity) {
      return;
    }
    if (choice == 'edit') {
      final initial = {...row, 'parentId': row['parentId'] ?? ''};
      final ok = await showAdminForm(
        context,
        title: '编辑卡片',
        fields: fields(row),
        initial: initial,
        onSubmit: (d) => ref
            .read(communityProvider)
            .patch('/admin/cards/${adminId(row['id'])}', normalized(d)),
      );
      if (ok) await load();
      return;
    }
    if (choice == 'up' || choice == 'down') {
      final ok = await confirmAdminAction(
        context,
        title: choice == 'up' ? '上移卡片' : '下移卡片',
        message: '卡片会在当前父级内${choice == 'up' ? '上移' : '下移'}一个位置。',
        confirmLabel: choice == 'up' ? '上移' : '下移',
        danger: false,
        onConfirm: () => ref.read(communityProvider).post(
          '/admin/cards/${adminId(row['id'])}/move',
          {'direction': choice},
        ),
      );
      if (ok) await load();
      return;
    }
    final reviewing = choice == 'approve' || choice == 'reject';
    final ok = await confirmAdminAction(
      context,
      title: reviewing ? (choice == 'approve' ? '通过审核' : '驳回审核') : '删除卡片',
      message: reviewing ? '审核结果会立即影响卡片状态。' : '删除后该卡片将不再显示。',
      confirmLabel: reviewing ? (choice == 'approve' ? '通过' : '驳回') : '删除',
      ownerOnly: reviewing,
      onConfirm: () => reviewing
          ? ref.read(communityProvider).post(
              '/admin/cards/${adminId(row['id'])}/review',
              {'decision': choice},
            )
          : ref
                .read(communityProvider)
                .delete('/admin/cards/${adminId(row['id'])}'),
    );
    if (ok) await load();
  }

  int depth(Json row) {
    int d = 0;
    var parent = str(row['parentId']);
    final seen = <String>{};
    while (parent.isNotEmpty && seen.add(parent)) {
      d++;
      final hit = cards.where((c) => str(c['id']) == parent);
      if (hit.isEmpty) break;
      parent = str(hit.first['parentId']);
    }
    return d;
  }

  List<Json> get treeCards {
    final result = <Json>[];
    final added = <String>{};
    void append(dynamic parent) {
      final children =
          cards.where((row) {
            final value = row['parentId'];
            return parent == null
                ? value == null || str(value).isEmpty
                : str(value) == parent;
          }).toList()..sort(
            (a, b) => (a['position'] as num? ?? 0).compareTo(
              b['position'] as num? ?? 0,
            ),
          );
      for (final child in children) {
        if (!added.add(str(child['id']))) continue;
        result.add(child);
        append(str(child['id']));
      }
    }

    append(null);
    for (final row in cards) {
      if (added.add(str(row['id']))) result.add(row);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: '下载卡片',
    child: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.filledTonal(
              tooltip: '新建卡片',
              onPressed: create,
              icon: const Icon(Icons.add),
            ),
          ),
          if (loading)
            const LoadingRows()
          else if (error != null)
            ErrorPanel(error!, load)
          else if (cards.isEmpty)
            const StatePanel(title: '暂无卡片')
          else
            for (final row in treeCards)
              Padding(
                padding: EdgeInsets.only(left: depth(row) * 18.0),
                child: AdminTile(
                  title: str(row['title'], '未命名卡片'),
                  markdownTitle: true,
                  description: str(row['subtitle']),
                  subtitle:
                      '${adminStatus(row['kind'])} · ${adminStatus(row['visibility'])}',
                  status: adminStatus(row['status']),
                  icon: Icons.dashboard_customize_outlined,
                  onTap: () => action(row),
                ),
              ),
        ],
      ),
    ),
  );
}

class AdminBadgesPage extends ConsumerStatefulWidget {
  const AdminBadgesPage({super.key});
  @override
  ConsumerState<AdminBadgesPage> createState() => _AdminBadgesPageState();
}

class _AdminBadgesPageState extends ConsumerState<AdminBadgesPage> {
  final key = GlobalKey<AdminCollectionState>();
  String? color(String v) =>
      RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v) ? null : '请输入 #RRGGBB 颜色';
  Future<void> create() async {
    final ok = await showAdminForm(
      context,
      title: '新建徽章',
      submitLabel: '创建',
      fields: [
        const AdminField('name', '名称', required: true, maxLength: 20),
        AdminField('colorFrom', '起始颜色', validate: color),
        AdminField('colorTo', '结束颜色', validate: color),
      ],
      onSubmit: (d) =>
          ref.read(communityProvider).post('/admin/badges', _withoutEmpty(d)),
    );
    if (ok) await key.currentState?.refresh();
  }

  Future<void> remove(Json row) async {
    final ok = await confirmAdminAction(
      context,
      title: '删除徽章',
      message: '删除徽章定义，并解除所有用户与该徽章的关联。',
      confirmLabel: '删除',
      typedConfirmation: str(row['name']),
      onConfirm: () => ref
          .read(communityProvider)
          .delete('/admin/badges/${adminId(row['id'])}'),
    );
    if (ok) await key.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: '徽章管理',
    child: AdminCollection(
      key: key,
      path: '/admin/badges',
      listKey: 'badges',
      paginated: false,
      header: Align(
        alignment: Alignment.centerRight,
        child: IconButton.filledTonal(
          tooltip: '新建徽章',
          onPressed: create,
          icon: const Icon(Icons.add),
        ),
      ),
      itemBuilder: (c, row, refresh) => AdminTile(
        title: str(row['name'], '未命名徽章'),
        subtitle:
            '${str(row['colorFrom'], '默认色')} → ${str(row['colorTo'], '默认色')}',
        icon: Icons.workspace_premium_outlined,
        onTap: () => remove(row),
      ),
    ),
  );
}

class AdminInvitesPage extends ConsumerStatefulWidget {
  const AdminInvitesPage({super.key});
  @override
  ConsumerState<AdminInvitesPage> createState() => _AdminInvitesPageState();
}

class _AdminInvitesPageState extends ConsumerState<AdminInvitesPage> {
  final key = GlobalKey<AdminCollectionState>();
  Future<void> create() async {
    final ok = await showAdminForm(
      context,
      title: '新建邀请码',
      submitLabel: '创建',
      fields: const [
        AdminField('name', '名称', required: true, maxLength: 60),
        AdminField('code', '邀请码', maxLength: 10, hint: '留空由服务器生成'),
        AdminField('maxUses', '最大使用次数', number: true, min: 1, max: 1000),
      ],
      onSubmit: (d) {
        final body = {...d};
        if (str(body['code']).isEmpty) body.remove('code');
        if (str(body['maxUses']).isEmpty) body.remove('maxUses');
        return ref.read(communityProvider).post('/admin/invites', body);
      },
    );
    if (ok) await key.currentState?.refresh();
  }

  Future<void> action(Json row) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: const Text('复制邀请码'),
              leading: const Icon(Icons.copy),
              onTap: () => Navigator.pop(c, 'copy'),
            ),
            ListTile(
              title: const Text('使用记录'),
              leading: const Icon(Icons.people_outline),
              onTap: () => Navigator.pop(c, 'uses'),
            ),
            ListTile(
              title: const Text('删除邀请码'),
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(c).colorScheme.error,
              ),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: str(row['code'])));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('邀请码已复制')));
      }
      return;
    }
    if (choice == 'uses') {
      await openPage(context, _InviteUsesPage(invite: row));
      return;
    }
    final ok = await confirmAdminAction(
      context,
      title: '删除邀请码',
      message: '删除后该邀请码无法继续使用。',
      confirmLabel: '删除',
      onConfirm: () => ref
          .read(communityProvider)
          .delete('/admin/invites/${adminId(row['id'])}'),
    );
    if (ok) await key.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: '邀请码',
    child: AdminCollection(
      key: key,
      path: '/admin/invites',
      listKey: 'inviteCodes',
      paginated: false,
      header: Align(
        alignment: Alignment.centerRight,
        child: IconButton.filledTonal(
          tooltip: '新建邀请码',
          onPressed: create,
          icon: const Icon(Icons.add),
        ),
      ),
      itemBuilder: (c, row, refresh) => AdminTile(
        title: str(row['name'], '未命名邀请码'),
        subtitle:
            '${str(row['code'])} · 已使用 ${str(row['usedCount'], '0')} / ${str(row['maxUses'], '不限')}',
        status: row['disabledAt'] != null ? '已停用' : '有效',
        icon: Icons.vpn_key_outlined,
        onTap: () => action(row),
      ),
    ),
  );
}

class _InviteUsesPage extends StatelessWidget {
  const _InviteUsesPage({required this.invite});
  final Json invite;
  @override
  Widget build(BuildContext context) => AdminPage(
    title: '使用记录',
    child: AdminCollection(
      path: '/admin/invites/${adminId(invite['id'])}/uses',
      listKey: 'users',
      paginated: false,
      emptyTitle: '暂无使用记录',
      itemBuilder: (c, row, refresh) => AdminTile(
        title: str(row['displayName'], str(row['username'], '未知用户')),
        subtitle:
            '@${str(row['username'])} · ${adminStatus(row['role'])}\n使用时间 ${_date(row['usedAt'])}',
        status: adminStatus(row['state']),
        icon: Icons.person_outline,
      ),
    ),
  );
}
