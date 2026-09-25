import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import '../auth/auth_gate.dart';

class AdminAccess {
  const AdminAccess(this.user);
  final Json? user;
  bool get usable =>
      user != null && str(user!['id']).isNotEmpty && user!['state'] == 'active';
  bool get isStaff => usable && ['admin', 'owner'].contains(user!['role']);
  bool get isOwner => usable && user!['role'] == 'owner';
  bool owns(dynamic author) =>
      usable && author != null && str(author) == str(user!['id']);
  bool canWithdraw(dynamic author) => owns(author) || isOwner;
  String get identity => '${user?['id']}:${user?['role']}:${user?['state']}';
}

/// Guard every pushed management route, including forms and confirmation dialogs.
/// Identity changes dispose the sensitive subtree rather than reusing old data.
class AdminGuard extends ConsumerStatefulWidget {
  const AdminGuard({super.key, required this.child, this.ownerOnly = false});
  final Widget child;
  final bool ownerOnly;
  @override
  ConsumerState<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends ConsumerState<AdminGuard> {
  String? identity;
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final access = AdminAccess(session.value);
    if (session.isLoading) {
      return const SingleChildScrollView(child: LoadingRows());
    }
    if (session.hasError) {
      return SingleChildScrollView(
        child: ErrorPanel(
          session.error!,
          () => ref.read(sessionProvider.notifier).refresh(),
        ),
      );
    }
    if (session.value == null) {
      return SingleChildScrollView(
        child: StatePanel(
          title: '请先登录',
          message: '登录管理员账号后访问管理中心。',
          action: AppOutlinedButton(
            onPressed: () => requireSession(context, ref),
            child: const Text('登录'),
          ),
        ),
      );
    }
    if (!access.isStaff || (widget.ownerOnly && !access.isOwner)) {
      return const SingleChildScrollView(
        child: StatePanel(
          title: '暂无管理权限',
          message: '当前账号无法访问此页面。',
          icon: Icons.lock_outline,
        ),
      );
    }
    identity ??= access.identity;
    if (identity != access.identity) {
      return const SingleChildScrollView(
        child: StatePanel(
          title: '账号权限已变更',
          message: '请返回管理中心重新进入。',
          icon: Icons.lock_outline,
        ),
      );
    }
    return KeyedSubtree(key: ValueKey(identity), child: widget.child);
  }
}
