import 'package:flutter/cupertino.dart' as c;
import 'package:flutter/material.dart' as m;

import 'apple_chrome.dart';
import 'adaptive_overlays.dart' show appShowCupertinoPopup;

c.Widget _appleField(
  m.BuildContext context, {
  required m.TextEditingController? controller,
  required m.FocusNode? focusNode,
  required m.InputDecoration decoration,
  required bool enabled,
  required bool obscureText,
  required bool autofocus,
  required bool autocorrect,
  required bool enableSuggestions,
  required m.TextInputType? keyboardType,
  required m.TextInputAction? textInputAction,
  required m.TextCapitalization textCapitalization,
  required int? maxLength,
  required int? minLines,
  required int? maxLines,
  required m.TextStyle? style,
  required Iterable<String>? autofillHints,
  required m.ValueChanged<String>? onChanged,
  required m.ValueChanged<String>? onSubmitted,
  String? errorText,
}) {
  final tokens = appleTokensOf(context)!;
  final effectiveError = errorText ?? decoration.errorText;
  final helper = effectiveError ?? decoration.helperText;
  return c.Column(
    crossAxisAlignment: c.CrossAxisAlignment.start,
    mainAxisSize: c.MainAxisSize.min,
    children: [
      if (decoration.labelText != null) ...[
        c.Text(
          decoration.labelText!,
          style: c.TextStyle(fontSize: 13, color: tokens.secondaryLabel),
        ),
        const c.SizedBox(height: 6),
      ],
      c.Semantics(
        label: decoration.labelText,
        child: c.CupertinoTextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled && decoration.enabled,
          obscureText: obscureText,
          autofocus: autofocus,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: maxLines,
          style: style,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          placeholder: decoration.hintText,
          placeholderStyle: m.Theme.of(context).textTheme.bodyLarge!
              .copyWith(color: tokens.tertiaryLabel),
          prefix: decoration.prefixIcon == null || decoration.labelText != null
              ? null
              : c.Padding(
                  padding: const c.EdgeInsets.only(left: 10),
                  child: decoration.prefixIcon,
                ),
          suffix: decoration.suffixIcon == null
              ? null
              : c.Padding(
                  padding: const c.EdgeInsets.only(right: 6),
                  child: decoration.suffixIcon,
                ),
          padding:
              decoration.contentPadding ??
              const c.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: c.BoxDecoration(
            color: tokens.cardBackground,
            borderRadius: decoration.border is m.OutlineInputBorder
                ? (decoration.border! as m.OutlineInputBorder).borderRadius
                : c.BorderRadius.circular(9),
            border:
                effectiveError != null ||
                    c.MediaQuery.highContrastOf(context) ||
                    decoration.border is m.OutlineInputBorder
                ? c.Border.all(
                    color: effectiveError == null
                        ? tokens.separator
                        : m.Theme.of(context).colorScheme.error,
                  )
                : null,
          ),
        ),
      ),
      if (helper != null) ...[
        const c.SizedBox(height: 5),
        c.Text(
          helper,
          style: c.TextStyle(
            fontSize: 12,
            color: effectiveError == null
                ? tokens.secondaryLabel
                : m.Theme.of(context).colorScheme.error,
          ),
        ),
      ],
      if (maxLength != null &&
          controller != null &&
          decoration.counterText != '')
        c.Align(
          alignment: c.Alignment.centerRight,
          child: c.ValueListenableBuilder<m.TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => c.Text(
              '${value.text.characters.length}/$maxLength',
              style: c.TextStyle(fontSize: 12, color: tokens.secondaryLabel),
            ),
          ),
        ),
    ],
  );
}

class AppTextField extends m.StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const m.InputDecoration(),
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = m.TextCapitalization.none,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    this.style,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });
  final m.TextEditingController? controller;
  final m.FocusNode? focusNode;
  final m.InputDecoration decoration;
  final bool enabled, obscureText, autofocus, autocorrect, enableSuggestions;
  final m.TextInputType? keyboardType;
  final m.TextInputAction? textInputAction;
  final m.TextCapitalization textCapitalization;
  final int? maxLength, minLines, maxLines;
  final m.TextStyle? style;
  final Iterable<String>? autofillHints;
  final m.ValueChanged<String>? onChanged, onSubmitted;
  @override
  m.Widget build(m.BuildContext context) => appleTokensOf(context) == null
      ? m.TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: decoration,
          enabled: enabled,
          obscureText: obscureText,
          autofocus: autofocus,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: maxLines,
          style: style,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        )
      : _appleField(
          context,
          controller: controller,
          focusNode: focusNode,
          decoration: decoration,
          enabled: enabled,
          obscureText: obscureText,
          autofocus: autofocus,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: maxLines,
          style: style,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        );
}

