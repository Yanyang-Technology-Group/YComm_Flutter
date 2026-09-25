import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../auth/auth_flow.dart';
import '../auth/captcha_dialog.dart';
import 'admin_access.dart';
import 'admin_widgets.dart';

Json adminPunishmentPayload(String reason, DateTime? until) => {
  if (reason.trim().isNotEmpty) 'reason': reason.trim(),
  'until': until?.toUtc().toIso8601String(),
};

bool canManageUserOwnerActions(Json? sessionUser) =>
    AdminAccess(sessionUser).isOwner;

String _date(dynamic value) {
  final parsed = DateTime.tryParse(str(value));
  if (parsed == null) return str(value, '未提供');
  final d = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final search = TextEditingController();
  final collection = GlobalKey<AdminCollectionState>();
  String q = '';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void submitSearch() => setState(() => q = search.text.trim());
  @override
  Widget build(BuildContext context) => AdminPage(
    title: '用户管理',
    child: AdminCollection(
      key: collection,
      path: '/admin/users',
      listKey: 'users',
      query: {if (q.isNotEmpty) 'q': q},
      header: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: AppSearchBar(
          elevation: const WidgetStatePropertyAll(0),
          controller: search,
          hintText: '搜索账号或昵称',
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => submitSearch(),
          trailing: [
            AppIconButton(
              tooltip: '搜索',
              onPressed: submitSearch,
              icon: const AppIcon(Icons.search_rounded),
            ),
            if (q.isNotEmpty)
              AppIconButton(
                tooltip: '清除搜索',
                onPressed: () {
                  search.clear();
                  submitSearch();
                },
                icon: const AppIcon(Icons.close_rounded),
              ),
          ],
        ),
      ),
      emptyTitle: q.isEmpty ? '暂无用户' : '没有匹配的用户',
      itemBuilder: (context, user, refresh) => AdminTile(
        title: str(user['displayName'], str(user['username'], '未命名用户')),
        subtitle:
            '@${str(user['username'])}${str(user['email']).isEmpty ? '' : ' · ${str(user['email'])}'}',
        status: '${adminStatus(user['role'])} · ${adminStatus(user['state'])}',
        icon: Icons.person_outline_rounded,
        onTap: () async {
          await Navigator.of(context).push(
            appPageRoute(
              context,
              builder: (_) => AdminUserDetailPage(user: user),
            ),
          );
          if (context.mounted) await refresh();
        },
      ),
    ),
  );
}

