import '../../core/design/adaptive.dart';

import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/design.dart';
import 'github_login_page.dart';

Future<bool> signInWithGithub(BuildContext context, ApiClient api) async {
  FocusScope.of(context).unfocus();
  final cookies = await openPage<List<Cookie>>(
    context,
    const GithubLoginPage(),
  );
  if (cookies == null || !context.mounted) return false;
  await api.acceptGithubSession(cookies);
  if (!context.mounted) return false;
  notice(context, 'GitHub 登录成功');
  return true;
}

class GithubLoginButton extends StatelessWidget {
  const GithubLoginButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => AppOutlinedButton.icon(
    onPressed: onPressed,
    icon: Image.asset(
      'assets/github_mark.png',
      width: 20,
      height: 20,
      color: onPressed == null
          ? Theme.of(context).disabledColor
          : Theme.of(context).colorScheme.onSurface,
      excludeFromSemantics: true,
    ),
    label: const Text('使用 GitHub 登录'),
  );
}
