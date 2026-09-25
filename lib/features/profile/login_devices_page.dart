import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/adaptive.dart';
import '../../core/design/apple_chrome.dart';
import '../../core/design/tokens.dart';
import '../../core/network/community_api.dart';
import '../../core/widgets/design.dart';

/// 登录设备管理（三级页）：我的 → 设置 → 账号安全 → 登录设备管理。
///
/// 一次登录 = 一条会话；列出当前账号的有效会话，标记当前设备，可退出其他设备。
/// 当前会话不提供远程退出 —— 用「我的」页的「退出登录」。
class LoginDevicesPage extends ConsumerStatefulWidget {
  const LoginDevicesPage({super.key});

  @override
  ConsumerState<LoginDevicesPage> createState() => _LoginDevicesPageState();
}

class _LoginDevicesPageState extends ConsumerState<LoginDevicesPage> {
  /// null = 首屏加载中；加载失败且没有旧数据时配合 [_error] 显示重试。
  List<Json>? _sessions;
  Object? _error;
  bool _busy = false;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(communityProvider).get('/auth/sessions');
      if (!mounted) return;
      setState(() {
        _sessions = jsonList(data['sessions']);
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      // 失败时保留旧列表，只提示并提供重试。
      setState(() => _error = error);
    }
  }

  Future<void> _revokeOne(Json session) async {
    final id = str(session['id']);
    final device = str(session['device'], '未知设备');
    final yes = await appShowDialog<bool>(
      context: context,
      builder: (c) => AppAlertDialog(
        title: const Text('退出该设备的登录？'),
        content: Text('退出「$device」后，该设备需要重新登录。'),
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
            child: const Text('确认退出'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busyId = id);
    try {
      await ref
          .read(communityProvider)
          .delete('/auth/sessions/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      await _load();
      if (mounted) notice(context, '已退出该设备。');
    } catch (error) {
      if (mounted) notice(context, error);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _revokeOthers() async {
    final yes = await appShowDialog<bool>(
      context: context,
      builder: (c) => AppAlertDialog(
        title: const Text('退出其他所有设备？'),
        content: const Text('其他设备上的登录都会失效并需要重新登录，当前设备不受影响。'),
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
            child: const Text('确认全部退出'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final data = await ref
          .read(communityProvider)
          .post('/auth/sessions/revoke-others');
      if (!mounted) return;
      await _load();
      final count = (data['revokedCount'] as num?)?.toInt() ?? 0;
      if (mounted) {
        notice(
          context,
          count > 0 ? '已退出其他 $count 个设备。' : '没有其他需要退出的设备。',
        );
      }
    } catch (error) {
      if (mounted) notice(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return AppScaffold(
      appBar: AppNavigationBar(title: const Text('登录设备管理')),
      body: SafeArea(
        child: PageWidth(
          child: switch ((sessions, _error)) {
            (null, null) => const LoadingRows(),
            (null, final error?) => ErrorPanel(error, _load),
            (final list?, _) => _SessionList(
              sessions: list,
              error: _error,
              busy: _busy,
              busyId: _busyId,
              onRetry: _load,
              onRevokeOne: _revokeOne,
              onRevokeOthers: _revokeOthers,
            ),
          },
        ),
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.error,
    required this.busy,
    required this.busyId,
    required this.onRetry,
    required this.onRevokeOne,
    required this.onRevokeOthers,
  });

  final List<Json> sessions;
  final Object? error;
  final bool busy;
  final String? busyId;
  final Future<void> Function() onRetry;
  final Future<void> Function(Json session) onRevokeOne;
  final Future<void> Function() onRevokeOthers;

  @override
  Widget build(BuildContext context) {
    final others = sessions.where((s) => s['isCurrent'] != true).toList();
    final operating = busy || busyId != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          '一次登录就是一条会话（同一台设备上的不同浏览器或 App 分别列出）。'
          '退出其他设备后，对应设备需要重新登录；当前设备请用「我的」页的「退出登录」。',
          style: _metaStyle(context),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _InlineError(error: error!, retry: onRetry),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppOutlinedButton(
            onPressed: operating ? null : () => onRevokeOthers(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(busy ? '处理中…' : '退出所有其他设备'),
          ),
        ],
        const SizedBox(height: 16),
        if (sessions.isEmpty)
          StatePanel(
            title: '没有有效的登录会话',
            message: '重新登录后，设备会出现在这里。',
            icon: Icons.devices_outlined,
          )
        else
          for (final session in sessions) ...[
            _SessionCard(
              session: session,
              busy: busy,
              busyId: busyId,
              operating: operating,
              onRevoke: () => onRevokeOne(session),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.busy,
    required this.busyId,
    required this.operating,
    required this.onRevoke,
  });

  final Json session;
  final bool busy;
  final String? busyId;
  final bool operating;
  final Future<void> Function() onRevoke;

  @override
  Widget build(BuildContext context) {
    final isCurrent = session['isCurrent'] == true;
    final id = str(session['id']);
    final scheme = Theme.of(context).colorScheme;
    final apple = appleTokensOf(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(apple != null ? AppleSpacing.lg : 16),
      decoration: apple != null
          ? BoxDecoration(
              color: apple.cardBackground,
              borderRadius: BorderRadius.circular(AppleRadius.card),
            )
          : BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .5),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  str(session['device'], '未知设备'),
                  style: _titleStyle(context),
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                const SmallTag('当前设备'),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _MetaLine(
            label: 'IP',
            value: str(session['ip']).trim().isEmpty ? '未知' : str(session['ip']),
          ),
          _MetaLine(label: '登录时间', value: _date(session['createdAt'])),
          _MetaLine(
            label: '最近活跃',
            value: session['lastUsedAt'] == null ? '暂无记录' : _date(session['lastUsedAt']),
          ),
          _MetaLine(label: '过期时间', value: _date(session['expiresAt'])),
          if (!isCurrent) ...[
            const SizedBox(height: 12),
            AppOutlinedButton(
              onPressed: operating ? null : () => onRevoke(),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
              ),
              child: Text(busyId == id ? '处理中…' : '退出此设备'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label：$value', style: _metaStyle(context));
  }
}

/// 双风格文字样式：Apple 用 tokens 排版，Material 跟随主题。
TextStyle _titleStyle(BuildContext context) {
  final apple = appleTokensOf(context);
  if (apple != null) {
    return AppleType.headline.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontFamilyFallback: appleFontFallback,
    );
  }
  return Theme.of(context).textTheme.titleMedium!;
}

TextStyle _metaStyle(BuildContext context) {
  final apple = appleTokensOf(context);
  if (apple != null) {
    return AppleType.footnote.copyWith(
      color: apple.secondaryLabel,
      fontFamilyFallback: appleFontFallback,
    );
  }
  return Theme.of(context).textTheme.bodySmall!.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    height: 1.7,
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error, required this.retry});
  final Object error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            error is RequestFailure ? error.toString() : '加载失败，请重试',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        AppTextButton(onPressed: () => retry(), child: const Text('重试')),
      ],
    );
  }
}

/// ISO 8601 → `yyyy-MM-dd HH:mm`（本地时间），解析失败显示 `—`。
String _date(dynamic value) {
  final parsed = DateTime.tryParse(str(value));
  if (parsed == null) return '—';
  final date = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}
