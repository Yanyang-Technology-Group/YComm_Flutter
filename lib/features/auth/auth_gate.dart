import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import 'login_page.dart';

Future<bool> requireSession(BuildContext context, WidgetRef ref) async {
  if (ref.read(sessionProvider).value != null) {
    await ref.read(sessionProvider.notifier).refresh();
    if (!context.mounted) return false;
    if (ref.read(sessionProvider).value != null) return true;
    if (ref.read(sessionProvider).hasError) {
      notice(context, '无法确认登录状态，请检查网络后重试');
      return false;
    }
  }
  final result = await openPage<bool>(context, const LoginPage());
  if (result != true || !context.mounted) return false;
  await ref.read(sessionProvider.notifier).refresh();
  if (!context.mounted) return false;
  if (ref.read(sessionProvider).value == null) {
    notice(context, '登录状态尚未确认，请稍后再试');
    return false;
  }
  return true;
}
