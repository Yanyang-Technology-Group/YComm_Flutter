import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/community_api.dart';
import '../../core/network/api_result.dart';
import '../../core/state/session.dart';
import '../../core/widgets/design.dart';
import '../auth/auth_gate.dart';

class ResourcePage extends ConsumerStatefulWidget {
  const ResourcePage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends ConsumerState<ResourcePage> {
  late Future<Json> future;
  bool downloading = false;
  double? progress;
  String? savedPath;
  CancelToken? cancel;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => future = ref
      .read(communityProvider)
      .get('/downloads/resources/${widget.id}');
  @override
  void dispose() {
    cancel?.cancel();
    super.dispose();
  }

  Future<void> download() async {
    if (downloading || !await requireSession(context, ref) || !mounted) return;
    setState(() {
      downloading = true;
      progress = null;
    });
    cancel = CancelToken();
    File? partial;
    try {
      final response = await ref
          .read(communityProvider)
          .client
          .dio
          .get<ResponseBody>(
            '/downloads/resources/${widget.id}/go',
            options: Options(
              responseType: ResponseType.stream,
              followRedirects: false,
              validateStatus: (_) => true,
            ),
            cancelToken: cancel,
          );
      final body = response.data!;
      if (response.statusCode == 302) {
        await body.stream.drain<void>();
        final location = response.headers.value('location');
        if (location == null) throw const RequestFailure('下载链接暂时不可用');
        if (mounted) {
          await externalLink(
            context,
            Uri.parse(siteOrigin).resolve(location).toString(),
          );
        }
      } else if (response.statusCode == 200 || response.statusCode == 206) {
        final directory = await getApplicationDocumentsDirectory();
        final disposition = response.headers.value('content-disposition') ?? '';
        final encoded = RegExp(
          r"filename\*=UTF-8''([^;]+)",
          caseSensitive: false,
        ).firstMatch(disposition)?.group(1);
        final name =
            (encoded == null
                    ? 'resource-${widget.id}'
                    : Uri.decodeComponent(encoded))
                .replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_');
        partial = File(
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}-$name',
        );
        final sink = partial.openWrite();
        final length =
            int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
        int received = 0;
        try {
          await sink.addStream(
            body.stream.map((chunk) {
              received += chunk.length;
              if (mounted && length > 0) {
                setState(() => progress = received / length);
              }
              return chunk;
            }),
          );
        } finally {
          await sink.close();
        }
        if (mounted) {
          setState(() => savedPath = partial!.path);
          notice(context, '下载完成，已保存到应用文件夹');
        }
      } else {
        final payload = await utf8.decodeStream(body.stream);
        try {
          final result = ApiResult<dynamic>.fromJson(
            Json.from(jsonDecode(payload)),
          );
          throw RequestFailure(result.errorMessage ?? '下载失败', result.code);
        } on FormatException {
          throw RequestFailure('下载失败（${response.statusCode}），请稍后重试');
        }
      }
    } catch (e) {
      if (partial != null && await partial.exists()) await partial.delete();
      if (mounted) {
        notice(
          context,
          e is DioException && CancelToken.isCancel(e) ? '下载已取消' : e,
        );
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  Future<void> extract() async {
    if (!await requireSession(context, ref) || !mounted) return;
    try {
      final data = await ref
          .read(communityProvider)
          .get('/downloads/resources/${widget.id}/extract-code');
      final code = str(data['extractCode']);
      if (code.isNotEmpty) await Clipboard.setData(ClipboardData(text: code));
      if (mounted) notice(context, code.isEmpty ? '此资源没有提取码' : '提取码已复制：$code');
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('资源详情'),
      actions: [
        IconButton(
          tooltip: '复制资源链接',
          onPressed: () => copyLink(context, '/downloads/${widget.id}'),
          icon: const Icon(Icons.ios_share_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: PageWidth(
        child: FutureBuilder<Json>(
          future: future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const LoadingRows();
            }
            if (s.hasError) {
              return ListView(
                children: [
                  ErrorPanel(s.error!, () => setState(reload)),
                  if (ref.watch(sessionProvider).value == null &&
                      s.error is RequestFailure &&
                      [
                        'UNAUTHENTICATED',
                        'FORBIDDEN',
                        '401',
                        '403',
                      ].contains((s.error as RequestFailure).code))
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: OutlinedButton(
                        onPressed: () async {
                          if (await requireSession(context, ref) && mounted) {
                            setState(reload);
                          }
                        },
                        child: const Text('登录后重试'),
                      ),
                    ),
                ],
              );
            }
            final r = Json.from(s.data!['resource']);
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 42,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  str(r['title']),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  str(r['summary'], '来自社区的资源分享'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (str(r['versionLabel']).isNotEmpty)
                      SmallTag(str(r['versionLabel'])),
                    SmallTag('${r['downloadCount'] ?? 0} 次下载'),
                    SmallTag(r['sourceType'] == 'local' ? '文件下载' : '外部资源'),
                  ],
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 28),
                Text('关于这个资源', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                MarkdownContent(
                  str(r['descriptionMd']).isEmpty
                      ? '发布者尚未补充详细介绍。'
                      : str(r['descriptionMd']),
                ),
                const SizedBox(height: 32),
                if (downloading) ...[
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 12),
                  Text(
                    progress == null
                        ? '正在连接下载…'
                        : '已下载 ${(progress! * 100).toStringAsFixed(0)}%',
                  ),
                  TextButton(
                    onPressed: () => cancel?.cancel(),
                    child: const Text('取消下载'),
                  ),
                ],
                FilledButton.icon(
                  onPressed: downloading ? null : download,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    downloading
                        ? '正在下载…'
                        : r['sourceType'] == 'local'
                        ? '下载文件'
                        : '获取资源',
                  ),
                ),
                if (r['sourceType'] != 'local')
                  TextButton(
                    onPressed: downloading ? null : extract,
                    child: const Text('复制提取码'),
                  ),
                if (savedPath != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final result = await OpenFilex.open(savedPath!);
                        if (context.mounted && result.type != ResultType.done) {
                          notice(context, '无法打开文件：${result.message}');
                        }
                      } catch (_) {
                        if (context.mounted) {
                          notice(context, '文件已保存，但没有可用的打开方式');
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('打开已下载文件'),
                  ),
                const SizedBox(height: 16),
                Text(
                  r['sourceType'] == 'local'
                      ? '文件会保存到应用文件夹。'
                      : '获取成功后将在浏览器打开资源地址。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
