import '../design/adaptive.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../design/apple_chrome.dart';
import '../design/apple_widgets.dart';
import '../design/tokens.dart';
import '../network/community_api.dart';
import 'markdown_text.dart';

export 'markdown_text.dart';
export '../design/apple_chrome.dart' show AppleSeparator, PressableScale;

const siteOrigin = 'https://community.yanyn.cn';

/// 把服务端返回的图片/资源路径解析成可直接请求的绝对地址。
///
/// 服务端经常返回 `/uploads/images/xxx.png` 这种站内相对路径，直接丢给
/// `Image.network` / `url_launcher` 会解析失败（图片就加载不出来）。
/// 统一在这里补上站点前缀：
///   /uploads/x.png      -> https://community.yanyn.cn/uploads/x.png
///   uploads/x.png       -> https://community.yanyn.cn/uploads/x.png
///   //cdn.x/x.png       -> https://cdn.x/x.png
///   https://x/x.png     -> 原样返回
/// 空串、空白和无法解析的输入返回 null，调用方据此走占位/忽略。
Uri? resolveSiteUrl(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  final parsed = Uri.tryParse(text);
  if (parsed == null) {
    return null;
  }
  return Uri.parse('$siteOrigin/').resolveUri(parsed);
}

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context)
        .push<T>(appPageRoute<T>(context, builder: (_) => page));
void notice(BuildContext context, Object message) =>
    appNotice(context, message);
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

/// 分组小标题（「外观」「关于」这类）。
///
/// 设置页与「我的」都在用，原本各写了一份私有实现，这里统一。
/// Apple 风格下是小号、灰色、**加字距**的全大写式标签——iOS 分组列表用它
/// 在不抢标题层级的前提下把段落分出来。
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    if (tokens == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppleSpacing.gutter + AppleSpacing.row,
        0,
        AppleSpacing.gutter + AppleSpacing.row,
        AppleSpacing.sectionHeader,
      ),
      child: Text(
        // 中文没有大小写，这里靠字距和字重做区分，不强行加英文式大写。
        text,
        style: AppleType.footnote.copyWith(
          color: tokens.secondaryLabel,
          fontFamilyFallback: appleFontFallback,
        ),
      ),
    );
  }
}

class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => appleTokensOf(context) != null
      ? ApplePageWidth(child: child)
      : Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: child,
          ),
        );
}

class PageIntro extends StatelessWidget {
  const PageIntro(this.title, {super.key, this.action, this.markdown = false});
  final String title;
  final Widget? action;
  final bool markdown;
  @override
  Widget build(BuildContext context) {
    if (appleTokensOf(context) != null) {
      return ApplePageIntro(
        title,
        action: action,
        markdown: markdown,
        // 大字标题在 Apple 侧用 34pt 粗体，Markdown 标题也要套同一个样式，
        // 否则带 *** 的标题会比纯文本标题小一圈。
        buildTitle: markdown
            ? (style) => MarkdownText(title, style: style)
            : null,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: markdown
                  ? MarkdownText(
                      title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    )
                  : Text(
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
  Widget build(BuildContext context) => appleTokensOf(context) != null
      ? AppleStatePanel(
          title: title,
          message: message,
          icon: icon,
          action: action,
        )
      : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                icon,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
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
    action: AppOutlinedButton.icon(
      onPressed: retry,
      icon: const AppIcon(Icons.refresh),
      label: const Text('重新加载'),
    ),
  );
}

class LoadingRows extends StatelessWidget {
  const LoadingRows({super.key});
  @override
  Widget build(BuildContext context) => appleTokensOf(context) != null
      ? const AppleLoadingRows()
      : Semantics(
          label: '正在加载',
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const AppProgress(minHeight: 2),
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
  const SmallTag(this.text, {super.key, this.markdown = false});
  final String text;
  final bool markdown;
  @override
  Widget build(BuildContext context) {
    if (appleTokensOf(context) != null) {
      return AppleSmallTag(
        text,
        buildChild: markdown
            ? (style) => MarkdownText(text, style: style)
            : null,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer
            .withValues(alpha: .6),
        borderRadius: BorderRadius.circular(7),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        child: markdown ? MarkdownText(text) : Text(text),
      ),
    );
  }
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
    final raw = url?.trim() ?? '';
    final uri = resolveSiteUrl(raw);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * (isApple(context) ? .5 : .36)),
      child: Container(
        width: size,
        height: size,
        color: scheme.primaryContainer.withValues(alpha: .55),
        child: uri != null && ['http', 'https'].contains(uri.scheme)
            ? Image.network(
                uri.toString(),
                key: ValueKey(uri.toString()),
                semanticLabel: '$name 的头像',
                fit: BoxFit.cover,
                frameBuilder: (_, child, frame, sync) =>
                    frame == null ? fallback : child,
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
  Widget build(BuildContext context) => AppSelection(
    child: MarkdownBody(
      data: text,
      selectable: appleTokensOf(context) == null,
      checkboxBuilder: appleTokensOf(context) == null
          ? null
          : (checked) => Semantics(
              checked: checked,
              child: AppIcon(
                checked
                    ? Icons.check_circle_outline
                    : Icons.crop_square_rounded,
                size: 18,
              ),
            ),
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: Theme.of(context).textTheme.bodyLarge,
        a: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        checkbox: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 18,
        ),
        code: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontFamily: 'monospace',
          fontFamilyFallback: const [
            'Noto Sans CJK SC',
            'Noto Sans SC',
            'Roboto',
          ],
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockSpacing: 16,
        tableColumnWidth: const IntrinsicColumnWidth(),
      ),
      onTapLink: (_, href, _) {
        if (href != null) {
          final uri = Uri.tryParse(href);
          if (uri == null) {
            notice(context, '无法打开此链接');
            return;
          }
          externalLink(
            context,
            Uri.parse(siteOrigin).resolveUri(uri).toString(),
          );
        }
      },
      imageBuilder: (uri, title, alt) {
        final resolved = resolveSiteUrl(uri.toString());
        if (resolved == null || !['https', 'http'].contains(resolved.scheme)) {
          return const SizedBox.shrink();
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            resolved.toString(),
            semanticLabel: alt,
            fit: BoxFit.contain,
            errorBuilder: (_, e, s) => const Padding(
              padding: EdgeInsets.all(20),
              child: Text('图片暂时无法加载'),
            ),
          ),
        );
      },
    ),
  );
}

Future<void> copyLink(BuildContext context, String path) async {
  await Clipboard.setData(ClipboardData(text: '$siteOrigin$path'));
  if (context.mounted) notice(context, '链接已复制');
}