class AppTextFormField extends m.StatefulWidget {
  const AppTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.decoration = const m.InputDecoration(),
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = m.TextCapitalization.none,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    this.style,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.onSaved,
    this.autovalidateMode,
  });
  final m.TextEditingController? controller;
  final m.FocusNode? focusNode;
  final String? initialValue;
  final m.InputDecoration decoration;
  final bool enabled, obscureText, autofocus, autocorrect, enableSuggestions;
  final m.TextInputType? keyboardType;
  final m.TextInputAction? textInputAction;
  final m.TextCapitalization textCapitalization;
  final int? maxLength, minLines, maxLines;
  final m.TextStyle? style;
  final Iterable<String>? autofillHints;
  final m.ValueChanged<String>? onChanged, onFieldSubmitted;
  final m.FormFieldValidator<String>? validator;
  final m.FormFieldSetter<String>? onSaved;
  final m.AutovalidateMode? autovalidateMode;
  @override
  m.State<AppTextFormField> createState() => _AppTextFormFieldState();
}

class _AppTextFormFieldState extends m.State<AppTextFormField> {
  late m.TextEditingController _controller;
  bool _ownsController = false;
  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? m.TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(AppTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _ownsController = widget.controller == null;
      _controller =
          widget.controller ??
          m.TextEditingController(text: widget.initialValue);
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  m.Widget build(m.BuildContext context) {
    if (appleTokensOf(context) == null) {
      return m.TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        initialValue: widget.controller == null ? widget.initialValue : null,
        decoration: widget.decoration,
        enabled: widget.enabled,
        obscureText: widget.obscureText,
        autofocus: widget.autofocus,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        maxLength: widget.maxLength,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        style: widget.style,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onFieldSubmitted,
        validator: widget.validator,
        onSaved: widget.onSaved,
        autovalidateMode: widget.autovalidateMode,
      );
    }
    return _AppleTextFieldForm(
      controller: _controller,
      validator: widget.validator,
      onSaved: widget.onSaved,
      autovalidateMode: widget.autovalidateMode,
      enabled: widget.enabled && widget.decoration.enabled,
      builder: (field) => _appleField(
        context,
        controller: _controller,
        focusNode: widget.focusNode,
        decoration: widget.decoration,
        enabled: widget.enabled,
        obscureText: widget.obscureText,
        autofocus: widget.autofocus,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        maxLength: widget.maxLength,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        style: widget.style,
        autofillHints: widget.autofillHints,
        onChanged: (value) {
          field.didChange(value);
          widget.onChanged?.call(value);
        },
        onSubmitted: widget.onFieldSubmitted,
        errorText: field.errorText,
      ),
    );
  }
}

class _AppleTextFieldForm extends m.FormField<String> {
  _AppleTextFieldForm({
    required this.controller,
    required super.builder,
    super.validator,
    super.onSaved,
    super.autovalidateMode,
    super.enabled,
  }) : super(initialValue: controller.text);

  final m.TextEditingController controller;

  @override
  m.FormFieldState<String> createState() => _AppleTextFieldFormState();
}

class _AppleTextFieldFormState extends m.FormFieldState<String> {
  @override
  _AppleTextFieldForm get widget => super.widget as _AppleTextFieldForm;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncController);
  }

  @override
  void didUpdateWidget(covariant _AppleTextFieldForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncController);
      widget.controller.addListener(_syncController);
      _syncController();
    }
  }

  void _syncController() {
    if (value != widget.controller.text) didChange(widget.controller.text);
  }

  @override
  void reset() {
    widget.controller.text = widget.initialValue ?? '';
    super.reset();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncController);
    super.dispose();
  }
}

