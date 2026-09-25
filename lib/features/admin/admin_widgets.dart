import '../../core/design/adaptive.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import 'admin_access.dart';

String adminId(dynamic value) => Uri.encodeComponent(str(value));
String adminStatus(dynamic value) =>
    const {
      'pending': '待审核',
      'published': '已发布',
      'approved': '已通过',
      'rejected': '已驳回',
      'withdrawn': '已撤回',
      'deleted': '已删除',
      'active': '正常',
      'muted': '已禁言',
      'banned': '已封禁',
      'member': '会员',
      'admin': '管理员',
      'owner': '站长',
      'topic': '主题',
      'post': '回复',
      'resource': '资源',
      'download_resource': '资源',
      'download_link': '下载链接',
      'card': '下载卡片',
      'public': '公开',
      'login': '登录可见',
      'invite': '受邀可见',
      'staff': '管理团队',
    }[str(value)] ??
    str(value, '未提供');
String prettyJson(dynamic value) {
  if (value is String) return value;
  return const JsonEncoder.withIndent('  ').convert(value);
}

class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.ownerOnly = false,
    this.maxWidth = 720,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool ownerOnly;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppNavigationBar(
      title: Text(title),
      actions: actions
          .map(
            (a) => Consumer(
              builder: (context, ref, _) {
                final access = AdminAccess(ref.watch(sessionProvider).value);
                return access.isStaff && (!ownerOnly || access.isOwner)
                    ? a
                    : const SizedBox.shrink();
              },
            ),
          )
          .toList(),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AdminGuard(ownerOnly: ownerOnly, child: child),
        ),
      ),
    ),
  );
}

/// Server pagination with optional total; never infer a total from the first page.
class AdminCollection extends ConsumerStatefulWidget {
  const AdminCollection({
    super.key,
    required this.path,
    required this.listKey,
    required this.itemBuilder,
    this.query = const {},
    this.header,
    this.paginated = true,
    this.emptyTitle = '暂无内容',
    this.pageSize = 30,
  });
  final String path, listKey, emptyTitle;
  final Json query;
  final bool paginated;
  final int pageSize;
  final Widget? header;
  final Widget Function(BuildContext, Json, Future<void> Function())
  itemBuilder;
  @override
  ConsumerState<AdminCollection> createState() => AdminCollectionState();
}

