import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/design.dart';
import 'auth_flow.dart';
import 'github_login_button.dart';
import 'captcha_dialog.dart';
import 'register_page.dart';
import 'terms_consent.dart';
import 'auth_layout.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final api = ApiClient(), form = GlobalKey<FormState>();
  final login = TextEditingController(), password = TextEditingController();
  bool loading = false, agree = false, obscure = true;
  String? error;
  @override
  void dispose() {
    login.dispose();
    password.dispose();
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
    final result = await AuthFlow(api).submit('/auth/login', {
      'login': login.text.trim(),
      'password': password.text,
      'rememberMe': true,
      'agreeTerms': agree,
    }, verify: () async => mounted ? showCaptchaDialog(context) : null);
    if (!mounted) return;
    setState(() {
      loading = false;
      error = result.isSuccess ? null : result.errorMessage;
    });
    if (result.isSuccess) {
      notice(context, '登录成功');
      Navigator.of(context).pop(true);
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
    appBar: AppBar(title: const Text('登录')),
    body: SafeArea(
      child: Form(
        key: form,
        child: AutofillGroup(
          child: AuthLayout(
            title: '登录',
            children: [
              TextFormField(
                controller: login,
                enabled: !loading,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '用户名或邮箱',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? '请输入用户名或邮箱'
                    : v.trim().length > 255
                    ? '用户名或邮箱不能超过 255 个字符'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                enabled: !loading,
                obscureText: obscure,
                autofillHints: const [AutofillHints.password],
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  labelText: '密码',
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
                validator: (v) => v == null || v.isEmpty
                    ? '请输入密码'
                    : v.length > 200
                    ? '密码不能超过 200 个字符'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loading
                      ? null
                      : () => openPage(context, const ForgotPasswordPage()),
                  child: const Text('忘记密码？'),
                ),
              ),
              TermsConsent(
                value: agree,
                onChanged: loading ? null : (v) => setState(() => agree = v),
              ),
              AuthError(error),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: loading ? null : submit,
                child: Text(loading ? '正在登录…' : '登录'),
              ),
              const SizedBox(height: 12),
              GithubLoginButton(onPressed: loading ? null : githubLogin),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final signedIn = await openPage<bool>(
                          context,
                          const RegisterPage(),
                        );
                        if (signedIn == true && context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                child: const Text('创建新账号'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
