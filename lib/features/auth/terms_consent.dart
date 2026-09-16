import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsConsent extends StatelessWidget {
  const TermsConsent({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  Future<void> open(BuildContext context, String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* Show a recoverable UI error below. */
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开协议，请检查默认浏览器')));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: value,
        onChanged: onChanged == null
            ? null
            : (value) => onChanged!(value ?? false),
        title: const Text('我已阅读并同意以下协议'),
      ),
      Wrap(
        children: [
          TextButton(
            onPressed: () =>
                open(context, 'https://docs.qq.com/pdf/DQXpNU2NUcWxERWxP'),
            child: const Text('软件许可及服务协议'),
          ),
          TextButton(
            onPressed: () =>
                open(context, 'https://docs.qq.com/doc/DQUN1b0tycXRGdXdn'),
            child: const Text('儿童个人信息保护规则'),
          ),
        ],
      ),
    ],
  );
}
