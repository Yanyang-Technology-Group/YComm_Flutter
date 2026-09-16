import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'auth_flow.dart';
import 'captcha_dialog.dart';
import 'auth_layout.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController(), form = GlobalKey<FormState>();
  bool busy = false, done = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await AuthFlow(ApiClient()).submit('/auth/forgot-password', {
      'email': email.text.trim(),
    }, verify: () async => mounted ? showCaptchaDialog(context) : null);
    if (mounted) {
      setState(() {
        busy = false;
        done = result.isSuccess;
        error = result.isSuccess ? null : result.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('找回密码')),
    body: SafeArea(
      child: Form(
        key: form,
        child: AuthLayout(
          title: done ? '请求已提交' : '找回密码',
          children: done
              ? [
                  const Text('若邮箱已注册，请查收重置邮件。'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回登录'),
                  ),
                ]
              : [
                  TextFormField(
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '注册邮箱',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (v) =>
                        v == null ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(v.trim())
                        ? '请输入有效邮箱'
                        : null,
                  ),
                  AuthError(error),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(busy ? '正在发送…' : '发送重置邮件'),
                  ),
                ],
        ),
      ),
    ),
  );
}
