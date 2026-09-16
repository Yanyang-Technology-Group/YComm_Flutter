import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'auth_flow.dart';
import 'github_login_button.dart';
import 'captcha_dialog.dart';
import 'terms_consent.dart';
import 'auth_layout.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final api = ApiClient(), form = GlobalKey<FormState>();
  final username = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      invite = TextEditingController();
  String? error;
  bool loading = false, agree = false, obscure = true, done = false;
  @override
  void dispose() {
    username.dispose();
    email.dispose();
    password.dispose();
    invite.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading || !form.currentState!.validate()) return;
    if (!agree) {
      setState(() => error = '请先阅读并同意服务协议和儿童个人信息保护规则');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = null;
    });
    final result = await AuthFlow(api).submit('/auth/register', {
      'username': username.text.trim(),
      'email': email.text.trim(),
      'password': password.text,
      'agreeTerms': agree,
      if (invite.text.trim().isNotEmpty) 'inviteCode': invite.text.trim(),
    }, verify: () async => mounted ? showCaptchaDialog(context) : null);
    if (mounted) {
      setState(() {
        loading = false;
        error = result.isSuccess ? null : result.errorMessage;
        done = result.isSuccess;
      });
    }
  }

  Future<void> githubLogin() async {
    if (loading) return;
    if (!agree) {
      setState(() => error = '请先阅读并同意服务协议和儿童个人信息保护规则');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final success = await signInWithGithub(context, api);
      if (!mounted) return;
      if (success) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => error = '保存登录状态失败，请重新登录');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('创建账号')),
    body: SafeArea(
      child: Form(
        key: form,
        child: AutofillGroup(
          child: AuthLayout(
            title: done ? '注册已提交' : '注册',
            children: done
                ? [
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text('如需验证，请查收邮件。'),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('返回登录'),
                    ),
                  ]
                : [
                    TextFormField(
                      controller: username,
                      enabled: !loading,
                      autofillHints: const [AutofillHints.newUsername],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? '请输入用户名'
                          : v.trim().length > 20
                          ? '用户名不能超过 20 个字符'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: email,
                      enabled: !loading,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) =>
                          v == null ||
                              v.length > 255 ||
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(v.trim())
                          ? '请输入有效邮箱'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      enabled: !loading,
                      obscureText: obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: '密码',
                        helperText: '8–200 个字符',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: obscure ? '显示密码' : '隐藏密码',
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 8 || v.length > 200
                          ? '密码需要 8–200 个字符'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: invite,
                      enabled: !loading,
                      decoration: const InputDecoration(
                        labelText: '邀请码（选填）',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TermsConsent(
                      value: agree,
                      onChanged: loading
                          ? null
                          : (v) => setState(() => agree = v),
                    ),
                    AuthError(error),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: loading ? null : submit,
                      child: Text(loading ? '正在创建…' : '创建账号'),
                    ),
                    const SizedBox(height: 12),
                    GithubLoginButton(onPressed: loading ? null : githubLogin),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: loading ? null : () => Navigator.pop(context),
                      child: const Text('已有账号？返回登录'),
                    ),
                  ],
          ),
        ),
      ),
    ),
  );
}
