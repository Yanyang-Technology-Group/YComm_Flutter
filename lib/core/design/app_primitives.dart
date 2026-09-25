// Theme-aware visual controls. Material implementations are built only when
// the Material style is active; Apple uses Cupertino and basic widgets.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;

import 'apple_chrome.dart';

export 'apple_icons.dart';

bool isApple(BuildContext context) => appleTokensOf(context) != null;

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });
  final PreferredSizeWidget? appBar;
  final Widget? body, bottomNavigationBar;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  @override
  Widget build(BuildContext context) {
    if (!isApple(context)) {
      return m.Scaffold(
        appBar: appBar is AppNavigationBar
            ? m.AppBar(
                title: (appBar as AppNavigationBar).title,
                leading: (appBar as AppNavigationBar).leading,
                actions: (appBar as AppNavigationBar).actions,
              )
            : appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      );
    }
    return CupertinoPageScaffold(
      backgroundColor:
          backgroundColor ?? appleTokensOf(context)!.groupedBackground,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      navigationBar: appBar is AppNavigationBar
          ? (appBar as AppNavigationBar).cupertino(context)
          : null,
      child: Column(
        children: [
          Expanded(child: body ?? const SizedBox.shrink()),
          ?bottomNavigationBar,
        ],
      ),
    );
  }
}

