import 'package:flutter/material.dart';

import '../../core/design/adaptive.dart';
import '../../core/widgets/design.dart';
import 'login_devices_page.dart';
import 'profile_page.dart';

/// 账号安全（二级页）：登录设备管理等安全入口。
///
/// 路径：我的 → 设置 → 账号安全 → 登录设备管理。
class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppNavigationBar(title: const Text('账号安全')),
      body: SafeArea(
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 8),
              const SectionLabel('登录'),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.devices_outlined,
                    title: '登录设备管理',
                    subtitle: '查看当前有效的登录，退出其他设备',
                    onTap: () => openPage(context, const LoginDevicesPage()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