class AppDropdownButtonFormField<T> extends m.StatelessWidget {
  const AppDropdownButtonFormField({
    super.key,
    required this.items,
    this.initialValue,
    this.value,
    this.onChanged,
    this.onSaved,
    this.validator,
    this.decoration = const m.InputDecoration(),
    this.isExpanded = false,
    this.autovalidateMode,
  });
  final List<m.DropdownMenuItem<T>>? items;
  final T? initialValue, value;
  final m.ValueChanged<T?>? onChanged;
  final m.FormFieldSetter<T>? onSaved;
  final m.FormFieldValidator<T>? validator;
  final m.InputDecoration decoration;
  final bool isExpanded;
  final m.AutovalidateMode? autovalidateMode;
  @override
  m.Widget build(m.BuildContext context) {
    if (appleTokensOf(context) == null) {
      return m.DropdownButtonFormField<T>(
        items: items,
        initialValue: initialValue ?? value,
        onChanged: onChanged,
        onSaved: onSaved,
        validator: validator,
        decoration: decoration,
        isExpanded: isExpanded,
        autovalidateMode: autovalidateMode,
      );
    }
    final tokens = appleTokensOf(context)!;
    return m.FormField<T>(
      initialValue: initialValue ?? value,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      builder: (field) {
        final selected = items
            ?.where((item) => item.value == field.value)
            .firstOrNull;
        return c.Column(
          crossAxisAlignment: c.CrossAxisAlignment.start,
          mainAxisSize: c.MainAxisSize.min,
          children: [
            if (decoration.labelText != null) ...[
              c.Text(
                decoration.labelText!,
                style: c.TextStyle(fontSize: 13, color: tokens.secondaryLabel),
              ),
              const c.SizedBox(height: 6),
            ],
            c.CupertinoButton(
              padding: const c.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              color: tokens.cardBackground,
              borderRadius: c.BorderRadius.circular(9),
              onPressed: onChanged == null
                  ? null
                  : () async {
                      final choice = await appShowCupertinoPopup<T>(
                        context: context,
                        builder: (popupContext) => c.CupertinoActionSheet(
                          title: decoration.labelText == null
                              ? null
                              : c.Text(decoration.labelText!),
                          actions: [
                            for (final item
                                in items ?? <m.DropdownMenuItem<T>>[])
                              c.CupertinoActionSheetAction(
                                onPressed: () =>
                                    c.Navigator.pop(popupContext, item.value),
                                child: item.child,
                              ),
                          ],
                          cancelButton: c.CupertinoActionSheetAction(
                            onPressed: () => c.Navigator.pop(popupContext),
                            child: const c.Text('取消'),
                          ),
                        ),
                      );
                      if (choice != null && field.mounted) {
                        field.didChange(choice);
                        onChanged?.call(choice);
                      }
                    },
              child: c.Row(
                children: [
                  if (selected != null)
                    c.Expanded(child: selected.child)
                  else
                    c.Expanded(
                      child: c.Text(
                        decoration.hintText ?? '请选择',
                        style: c.TextStyle(color: tokens.secondaryLabel),
                      ),
                    ),
                  const c.Icon(c.CupertinoIcons.chevron_down, size: 16),
                ],
              ),
            ),
            if (field.errorText != null)
              c.Padding(
                padding: const c.EdgeInsets.only(top: 5),
                child: c.Text(
                  field.errorText!,
                  style: c.TextStyle(
                    fontSize: 12,
                    color: m.Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AppSwitchListTile extends m.StatelessWidget {
  const AppSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
  });
  final bool value;
  final m.ValueChanged<bool>? onChanged;
  final m.Widget? title, subtitle, secondary;
  final m.EdgeInsetsGeometry? contentPadding;
  @override
  m.Widget build(m.BuildContext context) => appleTokensOf(context) == null
      ? m.SwitchListTile(
          value: value,
          onChanged: onChanged,
          title: title,
          subtitle: subtitle,
          secondary: secondary,
          contentPadding: contentPadding,
        )
      : c.Padding(
          padding:
              contentPadding ??
              const c.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: c.Row(
            children: [
              if (secondary != null) ...[
                secondary!,
                const c.SizedBox(width: 12),
              ],
              c.Expanded(
                child: c.GestureDetector(
                  behavior: c.HitTestBehavior.opaque,
                  onTap: onChanged == null ? null : () => onChanged!(!value),
                  child: c.Column(
                    crossAxisAlignment: c.CrossAxisAlignment.start,
                    children: [?title, ?subtitle],
                  ),
                ),
              ),
              c.CupertinoSwitch(value: value, onChanged: onChanged),
            ],
          ),
        );
}

class AppCheckboxListTile extends m.StatelessWidget {
  const AppCheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.contentPadding,
    this.controlAffinity = m.ListTileControlAffinity.platform,
  });
  final bool? value;
  final m.ValueChanged<bool?>? onChanged;
  final m.Widget? title, subtitle;
  final m.EdgeInsetsGeometry? contentPadding;
  final m.ListTileControlAffinity controlAffinity;
  @override
  m.Widget build(m.BuildContext context) {
    if (appleTokensOf(context) == null) {
      return m.CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        contentPadding: contentPadding,
        controlAffinity: controlAffinity,
      );
    }
    final control = AppCheckbox(value: value, onChanged: onChanged);
    return c.Padding(
      padding:
          contentPadding ??
          const c.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: c.Row(
        children: [
          if (controlAffinity == m.ListTileControlAffinity.leading) ...[
            control,
            const c.SizedBox(width: 10),
          ],
          c.Expanded(
            child: c.GestureDetector(
              behavior: c.HitTestBehavior.opaque,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(!(value ?? false)),
              child: c.Column(
                crossAxisAlignment: c.CrossAxisAlignment.start,
                children: [?title, ?subtitle],
              ),
            ),
          ),
          if (controlAffinity != m.ListTileControlAffinity.leading) control,
        ],
      ),
    );
  }
}

class AppCheckbox extends m.StatelessWidget {
  const AppCheckbox({super.key, required this.value, required this.onChanged});
  final bool? value;
  final m.ValueChanged<bool?>? onChanged;
  @override
  m.Widget build(m.BuildContext context) => appleTokensOf(context) == null
      ? m.Checkbox(value: value, onChanged: onChanged)
      : c.CupertinoCheckbox(value: value, onChanged: onChanged);
}

class AppChoiceChip extends m.StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.showCheckmark = true,
  });
  final m.Widget label;
  final bool selected, showCheckmark;
  final m.ValueChanged<bool>? onSelected;
  @override
  m.Widget build(m.BuildContext context) {
    if (appleTokensOf(context) == null) {
      return m.ChoiceChip(
        label: label,
        selected: selected,
        onSelected: onSelected,
        showCheckmark: showCheckmark,
      );
    }
    final tokens = appleTokensOf(context)!;
    return c.Semantics(
      selected: selected,
      button: true,
      child: c.CupertinoButton(
        padding: const c.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: selected
            ? m.Theme.of(context).colorScheme.primary.withValues(alpha: .14)
            : tokens.fill,
        onPressed: onSelected == null ? null : () => onSelected!(!selected),
        child: c.DefaultTextStyle(
          style:
              (m.Theme.of(context).textTheme.bodyMedium ??
                      const c.TextStyle(fontSize: 14))
                  .copyWith(
                    color: selected
                        ? m.Theme.of(context).colorScheme.primary
                        : m.Theme.of(context).colorScheme.onSurface,
                  ),
          child: label,
        ),
      ),
    );
  }
}

class AppFilterChip extends AppChoiceChip {
  const AppFilterChip({
    super.key,
    required super.label,
    required super.selected,
    required super.onSelected,
  });

