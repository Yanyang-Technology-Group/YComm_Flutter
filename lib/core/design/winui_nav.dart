import 'package:flutter/material.dart';

import 'winui_theme.dart';

class WinuiNavigationItem {
  const WinuiNavigationItem({
    required this.label,
    required this.icon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final String? badge;
}

/// Windows navigation stays at the left; smaller windows collapse to icons.
class WinuiNavigationPane extends StatelessWidget {
  const WinuiNavigationPane({
    super.key,
    required this.index,
    required this.onSelect,
    required this.items,
    required this.expanded,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<WinuiNavigationItem> items;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = winuiTokensOf(context)!;
    return SizedBox(
      width: expanded ? 224 : 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.canvas,
          border: Border(right: BorderSide(color: tokens.stroke)),
        ),
        child: SafeArea(
          right: false,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            children: [
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  child: Text('浏览', style: theme.textTheme.titleSmall),
                ),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _WinuiDestination(
                    key: ValueKey('winui-destination-$i'),
                    item: items[i],
                    selected: index == i,
                    expanded: expanded,
                    onSelect: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinuiDestination extends StatelessWidget {
  const _WinuiDestination({
    super.key,
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onSelect,
  });

  final WinuiNavigationItem item;
  final bool selected, expanded;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = winuiTokensOf(context)!;
    final scheme = theme.colorScheme;
    final icon = Badge(
      isLabelVisible: item.badge != null,
      child: Icon(item.icon, size: 20),
    );
    return Tooltip(
      message: expanded
          ? ''
          : item.badge == null
          ? item.label
          : '${item.label}，${item.badge} 条未读',
      excludeFromSemantics: true,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          TextButton(
            onPressed: onSelect,
            style: ButtonStyle(
              alignment: expanded ? Alignment.centerLeft : Alignment.center,
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(
                  horizontal: expanded ? 12 : 8,
                  vertical: 10,
                ),
              ),
              foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
              backgroundColor: WidgetStatePropertyAll(
                selected ? tokens.hover : Colors.transparent,
              ),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) return tokens.pressed;
                if (states.contains(WidgetState.hovered)) return tokens.hover;
                return Colors.transparent;
              }),
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? BorderSide(color: scheme.primary, width: 2)
                    : BorderSide.none,
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            child: Semantics(
              selected: selected,
              label: item.badge == null
                  ? item.label
                  : '${item.label}，${item.badge} 条未读',
              excludeSemantics: true,
              child: expanded
                  ? Row(
                      children: [
                        Icon(item.icon, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (item.badge != null) ...[
                          const SizedBox(width: 8),
                          Badge(label: Text(item.badge!)),
                        ],
                      ],
                    )
                  : icon,
            ),
          ),
          if (selected)
            PositionedDirectional(
              start: 0,
              width: 3,
              height: 16,
              child: DecoratedBox(
                key: const ValueKey('winui-selection-indicator'),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