// Named AppBar only inside this library; exported alias avoids an import clash.
class AppNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavigationBar({super.key, this.title, this.leading, this.actions});
  final Widget? title, leading;
  final List<Widget>? actions;
  @override
  Size get preferredSize => const Size.fromHeight(44);
  CupertinoNavigationBar cupertino(BuildContext context) =>
      CupertinoNavigationBar(
        middle: title,
        leading: leading,
        backgroundColor: MediaQuery.highContrastOf(context)
            ? appleTokensOf(context)!.cardBackground
            : appleTokensOf(context)!.materialColor,
        border: null,
        // Custom title widgets and controls are not suitable for hero flights.
        transitionBetweenRoutes: false,
        trailing: actions == null
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions!),
      );
  @override
  Widget build(BuildContext context) => isApple(context)
      ? cupertino(context)
      : m.AppBar(title: title, leading: leading, actions: actions);
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    this.child,
    this.color,
    this.borderRadius,
    this.clipBehavior = Clip.none,
  });
  final Widget? child;
  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final Clip clipBehavior;
  @override
  Widget build(BuildContext context) => !isApple(context)
      ? m.Material(
          color: color,
          borderRadius: borderRadius,
          clipBehavior: clipBehavior,
          child: child,
        )
      : Container(
          clipBehavior: borderRadius == null ? Clip.none : clipBehavior,
          decoration: BoxDecoration(
            color: color ?? appleTokensOf(context)!.cardBackground,
            borderRadius: borderRadius,
          ),
          child: child,
        );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.child,
    this.color,
    this.elevation,
    this.margin,
  });
  final Widget? child;
  final Color? color;
  final double? elevation;
  final EdgeInsetsGeometry? margin;
  @override
  Widget build(BuildContext context) => !isApple(context)
      ? m.Card(color: color, elevation: elevation, margin: margin, child: child)
      : Container(
          margin: margin,
          decoration: BoxDecoration(
            color: color ?? appleTokensOf(context)!.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
}

class AppTap extends StatelessWidget {
  const AppTap({super.key, this.child, this.onTap, this.borderRadius});
  final Widget? child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  @override
  Widget build(BuildContext context) => !isApple(context)
      ? m.InkWell(onTap: onTap, borderRadius: borderRadius, child: child)
      : PressableScale(
          onTap: onTap,
          enabled: onTap != null,
          pressedScale: 1,
          borderRadius: borderRadius,
          child: child ?? const SizedBox.shrink(),
        );
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.contentPadding,
    this.selected = false,
    this.dense = false,
  });
  final Widget? title, subtitle, leading, trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final bool selected, dense;
  @override
  Widget build(BuildContext context) {
    if (!isApple(context)) {
      return m.ListTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        onTap: onTap,
        contentPadding: contentPadding,
        selected: selected,
        dense: dense,
      );
    }
    final theme = m.Theme.of(context);
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: AppTap(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding:
              contentPadding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: selected ? appleTokensOf(context)!.fill : null,
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      DefaultTextStyle(
                        style: theme.textTheme.bodyLarge!,
                        child: title!,
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle(
                        style: theme.textTheme.bodySmall!,
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

enum AppButtonKind { text, filled, outlined, tonal }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.kind = AppButtonKind.text,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final m.ButtonStyle? style;
  final AppButtonKind kind;
  @override
  Widget build(BuildContext context) {
    if (!isApple(context)) {
      return switch (kind) {
        AppButtonKind.text => m.TextButton(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
        AppButtonKind.filled => m.FilledButton(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
        AppButtonKind.outlined => m.OutlinedButton(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
        AppButtonKind.tonal => m.FilledButton.tonal(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
      };
    }
    final states = <WidgetState>{if (onPressed == null) WidgetState.disabled};
    final scheme = m.Theme.of(context).colorScheme;
    if (context.findAncestorWidgetOfExactType<CupertinoAlertDialog>() != null) {
      return CupertinoDialogAction(
        onPressed: onPressed,
        isDefaultAction: kind == AppButtonKind.filled,
        isDestructiveAction:
            style?.foregroundColor?.resolve(states) == scheme.error ||
            style?.backgroundColor?.resolve(states) == scheme.error,
        child: child,
      );
    }
    final filled = kind == AppButtonKind.filled;
    final foreground = onPressed == null
        ? appleTokensOf(context)!.tertiaryLabel
        : style?.foregroundColor?.resolve(states) ??
              (filled ? scheme.onPrimary : scheme.primary);
    final background =
        style?.backgroundColor?.resolve(states) ??
        (filled
            ? scheme.primary
            : kind == AppButtonKind.tonal || kind == AppButtonKind.outlined
            ? scheme.primary.withValues(alpha: .10)
            : null);
    final border = BorderRadius.circular(10);
    final resolvedSize = style?.minimumSize?.resolve(states);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 44,
        minWidth: resolvedSize?.width ?? 44,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: border),
        child: CupertinoButton(
          onPressed: onPressed,
          color: background,
          borderRadius: border,
          padding:
              style?.padding?.resolve(states) ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: IconTheme.merge(
            data: IconThemeData(color: foreground, size: 20),
            child: DefaultTextStyle(
              style:
                  (style?.textStyle?.resolve(states) ??
                          m.Theme.of(context).textTheme.bodyLarge!)
                      .copyWith(
                        color: foreground,
                        fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                      ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style,
  }) : kind = AppButtonKind.text;
  const AppIconButton.filled({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style,
  }) : kind = AppButtonKind.filled;
  const AppIconButton.filledTonal({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style,
  }) : kind = AppButtonKind.tonal;
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final m.ButtonStyle? style;
  final AppButtonKind kind;
  @override
  Widget build(BuildContext context) {
    if (!isApple(context)) {
      return switch (kind) {
        AppButtonKind.filled => m.IconButton.filled(
          icon: icon,
          onPressed: onPressed,
          tooltip: tooltip,
          style: style,
        ),
        AppButtonKind.tonal => m.IconButton.filledTonal(
          icon: icon,
          onPressed: onPressed,
          tooltip: tooltip,
          style: style,
        ),
        _ => m.IconButton(
          icon: icon,
          onPressed: onPressed,
          tooltip: tooltip,
          style: style,
        ),
      };
    }
    final tokens = appleTokensOf(context)!;
    final scheme = m.Theme.of(context).colorScheme;
    final states = <WidgetState>{if (onPressed == null) WidgetState.disabled};
    final foreground = onPressed == null
        ? tokens.tertiaryLabel
        : style?.foregroundColor?.resolve(states) ??
              (kind == AppButtonKind.filled
                  ? scheme.onPrimary
                  : scheme.primary);
    final button = CupertinoButton(
      onPressed: onPressed,
      padding: const EdgeInsets.all(10),
      borderRadius: BorderRadius.circular(22),
      color:
          style?.backgroundColor?.resolve(states) ??
          switch (kind) {
            AppButtonKind.filled => scheme.primary,
            AppButtonKind.tonal => tokens.fill,
            _ => null,
          },
      disabledColor: tokens.fill,
      child: IconTheme.merge(
        data: IconThemeData(color: foreground, size: 22),
        child: icon,
      ),
    );
    return tooltip == null
        ? button
        : AppTooltip(message: tooltip!, child: button);
  }
}

/// A widgets-only tooltip keeps Apple hover feedback free of Material surfaces.
/// Semantics and focus/hover handling remain framework-owned.
class AppTooltip extends StatelessWidget {
  const AppTooltip({super.key, required this.message, required this.child});
  final String message;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!isApple(context)) return m.Tooltip(message: message, child: child);
    return RawTooltip(
      semanticsTooltip: message,
      enableFeedback: false,
      hoverDelay: const Duration(milliseconds: 400),
      tooltipBuilder: (context, animation) => FadeTransition(
        opacity: animation,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: appleTokensOf(context)!.elevatedBackground,
            border: Border.all(color: appleTokensOf(context)!.separator),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              message,
              style: m.Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      child: Semantics(label: message, child: child),
    );
  }
}

class AppProgress extends StatelessWidget {
  const AppProgress({super.key, this.value, this.minHeight, this.color});
  final double? value, minHeight;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    if (!isApple(context)) {
      return m.LinearProgressIndicator(
        value: value,
        minHeight: minHeight,
        color: color,
      );
    }
    if (value == null) {
      return const SizedBox(
        height: 22,
        child: Center(child: CupertinoActivityIndicator(radius: 8)),
      );
    }
    return Semantics(
      label: '进度',
      value: '${(value!.clamp(0, 1) * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: minHeight ?? 4,
          child: ColoredBox(
            color: appleTokensOf(context)!.fill,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value!.clamp(0, 1),
                child: ColoredBox(
                  color: color ?? CupertinoTheme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppSpinner extends StatelessWidget {
  const AppSpinner({super.key, this.strokeWidth = 4, this.color});
  final double strokeWidth;
  final Color? color;
  @override
  Widget build(BuildContext context) => isApple(context)
      ? CupertinoActivityIndicator(color: color)
      : m.CircularProgressIndicator(strokeWidth: strokeWidth, color: color);
}

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.child,
    this.label,
    this.isLabelVisible = true,
    this.backgroundColor,
  });
  final Widget child;
  final Widget? label;
  final bool isLabelVisible;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => !isApple(context)
      ? m.Badge(
          label: label,
          isLabelVisible: isLabelVisible,
          backgroundColor: backgroundColor,
          child: child,
        )
      : Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (isLabelVisible)
              Positioned(
                top: -5,
                right: -10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: backgroundColor ?? CupertinoColors.systemRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: label == null
                        ? const EdgeInsets.all(3)
                        : const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.white,
                      ),
                      child: label ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
          ],
        );
}

class AppDivider extends StatelessWidget {
  const AppDivider({
    super.key,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    this.color,
  });
  final double? height, thickness, indent, endIndent;
  final Color? color;
  @override
  Widget build(BuildContext context) => !isApple(context)
      ? m.Divider(
          height: height,
          thickness: thickness,
          indent: indent,
          endIndent: endIndent,
          color: color,
        )
      : SizedBox(
          height: height ?? 1,
          child: Center(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: indent ?? 0,
                end: endIndent ?? 0,
              ),
              child: SizedBox(
                height: thickness ?? 1 / MediaQuery.devicePixelRatioOf(context),
                child: ColoredBox(
                  color: color ?? appleTokensOf(context)!.separator,
                ),
              ),
            ),
          ),
        );
}

class AppRefresh extends StatelessWidget {
  const AppRefresh({super.key, required this.onRefresh, required this.child});
  final Future<void> Function() onRefresh;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!isApple(context)) {
      return m.RefreshIndicator(onRefresh: onRefresh, child: child);
    }
    // Existing refreshable surfaces all supply a ListView. Reuse its delegate,
    // preserving lazy construction, storage key, controller and scroll padding.
    final list = child as ListView;
    return CustomScrollView(
      key: list.key,
      controller: list.controller,
      primary: list.primary,
      reverse: list.reverse,
      shrinkWrap: list.shrinkWrap,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: onRefresh),
        SliverPadding(
          padding: list.padding ?? EdgeInsets.zero,
          sliver: SliverList(delegate: list.childrenDelegate),
        ),
      ],
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.avatar,
    this.backgroundColor,
  });
  final Widget label;
  final Widget? avatar;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => !isApple(context)
      ? m.Chip(label: label, avatar: avatar, backgroundColor: backgroundColor)
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor ?? appleTokensOf(context)!.fill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatar != null) ...[avatar!, const SizedBox(width: 6)],
              label,
            ],
          ),
        );
}