  @override
  m.Widget build(m.BuildContext context) => appleTokensOf(context) == null
      ? m.FilterChip(label: label, selected: selected, onSelected: onSelected)
      : super.build(context);
}

class AppSegmentedButton<T extends Object> extends m.StatelessWidget {
  const AppSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.showSelectedIcon = true,
  });
  final List<m.ButtonSegment<T>> segments;
  final Set<T> selected;
  final m.ValueChanged<Set<T>>? onSelectionChanged;
  final bool showSelectedIcon;
  @override
  m.Widget build(m.BuildContext context) {
    if (appleTokensOf(context) == null) {
      return m.SegmentedButton<T>(
        segments: segments,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        showSelectedIcon: showSelectedIcon,
      );
    }
    final theme = m.Theme.of(context);
    return c.IgnorePointer(
      ignoring: onSelectionChanged == null,
      child: c.DefaultTextStyle(
        style: theme.textTheme.bodySmall!.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: c.FontWeight.w600,
        ),
        child: c.CupertinoSlidingSegmentedControl<T>(
          groupValue: selected.firstOrNull,
          disabledChildren: {
            for (final segment in segments)
              if (!segment.enabled) segment.value,
          },
          children: {
            for (final segment in segments)
              segment.value: c.Padding(
                padding: const c.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child:
                    segment.label ?? segment.icon ?? const c.SizedBox.shrink(),
              ),
          },
          onValueChanged: (value) {
            if (value != null) onSelectionChanged?.call({value});
          },
        ),
      ),
    );
  }
}