class AdminUserDetailPage extends ConsumerStatefulWidget {
  const AdminUserDetailPage({super.key, required this.user});
  final Json user;
  @override
  ConsumerState<AdminUserDetailPage> createState() =>
      _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends ConsumerState<AdminUserDetailPage> {
  late Json user = Json.from(widget.user);
  bool loadingBadges = true;
  bool badgeBusy = false;
  Object? badgeError;
  List<Json> assigned = [], allBadges = [];
  String get id => adminId(user['id']);
  bool get owner => canManageUserOwnerActions(ref.read(sessionProvider).value);
  bool get self =>
      str(ref.read(sessionProvider).value?['id']) == str(user['id']);
  @override
  void initState() {
    super.initState();
    loadBadges();
  }

  bool sameIdentity(String identity) =>
      mounted &&
      AdminAccess(ref.read(sessionProvider).value).identity == identity;
  Future<void> loadBadges() async {
    final identity = AdminAccess(ref.read(sessionProvider).value).identity;
    if (mounted) {
      setState(() {
        loadingBadges = true;
        badgeError = null;
      });
    }
    try {
      final results = await Future.wait([
        ref.read(communityProvider).get('/admin/users/$id/badges'),
        ref.read(communityProvider).get('/admin/badges'),
      ]);
      if (sameIdentity(identity)) {
        setState(() {
          assigned = jsonList(results[0]['badges']);
          allBadges = jsonList(results[1]['badges']);
        });
      }
    } catch (e) {
      if (sameIdentity(identity)) setState(() => badgeError = e);
    } finally {
      if (sameIdentity(identity)) setState(() => loadingBadges = false);
    }
  }

  void updateUser(Json response) {
    final next = response['user'];
    if (next is Map && mounted) setState(() => user = Json.from(next));
  }

  Future<void> punishment(String kind) async {
    await Navigator.of(context).push<bool>(
      appPageRoute(
        context,
        builder: (_) => _PunishmentPage(
          kind: kind,
          username: str(user['username']),
          onSubmit: (value) async {
            final identity = AdminAccess(ref.read(sessionProvider).value)
                .identity;
            final response = await ref
                .read(communityProvider)
                .post(
                  '/admin/users/$id/$kind',
                  adminPunishmentPayload(value.reason, value.until),
                );
            if (sameIdentity(identity)) updateUser(response);
          },
        ),
      ),
    );
  }

  Future<void> lift(String kind) async {
    final identity = AdminAccess(ref.read(sessionProvider).value).identity;
    final ok = await confirmAdminAction(
      context,
      title: kind == 'unmute' ? '解除禁言' : '解除封禁',
      message: '确认恢复 @${str(user['username'])} 的相关权限？',
      danger: false,
      confirmLabel: '确认解除',
      onConfirm: () async {
        final response = await ref
            .read(communityProvider)
            .post('/admin/users/$id/$kind');
        if (sameIdentity(identity)) updateUser(response);
      },
    );
    if (ok && mounted) setState(() {});
  }

  Future<void> role() async {
    final chosen = await showAdminForm(
      context,
      title: '修改角色',
      ownerOnly: true,
      description: '角色变更会立即影响管理权限。目标：@${str(user['username'])}',
      fields: const [
        AdminField(
          'role',
          '新角色',
          options: {'member': '会员', 'admin': '管理员', 'owner': '站长'},
        ),
      ],
      initial: {'role': user['role']},
      onSubmit: (data) async {
        final next = str(data['role']);
        final identity = AdminAccess(ref.read(sessionProvider).value).identity;
        final confirmed = await confirmAdminAction(
          context,
          title: '确认修改角色',
          ownerOnly: true,
          danger: true,
          message:
              '将 @${str(user['username'])} 的角色改为“${adminStatus(next)}”。请确认权限影响。',
          confirmLabel: '修改角色',
          onConfirm: () async {
            final response = await ref.read(communityProvider).patch(
              '/admin/users/$id/role',
              {'role': next},
            );
            if (sameIdentity(identity)) updateUser(response);
          },
        );
        if (!confirmed) throw const RequestFailure('尚未确认角色变更');
      },
    );
    if (chosen && mounted) setState(() {});
  }

  Future<Json> sensitive(String path, Json data) async {
    final identity = AdminAccess(ref.read(sessionProvider).value).identity;
    final result = await AuthFlow(ref.read(communityProvider).client).submit(
      path,
      data,
      verify: () async {
        if (!sameIdentity(identity) || !owner) return null;
        final token = await showCaptchaDialog(context);
        return sameIdentity(identity) && owner ? token : null;
      },
    );
    if (!result.isSuccess) {
      throw RequestFailure(result.errorMessage ?? '请求失败', result.code);
    }
    return result.data is Map ? Json.from(result.data) : {};
  }

  Future<void> resetPassword() async {
    await showAdminForm(
      context,
      title: '重置密码',
      ownerOnly: true,
      submitLabel: '继续确认',
      description: '重置后目标用户的全部会话将失效。',
      fields: const [
        AdminField(
          'newPassword',
          '新密码',
          required: true,
          minLength: 8,
          maxLength: 200,
          obscure: true,
        ),
      ],
      onSubmit: (data) async {
        final password = str(data['newPassword']);
        final identity = AdminAccess(ref.read(sessionProvider).value).identity;
        final confirmed = await confirmAdminAction(
          context,
          title: '确认重置密码',
          ownerOnly: true,
          message: '确认重置 @${str(user['username'])} 的密码并撤销其全部会话？',
          confirmLabel: '重置密码',
          onConfirm: () async {
            final response = await sensitive(
              '/admin/users/$id/reset-password',
              {'newPassword': password},
            );
            if (sameIdentity(identity)) updateUser(response);
          },
        );
        if (!confirmed) throw const RequestFailure('尚未确认密码重置');
      },
    );
  }

  Future<void> deleteUser() async {
    final username = str(user['username']);
    final done = await confirmAdminAction(
      context,
      title: '永久注销用户',
      ownerOnly: true,
      message: '这会立即永久注销 @$username，并撤销相关状态。此操作无法撤销。',
      typedConfirmation: username,
      confirmLabel: '永久注销',
      onConfirm: () async {
        await sensitive('/admin/users/$id/delete', {});
      },
    );
    if (done && mounted) Navigator.pop(context, true);
  }

  Future<void> toggleBadge(Json badge, bool has) async {
    if (badgeBusy) return;
    final identity = AdminAccess(ref.read(sessionProvider).value).identity;
    final badgeId = adminId(badge['id']);
    setState(() => badgeBusy = true);
    try {
      final response = has
          ? await ref
                .read(communityProvider)
                .delete('/admin/users/$id/badges/$badgeId')
          : await ref
                .read(communityProvider)
                .post('/admin/users/$id/badges/$badgeId');
      if (sameIdentity(identity)) {
        setState(() => assigned = jsonList(response['badges']));
      }
    } catch (e) {
      if (mounted) {
        appNotice(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => badgeBusy = false);
    }
  }

  Widget info(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
        final valueWidget = AppSelectableText(str(value, '未提供'));
        if (constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 4), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 104, child: labelWidget),
            const SizedBox(width: 16),
            Expanded(child: valueWidget),
          ],
        );
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    final mute = user['mutedUntil'] != null || str(user['state']) == 'muted';
    final ban = user['bannedUntil'] != null || str(user['state']) == 'banned';
    return AdminPage(
      title: str(user['displayName'], str(user['username'], '用户详情')),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            '@${str(user['username'])}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          Text('账号信息', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          info('用户 ID', user['id']),
          info('邮箱', user['email']),
          info('角色', adminStatus(user['role'])),
          info('状态', adminStatus(user['state'])),
          info('GitHub', user['githubUsername']),
          info('使用邀请码', user['inviteCodeUsed']),
          info('注册时间', _date(user['createdAt'])),
          info('最后登录', _date(user['lastLoginAt'])),
          const AppDivider(height: 40),
          Text('账号处置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (mute) ...[
            info(
              '禁言至',
              user['mutedUntil'] == null ? '永久' : _date(user['mutedUntil']),
            ),
            info('禁言原因', user['muteReason']),
          ],
          if (ban) ...[
            info(
              '封禁至',
              user['bannedUntil'] == null ? '永久' : _date(user['bannedUntil']),
            ),
            info('封禁原因', user['banReason']),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (mute)
                AppOutlinedButton.icon(
                  onPressed: () => lift('unmute'),
                  icon: const AppIcon(Icons.mic_rounded),
                  label: const Text('解除禁言'),
                )
              else
                AppFilledButton.tonalIcon(
                  onPressed: () => punishment('mute'),
                  icon: const AppIcon(Icons.mic_off_outlined),
                  label: const Text('禁言'),
                ),
              if (ban)
                AppOutlinedButton.icon(
                  onPressed: () => lift('unban'),
                  icon: const AppIcon(Icons.lock_open_rounded),
                  label: const Text('解除封禁'),
                )
              else
                AppFilledButton.tonalIcon(
                  onPressed: self ? null : () => punishment('ban'),
                  icon: const AppIcon(Icons.block_rounded),
                  label: const Text('封禁'),
                ),
            ],
          ),
          const AppDivider(height: 40),
          Text('徽章', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (loadingBadges)
            const AppProgress()
          else if (badgeError != null)
            AppOutlinedButton.icon(
              onPressed: loadBadges,
              icon: const AppIcon(Icons.refresh),
              label: Text('加载失败，重试：$badgeError'),
            )
          else if (allBadges.isEmpty)
            const Text('暂无可分配徽章')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final badge in allBadges)
                  Builder(
                    builder: (_) {
                      final has = assigned.any(
                        (a) => str(a['id']) == str(badge['id']),
                      );
                      return AppFilterChip(
                        label: Text(str(badge['name'], '未命名徽章')),
                        selected: has,
                        onSelected: badgeBusy
                            ? null
                            : (_) => toggleBadge(badge, has),
                      );
                    },
                  ),
              ],
            ),
          if (owner) ...[
            const AppDivider(height: 40),
            Text('站长操作', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                AppOutlinedButton.icon(
                  onPressed: role,
                  icon: const AppIcon(Icons.admin_panel_settings_outlined),
                  label: const Text('修改角色'),
                ),
                AppOutlinedButton.icon(
                  onPressed: resetPassword,
                  icon: const AppIcon(Icons.password_rounded),
                  label: const Text('重置密码'),
                ),
                AppFilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: self ? null : deleteUser,
                  icon: const AppIcon(Icons.person_remove_outlined),
                  label: const Text('永久注销'),
                ),
              ],
            ),
            if (self)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '当前账号不能在此永久注销或封禁自身。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PunishmentValue {
  const _PunishmentValue(this.reason, this.until);
  final String reason;
  final DateTime? until;
}

