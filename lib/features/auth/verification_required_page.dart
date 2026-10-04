import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/adaptive.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';

/// 未验证邮箱 / 待确认新设备时的引导页。
///
/// 服务端在这两种状态下会把所有内容请求 403（`ACCOUNT_UNVERIFIED` /
/// `DEVICE_UNVERIFIED`），所以在客户端直接把整个壳层换成这一页，别让用户面对
/// 一堆看不懂的报错。
class VerificationRequiredView extends ConsumerStatefulWidget {
  const VerificationRequiredView({super.key, required this.gate});

  final AccountGate gate;

  @override
  ConsumerState<VerificationRequiredView> createState() =>
      _VerificationRequiredViewState();
}

class _VerificationRequiredViewState
    extends ConsumerState<VerificationRequiredView> {
  bool _busy = false;

  Future<void> _resend() async {
    setState(() => _busy = true);
    final ok = await ref
        .read(accountGateProvider.notifier)
        .resend(device: !widget.gate.needsEmailVerification);
    if (!mounted) return;
    setState(() => _busy = false);
    notice(context, ok ? '邮件已重新发送，请查收（含垃圾邮件箱）' : '发送失败，请稍后再试');
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    await ref.read(accountGateProvider.notifier).refresh();
    await ref.read(sessionProvider.notifier).refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    await ref.read(sessionProvider.notifier).logout();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gate = widget.gate;
    final email = gate.email ?? '你的邮箱';
    final verifyingEmail = gate.needsEmailVerification;
    return AppScaffold(
      appBar: AppNavigationBar(title: Text(verifyingEmail ? '验证邮箱' : '确认新设备')),
      body: SafeArea(
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Center(
                child: AppIcon(
                  verifyingEmail
                      ? Icons.mark_email_unread_outlined
                      : Icons.devices_other_outlined,
                  size: 44,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                verifyingEmail ? '请先验证邮箱' : '请确认这台新设备',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                verifyingEmail
                    ? '你的账号（$email）还没有验证邮箱，验证之前社区内容和管理功能都不可用。'
                    : '你的账号刚刚在一台新设备上登录。确认是本人在用之前，这台设备不能访问社区。',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6),
              ),
              if (verifyingEmail) ...[
                const SizedBox(height: 10),
                Text(
                  '我们每 ${gate.reminderHours} 小时会重发一次验证邮件'
                  '${gate.graceEndsAt != null ? '；如果在那之前仍未验证，账号会被自动注销（用户名和邮箱会被释放）' : ''}。',
                  style: TextStyle(color: scheme.error, height: 1.6),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  '确认邮件已发到 $email，点里面的链接即可。没收到就点下面的按钮重发。',
                  style: TextStyle(color: scheme.error, height: 1.6),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _resend,
                child: Text(verifyingEmail ? '重新发送验证邮件' : '重新发送确认邮件'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy ? null : _refresh,
                child: const Text('我已经验证了，刷新'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _busy ? null : _logout,
                child: const Text('退出登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