class AppExpansionTile extends StatefulWidget {
  const AppExpansionTile({
    super.key,
    required this.title,
    this.children = const [],
    this.tilePadding,
  });
  final Widget title;
  final List<Widget> children;
  final EdgeInsetsGeometry? tilePadding;
  @override
  State<AppExpansionTile> createState() => _AppExpansionTileState();
}

class _AppExpansionTileState extends State<AppExpansionTile> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => !isApple(context)
      ? m.ExpansionTile(
          title: widget.title,
          tilePadding: widget.tilePadding,
          children: widget.children,
        )
      : Column(
          children: [
            Semantics(
              expanded: expanded,
              child: AppListTile(
                title: widget.title,
                contentPadding: widget.tilePadding,
                onTap: () => setState(() => expanded = !expanded),
                trailing: Icon(
                  expanded
                      ? CupertinoIcons.chevron_down
                      : CupertinoIcons.chevron_right,
                  size: 16,
                ),
              ),
            ),
            if (expanded) ...widget.children,
          ],
        );
}

class AppTextButton extends AppButton {
  const AppTextButton({
    super.key,
    required super.onPressed,
    required super.child,
    super.style,
  }) : super(kind: AppButtonKind.text);
  AppTextButton.icon({
    super.key,
    required super.onPressed,
    required Widget icon,
    required Widget label,
    super.style,
  }) : super(kind: AppButtonKind.text, child: _buttonLabel(icon, label));
}

class AppFilledButton extends AppButton {
  const AppFilledButton({
    super.key,
    required super.onPressed,
    required super.child,
    super.style,
  }) : super(kind: AppButtonKind.filled);
  AppFilledButton.icon({
    super.key,
    required super.onPressed,
    required Widget icon,
    required Widget label,
    super.style,
  }) : super(kind: AppButtonKind.filled, child: _buttonLabel(icon, label));
  AppFilledButton.tonalIcon({
    super.key,
    required super.onPressed,
    required Widget icon,
    required Widget label,
    super.style,
  }) : super(kind: AppButtonKind.tonal, child: _buttonLabel(icon, label));
}

class AppOutlinedButton extends AppButton {
  const AppOutlinedButton({
    super.key,
    required super.onPressed,
    required super.child,
    super.style,
  }) : super(kind: AppButtonKind.outlined);
  AppOutlinedButton.icon({
    super.key,
    required super.onPressed,
    required Widget icon,
    required Widget label,
    super.style,
  }) : super(kind: AppButtonKind.outlined, child: _buttonLabel(icon, label));
}

Widget _buttonLabel(Widget icon, Widget label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    icon,
    const SizedBox(width: 8),
    Flexible(child: label),
  ],
);
