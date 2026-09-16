import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

/// Compact GFM rendering for labels, titles and excerpts. Block content is
/// flattened and links inherit the surrounding control's tap action.
class MarkdownText extends StatelessWidget {
  const MarkdownText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parse(data);
    return Text.rich(
      TextSpan(children: _spans(nodes)),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  static const _blocks = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'pre',
    'ul',
    'ol',
    'li',
    'table',
    'thead',
    'tbody',
    'tr',
    'hr',
  };

  List<InlineSpan> _spans(List<md.Node> nodes) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is md.Text) {
        spans.add(TextSpan(text: node.text.replaceAll('\n', ' ')));
        continue;
      }
      if (node is! md.Element) continue;
      if (spans.isNotEmpty && _blocks.contains(node.tag)) {
        spans.add(const TextSpan(text: ' '));
      }
      if (node.tag == 'br') {
        spans.add(const TextSpan(text: ' '));
      } else if (node.tag == 'img') {
        final alt = node.attributes['alt'] ?? '';
        spans.add(TextSpan(text: alt.isEmpty ? '[图片]' : '[图片：$alt]'));
      } else if (node.tag == 'input') {
        spans.add(
          TextSpan(
            text: node.attributes.containsKey('checked') ? '[x] ' : '[ ] ',
          ),
        );
      } else {
        final style = switch (node.tag) {
          'strong' ||
          'h1' ||
          'h2' ||
          'h3' ||
          'h4' ||
          'h5' ||
          'h6' ||
          'th' => const TextStyle(fontWeight: FontWeight.w700),
          'em' => const TextStyle(fontStyle: FontStyle.italic),
          'del' => const TextStyle(decoration: TextDecoration.lineThrough),
          'code' => const TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: ['Noto Sans CJK SC', 'Noto Sans SC', 'Roboto'],
          ),
          _ => null,
        };
        if ((node.tag == 'td' || node.tag == 'th') && spans.isNotEmpty) {
          spans.add(const TextSpan(text: ' | '));
        }
        spans.add(
          TextSpan(style: style, children: _spans(node.children ?? [])),
        );
      }
    }
    return spans;
  }
}
