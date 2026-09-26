import 'adaptive.dart';

import 'package:flutter/material.dart';

import 'apple_chrome.dart';
import 'tokens.dart';

/// Compact floating navigation. Selection is visible by shape and symbol,
/// while high-frequency destination switches keep their content stationary.
class AppleTabBar extends StatefulWidget {
  const AppleTabBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<AppleTabItem> items;

  /// 标签栏内容高度（不含安全区）。
  static const height = 60.0;

  static double heightOf(BuildContext context) =>
      42 + MediaQuery.textScalerOf(context).scale(13);

  @override
  State<AppleTabBar> createState() => _AppleTabBarState();
}

class AppleTabItem {
  const AppleTabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badge,
  });
  final String label;
  final IconData icon, selectedIcon;

  /// 未读数等角标文案，为空时不显示。
  final String? badge;
}

class _AppleTabBarState extends State<AppleTabBar> {
  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    if (tokens == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000)
                .withValues(alpha: tokens.isDark ? .24 : .10),
            blurRadius: 24,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: TranslucentBar(
          blur: 24,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: SizedBox(
              height: AppleTabBar.heightOf(context) - 10,
              child: Row(
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    Expanded(
                      child: _AppleTabButton(
                        item: widget.items[i],
                        selected: i == widget.index,
                        onTap: () => widget.onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppleTabButton extends StatelessWidget {
  const _AppleTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppleTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = appleTokensOf(context);
    final color = selected
        ? scheme.primary
        : (tokens?.secondaryLabel ?? scheme.onSurfaceVariant);
    final icon = AppBadge(
      isLabelVisible: item.badge != null,
      label: Text(item.badge ?? ''),
      backgroundColor: const Color(0xFFFF3B30), // iOS 系统红，角标专用
      child: AppIcon(selected ? item.selectedIcon : item.icon, size: 26),
    );
    return PressableScale(
      onTap: onTap,
      pressedScale: 1,
      pressedColor: tokens?.fill,
      borderRadius: BorderRadius.circular(27),
      child: Semantics(
        button: true,
        selected: selected,
        label: item.badge == null
            ? item.label
            : '${item.label}，${item.badge} 条未读',
        excludeSemantics: true,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: selected ? tokens?.fill : null,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: color),
                child: icon,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: AppleType.caption2.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontFamilyFallback: appleFontFallback,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 宽屏侧边栏（macOS 那种）。
///
/// 不是 Material 的 NavigationRail：材质更重（大面积该更厚，技能第 12 条），
/// 选中项是整行填充 + 强调色文字，而不是左侧一条指示条。
class AppleSidebar extends StatelessWidget {
  const AppleSidebar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<AppleTabItem> items;

  static const width = 244.0;

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    if (tokens == null) return const SizedBox.shrink();
    return SizedBox(
      width: width,
      child: TranslucentBar(
        blur: 30,
        edge: TranslucentEdge.none,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: tokens.separator,
                width: hairlineOf(context),
              ),
            ),
          ),
          child: SafeArea(
            right: false,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppleSpacing.sm,
                vertical: AppleSpacing.md,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
                  child: Text(
                    '晏阳社区',
                    style: appleFont(AppleType.title3).copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    '浏览',
                    style: appleFont(AppleType.footnote)
                        .copyWith(color: tokens.secondaryLabel),
                  ),
                ),
                for (var i = 0; i < items.length; i++)
                  _AppleSidebarRow(
                    item: items[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppleSidebarRow extends StatelessWidget {
  const _AppleSidebarRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppleTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = appleTokensOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: PressableScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppleRadius.control),
        pressedScale: 1,
        child: Semantics(
          selected: selected,
          button: true,
          label: item.badge == null
              ? item.label
              : '${item.label}，${item.badge} 条未读',
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? scheme.primary.withValues(alpha: .12) : null,
              borderRadius: BorderRadius.circular(AppleRadius.control),
            ),
            child: Row(
              children: [
                AppIcon(
                  selected ? item.selectedIcon : item.icon,
                  size: 20,
                  color: selected
                      ? scheme.primary
                      : (tokens?.secondaryLabel ?? scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppleType.subheadline.copyWith(
                      color: selected
                          ? scheme.primary
                          : (tokens?.secondaryLabel ?? scheme.onSurfaceVariant),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      fontFamilyFallback: appleFontFallback,
                    ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(AppleRadius.chip),
                    ),
                    child: Text(
                      item.badge!,
                      style: AppleType.caption2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontFamilyFallback: appleFontFallback,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
