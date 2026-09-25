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

class AppPopupMenuButton<T> extends m.StatelessWidget {
  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.enabled = true,
    this.tooltip,
    this.icon,
    this.child,
    this.initialValue,
  });
  final m.PopupMenuItemBuilder<T> itemBuilder;
  final m.PopupMenuItemSelected<T>? onSelected;
  final bool enabled;
  final String? tooltip;
  final m.Widget? icon, child;
  final T? initialValue;
  @override
  m.Widget build(m.BuildContext context) {
    if (appleTokensOf(context) == null) {
      return m.PopupMenuButton<T>(
        itemBuilder: itemBuilder,
        onSelected: onSelected,
        enabled: enabled,
        tooltip: tooltip,
        icon: icon,
        initialValue: initialValue,
        child: child,
      );
    }
    return c.Semantics(
      label: tooltip,
      button: true,
      enabled: enabled,
      child: c.CupertinoButton(
        padding: child == null ? const c.EdgeInsets.all(8) : c.EdgeInsets.zero,
        onPressed: !enabled
            ? null
            : () async {
                final entries = itemBuilder(context);
                final value = await appShowCupertinoPopup<T>(
                  context: context,
                  builder: (popupContext) => c.CupertinoActionSheet(
                    actions: [
                      for (final entry in entries)
                        if (entry is m.PopupMenuItem<T>)
                          if (entry.enabled)
                            c.CupertinoActionSheetAction(
                              onPressed: () =>
                                  c.Navigator.pop(popupContext, entry.value),
                              child: entry.child ?? const c.SizedBox.shrink(),
                            )
                          else
                            c.MergeSemantics(
                              child: c.Semantics(
                                button: true,
                                enabled: false,
                                child: c.CupertinoButton(
                                  onPressed: null,
                                  child:
                                      entry.child ?? const c.SizedBox.shrink(),
                                ),
                              ),
                            ),
                    ],
                    cancelButton: c.CupertinoActionSheetAction(
                      onPressed: () => c.Navigator.pop(popupContext),
                      child: const c.Text('取消'),
                    ),
                  ),
                );
                if (value != null) onSelected?.call(value);
              },
        child:
            child ?? icon ?? const c.Icon(c.CupertinoIcons.ellipsis, size: 22),
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