class _PunishmentPage extends StatefulWidget {
  const _PunishmentPage({
    required this.kind,
    required this.username,
    required this.onSubmit,
  });
  final String kind, username;
  final Future<void> Function(_PunishmentValue) onSubmit;
  @override
  State<_PunishmentPage> createState() => _PunishmentPageState();
}

class _PunishmentPageState extends State<_PunishmentPage> {
  final form = GlobalKey<FormState>();
  final reason = TextEditingController();
  String duration = 'day';
  DateTime? custom;
  bool busy = false;
  Object? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> chooseCustom() async {
    final now = DateTime.now();
    final date = await appShowDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: custom ?? now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await appShowTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        custom ?? now.add(const Duration(days: 1)),
      ),
    );
    if (time != null) {
      setState(() {
        custom = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        duration = 'custom';
      });
    }
  }

  Future<void> submit() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    final now = DateTime.now();
    final until = switch (duration) {
      'day' => now.add(const Duration(days: 1)),
      'week' => now.add(const Duration(days: 7)),
      'month' => now.add(const Duration(days: 30)),
      'custom' => custom,
      _ => null,
    };
    if (duration == 'custom' && (until == null || !until.isAfter(now))) {
      appNotice(context, '请选择未来时间');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSubmit(_PunishmentValue(reason.text, until));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: widget.kind == 'mute' ? '禁言用户' : '封禁用户',
    child: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('目标：@${widget.username}'),
          const SizedBox(height: 20),
          AppTextFormField(
            controller: reason,
            enabled: !busy,
            maxLength: 300,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '原因（可选）',
              alignLabelWithHint: true,
            ),
            validator: (v) =>
                (v?.trim().length ?? 0) > 300 ? '原因不能超过 300 个字符' : null,
          ),
          const SizedBox(height: 12),
          AppDropdownButtonFormField<String>(
            initialValue: duration,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '期限'),
            items: const [
              DropdownMenuItem(value: 'day', child: Text('24 小时')),
              DropdownMenuItem(value: 'week', child: Text('7 天')),
              DropdownMenuItem(value: 'month', child: Text('30 天')),
              DropdownMenuItem(value: 'custom', child: Text('自定义时间')),
              DropdownMenuItem(value: 'permanent', child: Text('永久')),
            ],
            onChanged: (v) {
              if (busy) return;
              if (v == 'custom') {
                chooseCustom();
              } else if (v != null) {
                setState(() => duration = v);
              }
            },
          ),
          if (duration == 'custom')
            AppListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('结束时间'),
              subtitle: Text(custom == null ? '尚未选择' : _date(custom)),
              trailing: const AppIcon(Icons.calendar_month),
              onTap: busy ? null : chooseCustom,
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
            onPressed: busy ? null : submit,
            child: Text(
              busy ? '正在提交…' : (widget.kind == 'mute' ? '确认禁言' : '确认封禁'),
            ),
          ),
        ],
      ),
    ),
  );
}
