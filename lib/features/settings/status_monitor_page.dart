import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/community_api.dart';
import '../../core/network/status_monitor.dart';
import '../../core/widgets/design.dart';

/// 状态监测：跑一组连通性检查，展示服务器、API、WebSocket 与登录态的可用性。
class StatusMonitorPage extends ConsumerStatefulWidget {
  const StatusMonitorPage({super.key});
  @override
  ConsumerState<StatusMonitorPage> createState() => _StatusMonitorPageState();
}

class _StatusMonitorPageState extends ConsumerState<StatusMonitorPage> {
  late Future<StatusReport> report;
  bool running = false;

  @override
  void initState() {
    super.initState();
    report = _run();
  }

  Future<StatusReport> _run() {
    running = true;
    return StatusMonitor(ref.read(communityProvider).client)
        .run()
        .whenComplete(() {
          if (mounted) setState(() => running = false);
        });
  }

  void rerun() {
    setState(() => report = _run());
  }

  Future<void> copyReport(StatusReport value) async {
    final buffer = StringBuffer()
      ..writeln('开始时间: ${value.startedAt}')
      ..writeln('总耗时: ${value.totalMs} ms')
      ..writeln();
    for (final check in value.checks) {
      buffer.writeln(
        '[${check.ok ? 'OK' : 'FAIL'}] ${check.name} '
        '${check.elapsedMs} ms ${check.detail}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) notice(context, '诊断报告已复制');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppScaffold(
      appBar: AppNavigationBar(
        title: const Text('状态监测'),
        actions: [
          AppIconButton(
            tooltip: '重新检测',
            onPressed: running ? null : rerun,
            icon: const AppIcon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<StatusReport>(
          future: report,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSpinner(),
                    SizedBox(height: 16),
                    Text('正在检测……'),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return ListView(children: [ErrorPanel(snapshot.error!, rerun)]);
            }
            final value = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                AppCard(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        AppCircleAvatar(
                          backgroundColor: value.passed
                              ? colors.primaryContainer
                              : colors.errorContainer,
                          child: AppIcon(
                            value.passed
                                ? Icons.check_rounded
                                : Icons.error_outline,
                            color: value.passed
                                ? colors.onPrimaryContainer
                                : colors.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value.passed ? '连接状态正常' : '连接存在问题',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '总耗时：${value.totalMs} ms',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        AppIconButton(
                          tooltip: '复制报告',
                          onPressed: () => copyReport(value),
                          icon: const AppIcon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final check in value.checks)
                  AppCard(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: AppListTile(
                      leading: AppIcon(
                        check.ok
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: check.ok ? colors.primary : colors.error,
                      ),
                      title: Text(check.name),
                      subtitle: AppSelectableText(
                        check.detail.isEmpty ? '-' : check.detail,
                      ),
                      trailing: Text('${check.elapsedMs} ms'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
