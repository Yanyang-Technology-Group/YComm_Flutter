import 'package:flutter/cupertino.dart' as c;
import 'package:flutter/material.dart' as m;

import 'apple_chrome.dart';

class AppAlertDialog extends m.StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.scrollable = false,
    this.insetPadding,
  });
  final m.Widget? title, content;
  final List<m.Widget>? actions;
  final bool scrollable;
  final m.EdgeInsets? insetPadding;
  @override
  m.Widget build(m.BuildContext context) => appleTokensOf(context) == null
      ? m.AlertDialog(
          title: title,
          content: content,
          actions: actions,
          scrollable: scrollable,
          insetPadding: insetPadding,
        )
      : c.CupertinoAlertDialog(
          title: title,
          content: content,
          actions: actions ?? const [],
        );
}

class AppDialog extends m.StatelessWidget {
  const AppDialog({super.key, this.child, this.insetPadding});
  final m.Widget? child;
  final m.EdgeInsets? insetPadding;
  @override
  m.Widget build(m.BuildContext context) {
    if (appleTokensOf(context) == null) {
      return m.Dialog(insetPadding: insetPadding, child: child);
    }
    final tokens = appleTokensOf(context)!;
    final padding =
        insetPadding ??
        const c.EdgeInsets.symmetric(horizontal: 24, vertical: 24);
    return c.SafeArea(
      child: c.Padding(
        padding: padding.add(
          c.EdgeInsets.only(bottom: c.MediaQuery.viewInsetsOf(context).bottom),
        ),
        child: c.LayoutBuilder(
          builder: (context, constraints) => c.SingleChildScrollView(
            child: c.ConstrainedBox(
              constraints: c.BoxConstraints(minHeight: constraints.maxHeight),
              child: c.Center(
                child: c.ConstrainedBox(
                  constraints: const c.BoxConstraints(maxWidth: 480),
                  child: c.DecoratedBox(
                    decoration: c.BoxDecoration(
                      color: tokens.elevatedBackground,
                      borderRadius: c.BorderRadius.circular(14),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppSimpleDialog extends m.StatelessWidget {
  const AppSimpleDialog({super.key, this.title, this.children});
  final m.Widget? title;
  final List<m.Widget>? children;
  @override
  m.Widget build(m.BuildContext context) => appleTokensOf(context) == null
      ? m.SimpleDialog(title: title, children: children)
      : c.CupertinoAlertDialog(title: title, actions: children ?? const []);
}

class AppSimpleDialogOption extends m.StatelessWidget {
  const AppSimpleDialogOption({super.key, required this.onPressed, this.child});
  final m.VoidCallback? onPressed;
  final m.Widget? child;
  @override
  m.Widget build(m.BuildContext context) => appleTokensOf(context) == null
      ? m.SimpleDialogOption(onPressed: onPressed, child: child)
      : c.CupertinoDialogAction(
          onPressed: onPressed,
          child: child ?? const c.SizedBox.shrink(),
        );
}

Future<T?> appShowDialog<T>({
  required m.BuildContext context,
  required m.WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  bool useRootNavigator = true,
  m.RouteSettings? routeSettings,
}) {
  if (appleTokensOf(context) == null) {
    return m.showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
    );
  }
  if (m.MediaQuery.disableAnimationsOf(context)) {
    return m.showGeneralDialog<T>(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          c.FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 120),
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel ?? 'Dismiss',
      barrierColor: const m.Color(0x66000000),
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
    );
  }
  return c.showCupertinoDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
  );
}

Future<T?> appShowModalBottomSheet<T>({
  required m.BuildContext context,
  required m.WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  m.Color? backgroundColor,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  if (appleTokensOf(context) == null) {
    return m.showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      backgroundColor: backgroundColor,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    );
  }
  final tokens = appleTokensOf(context)!;
  return appShowCupertinoPopup<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    builder: (popupContext) => c.Align(
      alignment: c.Alignment.bottomCenter,
      child: c.Container(
        width: double.infinity,
        decoration: c.BoxDecoration(
          color: backgroundColor ?? tokens.elevatedBackground,
          borderRadius: const c.BorderRadius.vertical(
            top: c.Radius.circular(16),
          ),
        ),
        child: c.SafeArea(top: false, child: builder(popupContext)),
      ),
    ),
  );
}

/// Contextual actions expand from the control that owns them. Cupertino owns
/// the interruptible opening/closing spring and the platform Reduce Motion path.
class AppPopupMenuButton<T> extends m.StatefulWidget {
  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.enabled = true,
    this.tooltip,
    this.icon,
    this.child,
    this.initialValue,
    this.destructiveValues = const {},
  });
  final Set<T> destructiveValues;
  final m.PopupMenuItemBuilder<T> itemBuilder;
  final m.PopupMenuItemSelected<T>? onSelected;
  final bool enabled;
  final String? tooltip;
  final m.Widget? icon, child;
  final T? initialValue;

  @override
  m.State<AppPopupMenuButton<T>> createState() => _AppPopupMenuButtonState<T>();
}

class _AppPopupMenuButtonState<T> extends m.State<AppPopupMenuButton<T>> {
  final _focus = c.FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  m.Widget build(m.BuildContext context) {
    if (appleTokensOf(context) == null) {
      return m.PopupMenuButton<T>(
        itemBuilder: widget.itemBuilder,
        onSelected: widget.onSelected,
        enabled: widget.enabled,
        tooltip: widget.tooltip,
        icon: widget.icon,
        initialValue: widget.initialValue,
        child: widget.child,
      );
    }
    return c.CupertinoMenuAnchor(
      childFocusNode: _focus,
      consumeOutsideTaps: true,
      enableSwipe: widget.enabled,
      constrainCrossAxis: true,
      constraints: c.BoxConstraints(
        minWidth: 200,
        maxWidth: (c.MediaQuery.sizeOf(context).width - 32).clamp(
          200,
          280 * c.MediaQuery.textScalerOf(context).scale(1),
        ),
      ),
      menuChildren: [
        for (final entry in widget.itemBuilder(context))
          if (entry is m.PopupMenuItem<T>)
            c.CupertinoMenuItem(
              isDestructiveAction: widget.destructiveValues.contains(
                entry.value,
              ),
              onPressed: !entry.enabled
                  ? null
                  : () {
                      entry.onTap?.call();
                      final value = entry.value;
                      if (value != null) widget.onSelected?.call(value);
                    },
              leading: entry is m.CheckedPopupMenuItem<T> && entry.checked
                  ? const c.Icon(c.CupertinoIcons.check_mark, size: 17)
                  : null,
              child: c.Semantics(
                selected: widget.initialValue != null
                    ? entry.represents(widget.initialValue)
                    : null,
                child: entry.child ?? const c.SizedBox.shrink(),
              ),
            )
          else if (entry is m.PopupMenuDivider)
            const c.CupertinoMenuDivider(),
      ],
      builder: (context, controller, child) => c.Semantics(
        label: widget.tooltip,
        button: true,
        enabled: widget.enabled,
        child: c.CupertinoButton(
          focusNode: _focus,
          padding: widget.child == null
              ? const c.EdgeInsets.all(8)
              : c.EdgeInsets.zero,
          onPressed: !widget.enabled
              ? null
              : controller.isOpen
              ? controller.close
              : controller.open,
          child:
              widget.child ??
              widget.icon ??
              const c.Icon(c.CupertinoIcons.ellipsis, size: 22),
        ),
      ),
    );
  }
}

Future<T?> appShowCupertinoPopup<T>({
  required m.BuildContext context,
  required m.WidgetBuilder builder,
  bool useRootNavigator = true,
  bool barrierDismissible = true,
}) {
  if (m.MediaQuery.disableAnimationsOf(context)) {
    return m.showGeneralDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: const m.Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 120),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          c.FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, animation, secondaryAnimation) =>
          c.Align(alignment: c.Alignment.bottomCenter, child: builder(context)),
    );
  }
  return c.showCupertinoModalPopup<T>(
    context: context,
    builder: builder,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
  );
}

Future<DateTime?> appShowDatePicker({
  required m.BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime initialDate,
}) {
  if (appleTokensOf(context) == null) {
    return m.showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );
  }
  DateTime selected = initialDate.isBefore(firstDate)
      ? firstDate
      : initialDate.isAfter(lastDate)
      ? lastDate
      : initialDate;
  return appShowCupertinoPopup<DateTime>(
    context: context,
    builder: (popupContext) => _pickerSheet(
      popupContext,
      c.CupertinoDatePicker(
        mode: c.CupertinoDatePickerMode.date,
        initialDateTime: selected,
        minimumDate: firstDate,
        maximumDate: lastDate,
        onDateTimeChanged: (value) => selected = value,
      ),
      onDone: () => c.Navigator.pop(popupContext, selected),
    ),
  );
}

Future<m.TimeOfDay?> appShowTimePicker({
  required m.BuildContext context,
  required m.TimeOfDay initialTime,
}) {
  if (appleTokensOf(context) == null) {
    return m.showTimePicker(context: context, initialTime: initialTime);
  }
  var selected = initialTime;
  final now = DateTime.now();
  return appShowCupertinoPopup<m.TimeOfDay>(
    context: context,
    builder: (popupContext) => _pickerSheet(
      popupContext,
      c.CupertinoDatePicker(
        mode: c.CupertinoDatePickerMode.time,
        initialDateTime: DateTime(
          now.year,
          now.month,
          now.day,
          selected.hour,
          selected.minute,
        ),
        use24hFormat: m.MediaQuery.alwaysUse24HourFormatOf(context),
        onDateTimeChanged: (value) =>
            selected = m.TimeOfDay(hour: value.hour, minute: value.minute),
      ),
      onDone: () => c.Navigator.pop(popupContext, selected),
    ),
  );
}

m.Widget _pickerSheet(
  m.BuildContext context,
  m.Widget picker, {
  required m.VoidCallback onDone,
}) {
  final tokens = appleTokensOf(context)!;
  return c.Align(
    alignment: c.Alignment.bottomCenter,
    child: c.Container(
      color: tokens.elevatedBackground,
      child: c.SafeArea(
        top: false,
        child: c.Column(
          mainAxisSize: c.MainAxisSize.min,
          children: [
            c.Row(
              mainAxisAlignment: c.MainAxisAlignment.end,
              children: [
                c.CupertinoButton(
                  onPressed: () => c.Navigator.pop(context),
                  child: const c.Text('取消'),
                ),
                c.CupertinoButton(onPressed: onDone, child: const c.Text('完成')),
              ],
            ),
            c.SizedBox(height: 216, child: picker),
          ],
        ),
      ),
    ),
  );
}
