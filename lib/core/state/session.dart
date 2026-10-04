import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/community_api.dart';

class SessionController extends Notifier<AsyncValue<Json?>> {
  int _generation = 0;
  @override
  AsyncValue<Json?> build() {
    scheduleMicrotask(refresh);
    return const AsyncLoading();
  }

  Future<Json?> _load() async {
    try {
      final data = await ref.read(communityProvider).get('/auth/me');
      return data['user'] is Map ? Json.from(data['user']) : null;
    } on RequestFailure catch (e) {
      if ([
        'UNAUTHENTICATED',
        'UNAUTHORIZED',
        'AUTH_REQUIRED',
        '401',
      ].contains(e.code)) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    final ticket = ++_generation;
    final next = await AsyncValue.guard(_load);
    if (ref.mounted && ticket == _generation) state = next;
  }

  Future<void> logout() async {
    ++_generation;
    await ref.read(communityProvider).post('/auth/logout');
    ++_generation;
    await ref.read(communityProvider).client.clearSession();
    if (ref.mounted) state = const AsyncData(null);
  }
}

final sessionProvider = NotifierProvider<SessionController, AsyncValue<Json?>>(
  SessionController.new,
);

/// 账号门槛状态：未验证邮箱 / 待确认的新设备。
///
/// 服务端已经把这两种情况下的内容请求全部 403（`ACCOUNT_UNVERIFIED` /
/// `DEVICE_UNVERIFIED`），这里只是把「为什么用不了、该点哪里」讲清楚。
class AccountGate {
  const AccountGate({
    this.needsEmailVerification = false,
    this.pendingDevice = false,
    this.email,
    this.graceEndsAt,
    this.reminderHours = 6,
  });

  final bool needsEmailVerification;
  final bool pendingDevice;
  final String? email;

  /// 未验证邮箱的自动注销时刻（ISO8601）。
  final String? graceEndsAt;

  /// 提醒邮件间隔（小时）。
  final int reminderHours;

  bool get isBlocked => needsEmailVerification || pendingDevice;

  factory AccountGate.fromJson(Json data) => AccountGate(
    needsEmailVerification: data['needsEmailVerification'] == true,
    pendingDevice: data['pendingDevice'] == true,
    email: data['email'] is String ? data['email'] as String : null,
    graceEndsAt: data['verificationGraceEndsAt'] is String
        ? data['verificationGraceEndsAt'] as String
        : null,
    reminderHours: (data['verificationReminderHours'] as num?)?.toInt() ?? 6,
  );
}

class AccountGateController extends Notifier<AsyncValue<AccountGate?>> {
  int _generation = 0;

  @override
  AsyncValue<AccountGate?> build() {
    scheduleMicrotask(refresh);
    return const AsyncLoading();
  }

  Future<AccountGate?> _load() async {
    try {
      final data = await ref.read(communityProvider).get('/auth/me');
      return AccountGate.fromJson(data);
    } on RequestFailure catch (e) {
      if ([
        'UNAUTHENTICATED',
        'UNAUTHORIZED',
        'AUTH_REQUIRED',
        '401',
      ].contains(e.code)) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    final ticket = ++_generation;
    final next = await AsyncValue.guard(_load);
    if (ref.mounted && ticket == _generation) state = next;
  }

  /// 重新发一封验证 / 确认邮件。返回是否成功。
  Future<bool> resend({required bool device}) async {
    try {
      await ref
          .read(communityProvider)
          .post(device ? '/auth/resend-device' : '/auth/resend-verification');
      return true;
    } on RequestFailure {
      return false;
    }
  }
}

final accountGateProvider =
    NotifierProvider<AccountGateController, AsyncValue<AccountGate?>>(
      AccountGateController.new,
    );