class AdminCollectionState extends ConsumerState<AdminCollection> {
  List<Json> rows = [];
  bool loading = true, loadingMore = false, hasMore = false;
  Object? error;
  int generation = 0, offset = 0;
  bool failedAppend = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant AdminCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        jsonEncode(oldWidget.query) != jsonEncode(widget.query)) {
      rows = [];
      offset = 0;
      load();
    }
  }

  Future<void> refresh() => load();
  Future<void> load({bool append = false}) async {
    if (!mounted) return;
    final ticket = ++generation;
    final identity = AdminAccess(ref.read(sessionProvider).value).identity;
    setState(() {
      loading = !append;
      loadingMore = append;
      error = null;
      failedAppend = append;
    });
    try {
      final data = await ref
          .read(communityProvider)
          .get(
            widget.path,
            query: {
              ...widget.query,
              if (widget.paginated) ...{
                'offset': append ? offset : 0,
                'limit': widget.pageSize,
              },
            },
          );
      if (!mounted ||
          ticket != generation ||
          identity != AdminAccess(ref.read(sessionProvider).value).identity) {
        return;
      }
      final batch = jsonList(data[widget.listKey]);
      final nextOffset = (append ? offset : 0) + batch.length;
      setState(() {
        rows = append ? [...rows, ...batch] : batch;
        offset = nextOffset;
        final total = data['total'];
        hasMore =
            widget.paginated &&
            batch.isNotEmpty &&
            (total is num ? offset < total : batch.length == widget.pageSize);
      });
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    } finally {
      if (mounted && ticket == generation) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final denied =
        error is RequestFailure &&
        [
          'FORBIDDEN',
          'UNAUTHENTICATED',
          'ACCESS_LOGIN_REQUIRED',
          '401',
          '403',
        ].contains((error as RequestFailure).code);
    return AppRefresh(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ?widget.header,
          if (loading && rows.isEmpty)
            const LoadingRows()
          else if (denied)
            StatePanel(
              title: '当前无法访问',
              message: error.toString(),
              icon: Icons.lock_outline,
              action: AppOutlinedButton(
                onPressed: refresh,
                child: const Text('重新检查'),
              ),
            )
          else ...[
            if (loading) const AppProgress(minHeight: 2),
            if (error != null)
              ErrorPanel(error!, () => load(append: failedAppend)),
            if (rows.isEmpty && error == null)
              StatePanel(
                title: widget.emptyTitle,
                icon: Icons.task_alt_rounded,
              ),
            for (final row in rows) widget.itemBuilder(context, row, refresh),
            if (hasMore && error == null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: AppOutlinedButton(
                  onPressed: loadingMore || loading
                      ? null
                      : () => load(append: true),
                  child: Text(loadingMore ? '正在加载…' : '加载更多'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class AdminTile extends StatelessWidget {
  const AdminTile({
    super.key,
    required this.title,
    this.subtitle,
    this.status,
    this.icon = Icons.article_outlined,
    this.onTap,
    this.trailing,
    this.markdownTitle = false,
    this.description,
  });
  final String title;
  final String? subtitle, status;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool markdownTitle;
  final String? description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppSurface(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: AppListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: AppIcon(icon, color: Theme.of(context).colorScheme.primary),
        title: markdownTitle
            ? MarkdownText(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              )
            : Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle!),
              ),
            if (description != null && description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: MarkdownText(description!),
              ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SmallTag(status!),
              ),
          ],
        ),
        trailing:
            trailing ??
            (onTap == null ? null : const AppIcon(Icons.chevron_right_rounded)),
        onTap: onTap,
      ),
    ),
  );
}

class AdminField {
  const AdminField(
    this.key,
    this.label, {
    this.required = false,
    this.maxLength,
    this.minLength = 0,
    this.lines = 1,
    this.options,
    this.number = false,
    this.min,
    this.max,
    this.hint,
    this.obscure = false,
    this.validate,
    this.markdownOptions = false,
  });
  final String key, label;
  final bool required, number, obscure;
  final bool markdownOptions;
  final int? maxLength, min, max;
  final int minLength, lines;
  final String? hint;
  final Map<String, String>? options;
  final String? Function(String)? validate;
}

Future<bool> showAdminForm(
  BuildContext context, {
  required String title,
  required List<AdminField> fields,
  Json initial = const {},
  required Future<void> Function(Json) onSubmit,
  String submitLabel = '保存',
  String? description,
  bool ownerOnly = false,
}) async =>
    await openPage<bool>(
      context,
      _AdminForm(
        title: title,
        fields: fields,
        initial: initial,
        onSubmit: onSubmit,
        submitLabel: submitLabel,
        description: description,
        ownerOnly: ownerOnly,
      ),
    ) ??
    false;

class _AdminForm extends ConsumerStatefulWidget {
  const _AdminForm({
    required this.title,
    required this.fields,
    required this.initial,
    required this.onSubmit,
    required this.submitLabel,
    this.description,
    this.ownerOnly = false,
  });
  final String title, submitLabel;
  final List<AdminField> fields;
  final Json initial;
  final Future<void> Function(Json) onSubmit;
  final String? description;
  final bool ownerOnly;
  @override
  ConsumerState<_AdminForm> createState() => _AdminFormState();
}

class _AdminFormState extends ConsumerState<_AdminForm> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  late final Map<String, String> choices;
  late final String identity;
  bool busy = false, changed = false, exiting = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    identity = AdminAccess(ref.read(sessionProvider).value).identity;
    controllers = {
      for (final f in widget.fields.where((f) => f.options == null))
        f.key: TextEditingController(text: str(widget.initial[f.key])),
    };
    choices = {
      for (final f in widget.fields.where((f) => f.options != null))
        f.key: str(widget.initial[f.key], f.options!.keys.first),
    };
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (identity != AdminAccess(ref.read(sessionProvider).value).identity) {
      return;
    }
    final data = <String, dynamic>{};
    for (final f in widget.fields) {
      final value =
          choices[f.key] ??
          (f.obscure
              ? controllers[f.key]!.text
              : controllers[f.key]!.text.trim());
      data[f.key] = f.number && value.isNotEmpty ? int.parse(value) : value;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSubmit(data);
      if (mounted) {
        setState(() {
          exiting = true;
          busy = false;
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
        title: const Text('放弃未保存的修改？'),
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
    canPop: exiting || (!changed && !busy),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) back();
    },
    child: AdminPage(
      title: widget.title,
      ownerOnly: widget.ownerOnly,
      child: Form(
        key: form,
        onChanged: () {
          if (!changed) setState(() => changed = true);
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.description != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(widget.description!),
              ),
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: f.options != null
                    ? AppDropdownButtonFormField<String>(
                        initialValue: f.options!.containsKey(choices[f.key])
                            ? choices[f.key]
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: f.label),
                        items: f.options!.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: f.markdownOptions
                                    ? MarkdownText(
                                        e.value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (v) => setState(() {
                                choices[f.key] = v!;
                                changed = true;
                              }),
                        validator: (v) => v == null ? '请选择${f.label}' : null,
                      )
                    : AppTextFormField(
                        controller: controllers[f.key],
                        enabled: !busy,
                        obscureText: f.obscure,
                        maxLines: f.lines,
                        maxLength: f.maxLength,
                        keyboardType: f.number
                            ? TextInputType.number
                            : (f.lines > 1
                                  ? TextInputType.multiline
                                  : TextInputType.text),
                        decoration: InputDecoration(
                          labelText: f.label,
                          hintText: f.hint,
                          alignLabelWithHint: f.lines > 1,
                        ),
                        validator: (raw) {
                          final v = f.obscure
                              ? (raw ?? '')
                              : (raw?.trim() ?? '');
                          if (f.required && v.isEmpty) return '请填写${f.label}';
                          if (v.isNotEmpty && v.length < f.minLength) {
                            return '至少输入 ${f.minLength} 个字符';
                          }
                          if (v.isNotEmpty && f.number) {
                            final n = int.tryParse(v);
                            if (n == null ||
                                (f.min != null && n < f.min!) ||
                                (f.max != null && n > f.max!)) {
                              return '请输入有效整数${f.min != null ? '（${f.min}–${f.max ?? '不限'}）' : ''}';
                            }
                          }
                          return f.validate?.call(v);
                        },
                      ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            AppFilledButton(
              onPressed: busy ? null : submit,
              child: Text(busy ? '正在提交…' : widget.submitLabel),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Executes inside the confirmation dialog: errors retain context and prevent
/// callers from accidentally reporting a cancelled operation as successful.
Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onConfirm,
  String confirmLabel = '确认',
  String? typedConfirmation,
  bool danger = true,
  bool ownerOnly = false,
}) async =>
    await appShowDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminConfirmation(
        title: title,
        message: message,
        onConfirm: onConfirm,
        confirmLabel: confirmLabel,
        typedConfirmation: typedConfirmation,
        danger: danger,
        ownerOnly: ownerOnly,
      ),
    ) ??
    false;

class _AdminConfirmation extends ConsumerStatefulWidget {
  const _AdminConfirmation({
    required this.title,
    required this.message,
    required this.onConfirm,
    required this.confirmLabel,
    this.typedConfirmation,
    required this.danger,
    required this.ownerOnly,
  });
  final String title, message, confirmLabel;
  final String? typedConfirmation;
  final Future<void> Function() onConfirm;
  final bool danger, ownerOnly;
  @override
  ConsumerState<_AdminConfirmation> createState() => _AdminConfirmationState();
}

class _AdminConfirmationState extends ConsumerState<_AdminConfirmation> {
  final input = TextEditingController();
  bool busy = false, exiting = false;
  Object? error;
  late final String identity;
  @override
  void initState() {
    super.initState();
    identity = AdminAccess(ref.read(sessionProvider).value).identity;
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy ||
        identity != AdminAccess(ref.read(sessionProvider).value).identity) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onConfirm();
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: exiting || !busy,
    child: AppAlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: AdminGuard(
          ownerOnly: widget.ownerOnly,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message),
              if (widget.typedConfirmation != null) ...[
                const SizedBox(height: 16),
                Text('请输入 ${widget.typedConfirmation} 以确认'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: input,
                  enabled: !busy,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        AppTextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        AppFilledButton(
          style: widget.danger
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed:
              busy ||
                  identity !=
                      AdminAccess(ref.watch(sessionProvider).value).identity ||
                  (widget.typedConfirmation != null &&
                      input.text != widget.typedConfirmation)
              ? null
              : submit,
          child: Text(busy ? '正在处理…' : widget.confirmLabel),
        ),
      ],
    ),
  );
}
