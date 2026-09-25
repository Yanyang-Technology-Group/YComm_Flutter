import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import 'apple_chrome.dart';
import 'tokens.dart';

/// A single, anchored choice menu for variable-length categories and boards.
/// Short, fixed peer views use a segmented control instead.
class AppleChoiceMenu<T extends Object> extends StatefulWidget {
  const AppleChoiceMenu({
    super.key,
    required this.value,
    required this.choices,
    required this.onChanged,
    required this.semanticLabel,
  });

  final T value;
  final Map<T, Widget> choices;
  final ValueChanged<T> onChanged;
  final String semanticLabel;

  @override
  State<AppleChoiceMenu<T>> createState() => _AppleChoiceMenuState<T>();
}

class _AppleChoiceMenuState<T extends Object>
    extends State<AppleChoiceMenu<T>> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoMenuAnchor(
      childFocusNode: _focus,
      consumeOutsideTaps: true,
      constrainCrossAxis: true,
      constraints: BoxConstraints(
        minWidth: 220,
        maxWidth: (MediaQuery.sizeOf(context).width - 32).clamp(
          220,
          280 * MediaQuery.textScalerOf(context).scale(1),
        ),
      ),
      menuChildren: [
        for (final entry in widget.choices.entries)
          CupertinoMenuItem(
            leading: entry.key == widget.value
                ? const Icon(CupertinoIcons.check_mark, size: 17)
                : const SizedBox(width: 17),
            onPressed: () => widget.onChanged(entry.key),
            child: DefaultTextStyle(
              style: theme.textTheme.bodyLarge!,
              child: Semantics(
                selected: entry.key == widget.value,
                child: entry.value,
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => Semantics(
        label: widget.semanticLabel,
        child: CupertinoButton(
          focusNode: _focus,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.centerLeft,
          onPressed: controller.isOpen ? controller.close : controller.open,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: DefaultTextStyle(
                  style: theme.textTheme.titleMedium!.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  child:
                      widget.choices[widget.value] ?? const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.chevron_down,
                size: 13,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigation is a whole row with a disclosure indicator, not a primary action.
class AppleDisclosureRow extends StatelessWidget {
  const AppleDisclosureRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.detail,
  });
  final Widget leading, title, subtitle;
  final Widget? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = appleTokensOf(context)!;
    return MergeSemantics(
      child: PressableScale(
        onTap: onTap,
        pressedScale: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle(
                      style: theme.textTheme.titleLarge!,
                      child: title,
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 3),
                      DefaultTextStyle(
                        style: theme.textTheme.bodySmall!,
                        child: detail!,
                      ),
                    ],
                    const SizedBox(height: 5),
                    DefaultTextStyle(
                      style: appleFont(AppleType.subheadline)
                          .copyWith(color: tokens.secondaryLabel),
                      child: subtitle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                CupertinoIcons.chevron_forward,
                color: tokens.tertiaryLabel,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
