import '../../core/design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_debug.dart';
import '../../core/network/community_api.dart';
import '../../core/widgets/design.dart';
import 'api_doc.dart';

/// API 浏览器：搜索接口、查看参数并在线发起请求。
class ApiExplorerPage extends ConsumerStatefulWidget {
  const ApiExplorerPage({super.key});
  @override
  ConsumerState<ApiExplorerPage> createState() => _ApiExplorerPageState();
}

class _ApiExplorerPageState extends ConsumerState<ApiExplorerPage> {
  final search = TextEditingController();
  final route = TextEditingController();
  final paramControllers = <String, TextEditingController>{};
  ApiDocEndpoint selected = apiDocEndpoints.first;
  ApiDebugResponse? response;
  String? error;
  bool running = false;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    applyEndpoint(selected, notify: false);
  }

  @override
  void dispose() {
    search.dispose();
    route.dispose();
    for (final controller in paramControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<ApiDocEndpoint> get filteredEndpoints {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) return apiDocEndpoints;
    return apiDocEndpoints.where((endpoint) {
      return endpoint.route.toLowerCase().contains(query) ||
          endpoint.group.toLowerCase().contains(query) ||
          endpoint.summary.toLowerCase().contains(query) ||
          endpoint.description.toLowerCase().contains(query) ||
          endpoint.params.any(
            (param) =>
                param.name.toLowerCase().contains(query) ||
                param.description.toLowerCase().contains(query),
          );
    }).toList();
  }

  void selectEndpoint(ApiDocEndpoint endpoint) => applyEndpoint(endpoint);

  /// 切换接口时把参数输入框换掉；同名参数沿用已填的值。
  void applyEndpoint(ApiDocEndpoint endpoint, {bool notify = true}) {
    selected = endpoint;
    route.text = endpoint.route;
    final existing = <String, String>{
      for (final entry in paramControllers.entries) entry.key: entry.value.text,
    };
    for (final controller in paramControllers.values) {
      controller.dispose();
    }
    paramControllers
      ..clear()
      ..addEntries(
        endpoint.params.map(
          (param) => MapEntry(
            param.name,
            TextEditingController(text: existing[param.name] ?? param.example),
          ),
        ),
      );
    response = null;
    error = null;
    if (notify && mounted) setState(() {});
  }

  /// 把路径参数塞进 route，其余的当作 query/body。
  ///
  /// 路由里出现 `{name}` 时用该参数的值替换；被替换掉的参数不再发给服务端。
  ({String route, Map<String, dynamic> rest}) splitRouteParams() {
    var resolved = route.text.trim();
    final rest = <String, dynamic>{};
    for (final entry in paramControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) continue;
      if (resolved.contains('{${entry.key}}')) {
        resolved = resolved.replaceAll(
          '{${entry.key}}',
          Uri.encodeComponent(value),
        );
      } else {
        rest[entry.key] = value;
      }
    }
    return (route: resolved, rest: rest);
  }

  Future<void> runSelectedEndpoint() async {
    if (running) return;
    setState(() {
      running = true;
      error = null;
      response = null;
    });
    final split = splitRouteParams();
    try {
      final result = await ref
          .read(communityProvider)
          .client
          .runDebugRequest(
            method: selected.methodLabel,
            route: split.route,
            data: split.rest,
          );
      if (mounted) setState(() => response = result);
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  Future<void> copyResult() async {
    final text = response?.prettyBody ?? error ?? '';
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) notice(context, '已复制');
  }

  @override
  Widget build(BuildContext context) {
    final endpoints = filteredEndpoints;
    return AppScaffold(
      appBar: AppNavigationBar(
        title: const Text('API 浏览器'),
        actions: [
          AppIconButton(
            tooltip: '复制响应',
            onPressed: response == null && error == null ? null : copyResult,
            icon: const AppIcon(Icons.copy_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            final list = _EndpointList(
              search: search,
              endpoints: endpoints,
              selected: selected,
              onSelect: selectEndpoint,
            );
            final detail = _EndpointDetail(
              endpoint: selected,
              route: route,
              paramControllers: paramControllers,
              running: running,
              response: response,
              error: error,
              onRun: runSelectedEndpoint,
              onCopy: copyResult,
            );
            if (wide) {
              // min + stretch：左栏是 340px 的非弹性子项，stretch 会让 Row
              // 自身被撑到超出父级宽度，溢出区域盖住标题栏的拖拽热区。
              // min 让 Row 老实收缩到 min(340 + 1 + detail, 父宽度)。
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 340, child: list),
                  const VerticalDivider(width: 1),
                  Expanded(child: detail),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(height: 280, child: list),
                const AppDivider(height: 1),
                Expanded(child: detail),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EndpointList extends StatelessWidget {
  const _EndpointList({
    required this.search,
    required this.endpoints,
    required this.selected,
    required this.onSelect,
  });

  final TextEditingController search;
  final List<ApiDocEndpoint> endpoints;
  final ApiDocEndpoint selected;
  final ValueChanged<ApiDocEndpoint> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppTextField(
            controller: search,
            decoration: const InputDecoration(
              prefixIcon: AppIcon(Icons.search_rounded),
              hintText: '搜索 API 接口',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: endpoints.isEmpty
              ? const StatePanel(
                  title: '没有匹配的 API。',
                  icon: Icons.search_off_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: endpoints.length,
                  itemBuilder: (context, index) {
                    final endpoint = endpoints[index];
                    final active =
                        endpoint.route == selected.route &&
                        endpoint.method == selected.method;
                    return AppCard(
                      elevation: 0,
                      color: active
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: AppListTile(
                        dense: true,
                        leading: _MethodBadge(method: endpoint.methodLabel),
                        title: Text(
                          endpoint.route,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        subtitle: Text(
                          '${endpoint.group} · ${endpoint.summary}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: active,
                        onTap: () => onSelect(endpoint),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EndpointDetail extends StatelessWidget {
  const _EndpointDetail({
    required this.endpoint,
    required this.route,
    required this.paramControllers,
    required this.running,
    required this.response,
    required this.error,
    required this.onRun,
    required this.onCopy,
  });

  final ApiDocEndpoint endpoint;
  final TextEditingController route;
  final Map<String, TextEditingController> paramControllers;
  final bool running;
  final ApiDebugResponse? response;
  final String? error;
  final VoidCallback onRun;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AppCard(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MethodBadge(method: endpoint.methodLabel),
                    AppChip(label: Text(endpoint.group)),
                    if (!endpoint.runnableInExplorer)
                      const AppChip(
                        avatar: AppIcon(
                          Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        label: Text('仅供文档'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                AppSelectableText(
                  endpoint.route,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  endpoint.summary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  endpoint.description,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '在线运行',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: route,
                  decoration: const InputDecoration(
                    labelText: '路由',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                if (endpoint.params.isEmpty)
                  Text(
                    '无参数。',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  )
                else
                  for (final param in endpoint.params) ...[
                    AppTextField(
                      controller: paramControllers[param.name],
                      decoration: InputDecoration(
                        labelText: '${param.name}${param.required ? ' *' : ''}',
                        helperText: param.description,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  children: [
                    AppFilledButton.icon(
                      onPressed: running || !endpoint.runnableInExplorer
                          ? null
                          : onRun,
                      icon: running
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: AppSpinner(strokeWidth: 2),
                            )
                          : const AppIcon(Icons.play_arrow_rounded),
                      label: Text(
                        endpoint.runnableInExplorer ? '发起请求' : '仅供文档',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _ResultPanel(
              response: response,
              error: error,
              onCopy: onCopy,
            ),
          ),
        ),
      ],
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method});
  final String method;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isWrite = method != 'GET';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isWrite ? colors.tertiaryContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          method,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isWrite
                ? colors.onTertiaryContainer
                : colors.onSecondaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.response,
    required this.error,
    required this.onCopy,
  });

  final ApiDebugResponse? response;
  final String? error;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = response?.prettyBody ?? error ?? '暂无响应。';
    final hasResult = response != null || error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '响应',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (response != null)
              AppChip(
                label: Text(
                  '${response!.statusCode} · ${response!.elapsedMs} ms',
                ),
              ),
            AppIconButton(
              tooltip: '复制响应',
              onPressed: hasResult ? onCopy : null,
              icon: const AppIcon(Icons.copy_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AppSelectableText(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.35,
                  color: error == null ? null : colors.error,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
