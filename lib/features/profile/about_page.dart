import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/update/update_controller.dart';
import '../../core/widgets/design.dart';
import '../update/update_ui.dart';
import 'profile_page.dart';

/// 客户端开源仓库。
const String repositoryUrl =
    'https://github.com/Yanyang-Technology-Group/YComm_Flutter';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    return AppScaffold(
      appBar: AppNavigationBar(title: const Text('关于晏阳社区')),
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
                    icon: Icons.system_update_alt_rounded,
                    title: '检查更新',
                    subtitle: state.checking
                        ? '正在检查…'
                        : '当前版本 $appVersionLabel',
                    onTap: state.checking
                        ? () {}
                        : () => checkForUpdates(context, ref),
                  ),
                  SettingsRow(
                    icon: Icons.public_rounded,
                    title: '访问社区网站',
                    subtitle: 'community.yanyn.cn',
                    onTap: () => externalLink(context, siteOrigin),
                  ),
                  SettingsRow(
                    icon: Icons.source_rounded,
                    title: '开源仓库',
                    subtitle: 'Yanyang-Technology-Group/YComm_Flutter',
                    onTap: () => externalLink(context, repositoryUrl),
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
                    onTap: () => appShowLicensePage(
                      context: context,
                      applicationName: '晏阳社区',
                      applicationVersion: appVersionLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                '© 2025-2026 晏阳技术组',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
