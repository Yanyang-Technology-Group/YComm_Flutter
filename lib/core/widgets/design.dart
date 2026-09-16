import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/community_api.dart';

const siteOrigin = 'https://community.yanyn.cn';
Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
void notice(BuildContext context, Object message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.toString())));
Future<void> externalLink(BuildContext context, String link) async {
  final uri = Uri.tryParse(link);
  if (uri == null || !['http', 'https'].contains(uri.scheme)) {
    notice(context, '无法打开此链接');
    return;
  }
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      notice(context, '无法打开浏览器');
    }
  } catch (_) {
    if (context.mounted) notice(context, '无法打开浏览器');
  }
}

String dateLabel(dynamic value) {
  final date = DateTime.tryParse(str(value));
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.isNegative || diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${date.year}/${date.month}/${date.day}';
}

class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: child,
    ),
  );
}

class PageIntro extends StatelessWidget {
  const PageIntro(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class StatePanel extends StatelessWidget {
  const StatePanel({
    super.key,
    required this.title,
    this.message = '',
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel(this.error, this.retry, {super.key});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => StatePanel(
    title: '暂时没有加载成功',
    message: error is RequestFailure ? error.toString() : '请检查网络连接，再试一次。',
    icon: Icons.cloud_off_outlined,
    action: OutlinedButton.icon(
      onPressed: retry,
      icon: const Icon(Icons.refresh),
      label: const Text('重新加载'),
    ),
  );
}

class LoadingRows extends StatelessWidget {
  const LoadingRows({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '正在加载',
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 24),
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 120,
                    color: Theme.of(context).colorScheme.outlineVariant
                        .withValues(alpha: .5),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 20,
                    color: Theme.of(context).colorScheme.outlineVariant
                        .withValues(alpha: .35),
                  ),
                  const SizedBox(height: 10),
                  FractionallySizedBox(
                    widthFactor: .7,
                    child: Container(
                      height: 12,
                      color: Theme.of(context).colorScheme.outlineVariant
                          .withValues(alpha: .25),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class SmallTag extends StatelessWidget {
  const SmallTag(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: .6),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    ),
  );
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.name, {super.key, this.size = 32, this.url});
  final String name;
  final double size;
  final String? url;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Text(
        name.isEmpty ? '晏' : name.characters.first,
        style: TextStyle(
          color: scheme.primary,
          fontSize: size * .36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final uri = Uri.tryParse(url ?? '');
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .36),
      child: Container(
        width: size,
        height: size,
        color: scheme.primaryContainer.withValues(alpha: .55),
        child: uri != null && ['http', 'https'].contains(uri.scheme)
            ? Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class MarkdownContent extends StatelessWidget {
  const MarkdownContent(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: text,
    selectable: true,
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
        .copyWith(p: Theme.of(context).textTheme.bodyLarge, blockSpacing: 16),
    onTapLink: (_, href, _) {
      if (href != null) {
        externalLink(context, Uri.parse(siteOrigin).resolve(href).toString());
      }
    },
    imageBuilder: (uri, title, alt) {
      final resolved = Uri.parse(siteOrigin).resolveUri(uri);
      if (!['https', 'http'].contains(resolved.scheme)) {
        return const SizedBox.shrink();
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          resolved.toString(),
          fit: BoxFit.contain,
          errorBuilder: (_, e, s) => const Padding(
            padding: EdgeInsets.all(20),
            child: Text('图片暂时无法加载'),
          ),
        ),
      );
    },
  );
}

Future<void> copyLink(BuildContext context, String path) async {
  await Clipboard.setData(ClipboardData(text: '$siteOrigin$path'));
  if (context.mounted) notice(context, '链接已复制');
}
