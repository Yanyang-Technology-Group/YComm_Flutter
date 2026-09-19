import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/widgets/design.dart';
import 'profile_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('关于晏阳')),
    body: SafeArea(
      child: PageWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: [
            Center(
              child: Image.asset(
                'assets/ycomm_mark.png',
                height: 90,
                width: 90,
                semanticLabel: '晏阳社区 Logo',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '晏阳社区',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '移动客户端 $appVersionLabel',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 28),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.public_rounded,
                  title: '访问社区网站',
                  subtitle: 'community.yanyn.cn',
                  onTap: () => externalLink(context, siteOrigin),
                ),
                SettingsRow(
                  icon: Icons.description_outlined,
                  title: '服务协议',
                  onTap: () => externalLink(
                    context,
                    'https://docs.qq.com/pdf/DQXpNU2NUcWxERWxP',
                  ),
                ),
                SettingsRow(
                  icon: Icons.shield_outlined,
                  title: '儿童个人信息保护规则',
                  onTap: () => externalLink(
                    context,
                    'https://docs.qq.com/doc/DQUN1b0tycXRGdXdn',
                  ),
                ),
                SettingsRow(
                  icon: Icons.code_rounded,
                  title: '开源许可',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: '晏阳社区',
                    applicationVersion: appVersionLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
