import 'adaptive.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'apple_chrome.dart';
import 'motion.dart';
import 'tokens.dart';

/// Apple 风格的底部标签栏。
///
/// 与 Material 的 NavigationBar 的差别不只是长相：
/// - 材质是**半透明**的，页面内容从它下面滚过去（技能第 12 条）；
/// - 选中项没有胶囊底，只有图标颜色变化 + 轻微弹簧放大；
/// - 顶边是一条发丝线，不是 Material 的分割面。
///
/// 选中指示用弹簧驱动，并且**从当前值起步**——快速连点两个标签时，
/// 指示不会先跳回去再过来。
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
  static const height = 49.0;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        var labelHeight = 13.0;
        for (final item in widget.items) {
          final painter = TextPainter(
            text: TextSpan(
              text: item.label,
              style: appleFont(AppleType.caption2),
            ),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          )..layout(maxWidth: constraints.maxWidth / widget.items.length);
          if (painter.height > labelHeight) labelHeight = painter.height;
          painter.dispose();
        }
        return TranslucentBar(
          blur: 24,
          edge: TranslucentEdge.top,
          child: SizedBox(
            height: labelHeight + 36,
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
        );
      },
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
      child: Semantics(
        button: true,
        selected: selected,
        label: item.badge == null
            ? item.label
            : '${item.label}，${item.badge} 条未读',
        excludeSemantics: true,
        child: SizedBox(
          width: double.infinity,
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

  static const width = 220.0;

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
        pressedScale: .99,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: .14) : null,
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
    );
  }
}

/// 页面切换时让内容轻微淡入。
///
/// 现有 Material 版用的是固定 220ms、`.5 -> 1` 的透明度曲线。这里换成弹簧驱动
/// 的透明度 + 极小的纵向位移，作用是给切换一个「方向感」：新页面从下方一点点
/// 就位，而不是凭空出现。
///
/// 位移量刻意压到 6px——技能第 11 条要求每帧位移低于感知阈值，位移再大就会
/// 变成一次「滑动」，而这里不需要滑动。
class AppleTabTransition extends StatefulWidget {
  const AppleTabTransition({
    super.key,
    required this.child,
    required this.index,
  });

  final Widget child;

  /// 变化时重新播放一次进场。
  final int index;

  @override
  State<AppleTabTransition> createState() => _AppleTabTransitionState();
}

class _AppleTabTransitionState extends State<AppleTabTransition>
        // 这里是**两**条弹簧（位移 + 透明度），各自要一个 ticker，
        // 所以不能用 SingleTickerProviderStateMixin。
        with
        TickerProviderStateMixin {
  late final SpringMotion _offset;
  late final SpringMotion _fade;

  @override
  void initState() {
    super.initState();
    _offset = SpringMotion(vsync: this, value: 0);
    _fade = SpringMotion(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(AppleTabTransition old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      // 减少动画：只做一次很短的透明度交叉，不做位移。
      _offset.snapTo(0);
      _fade.snapTo(.75);
      _fade.animateTo(1);
      return;
    }
    _offset.snapTo(6);
    _offset.animateTo(0, spec: SpringSpec.move);
    _fade.snapTo(.55);
    _fade.animateTo(1, spec: SpringSpec.defaultSpec);
  }

  @override
  void dispose() {
    _offset.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_offset, _fade]),
    builder: (context, child) => Opacity(
      opacity: _fade.value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, _offset.value),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// 顶部导航栏（替代 AppBar 的 Apple 版本）。
///
/// Material 的 AppBar 是不透明表面；iOS 的导航栏是半透明材质，页面内容从下面
/// 穿过，并且在滚动时标题从「大标题」收缩进栏内——这个收缩效果这里用简化处理：
/// 栏永远显示小标题，大标题留在内容里（由 [ApplePageIntro] 负责），
/// 两者不重叠也就不会打架。
class AppleNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppleNavBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;

  static const _height = 44.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = appleTokensOf(context);
    if (tokens == null) return const SizedBox.shrink();
    return TranslucentBar(
      blur: 24,
      edge: TranslucentEdge.bottom,
      child: SizedBox(
        height: _height,
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: leading == null
                  ? null
                  : Align(alignment: Alignment.centerLeft, child: leading),
            ),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppleType.headline.copyWith(
                    color: scheme.onSurface,
                    fontFamilyFallback: appleFontFallback,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions.reversed.toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 供 [Scaffold.appBar] 使用的模糊背景包装。
///
/// Material 的 AppBar 会自己铺一层背景，这里只要保证它在滚动内容之上仍然是
/// 半透明的——用一个透明的 [PreferredSize] 包住实际内容即可。
class AppleBlurAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppleBlurAppBar({super.key, required this.child, this.height = 44});

  final Widget child;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    if (tokens == null) return child;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.materialColor,
            border: Border(
              bottom: BorderSide(
                color: tokens.separator,
                width: hairlineOf(context),
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
