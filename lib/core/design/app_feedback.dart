import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as m;

import 'apple_chrome.dart';
import 'app_primitives.dart';
import 'adaptive_inputs.dart';

/// Cupertino navigation even when Apple style is selected on Android/desktop.
PageRoute<T> appPageRoute<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => appleTokensOf(context) == null
    ? m.MaterialPageRoute<T>(builder: builder)
    : ApplePageRoute<T>(builder: builder);

class ApplePageRoute<T> extends CupertinoPageRoute<T> {
  ApplePageRoute({required super.builder, super.settings});
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? FadeTransition(opacity: animation, child: child)
      : super.buildTransitions(context, animation, secondaryAnimation, child);
}

final _notices = Expando<VoidCallback>();
void appNotice(BuildContext context, Object message) {
  if (appleTokensOf(context) == null) {
    m.ScaffoldMessenger.of(context)
        .showSnackBar(m.SnackBar(content: Text(message.toString())));
    return;
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  _notices[overlay]?.call();
  late final OverlayEntry entry;
  bool removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
    entry.dispose();
    _notices[overlay] = null;
  }

  entry = OverlayEntry(
    builder: (_) => _Notice(message: message.toString(), onDismiss: remove),
  );
  _notices[overlay] = remove;
  overlay.insert(entry);
}

class _Notice extends StatefulWidget {
  const _Notice({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;
  @override
  State<_Notice> createState() => _NoticeState();
}

class _NoticeState extends State<_Notice> with SingleTickerProviderStateMixin {
  late final AnimationController fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  Timer? timer;
  @override
  void initState() {
    super.initState();
    fade.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    timer?.cancel();
    if (!MediaQuery.accessibleNavigationOf(context)) {
      timer = Timer(const Duration(seconds: 3), () async {
        await fade.reverse();
        if (mounted) widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 20,
    right: 20,
    bottom:
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom +
        64,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: fade,
            curve: const Cubic(.23, 1, .32, 1),
          ),
          child: Semantics(
            liveRegion: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: appleTokensOf(context)!.elevatedBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: appleTokensOf(context)!.separator),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 20,
                    color: Color(0x22000000),
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.message,
                        style: m.Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    CupertinoButton(
                      onPressed: widget.onDismiss,
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        semanticLabel: '关闭提示',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
    this.elevation,
  });
  final TextEditingController? controller;
  final String? hintText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<Widget>? trailing;
  final WidgetStateProperty<double?>? elevation;
  @override
  Widget build(BuildContext context) => appleTokensOf(context) == null
      ? m.SearchBar(
          controller: controller,
          hintText: hintText,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          trailing: trailing,
          elevation: elevation,
        )
      : AppTextField(
          controller: controller,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          decoration: m.InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(CupertinoIcons.search, size: 20),
            suffixIcon: trailing == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: trailing!.toList(),
                  ),
          ),
        );
}

class AppCircleAvatar extends StatelessWidget {
  const AppCircleAvatar({
    super.key,
    this.child,
    this.backgroundColor,
    this.radius,
  });
  final Widget? child;
  final Color? backgroundColor;
  final double? radius;
  @override
  Widget build(BuildContext context) => appleTokensOf(context) == null
      ? m.CircleAvatar(
          backgroundColor: backgroundColor,
          radius: radius,
          child: child,
        )
      : ClipOval(
          child: ColoredBox(
            color: backgroundColor ?? appleTokensOf(context)!.fill,
            child: SizedBox(
              width: (radius ?? 20) * 2,
              height: (radius ?? 20) * 2,
              child: Center(child: child),
            ),
          ),
        );
}

void appShowLicensePage({
  required BuildContext context,
  String? applicationName,
  String? applicationVersion,
}) {
  if (appleTokensOf(context) == null) {
    m.showLicensePage(
      context: context,
      applicationName: applicationName,
      applicationVersion: applicationVersion,
    );
    return;
  }
  Navigator.of(context).push(
    appPageRoute<void>(
      context,
      builder: (_) => _AppleLicenses(
        applicationName: applicationName,
        applicationVersion: applicationVersion,
      ),
    ),
  );
}

class _AppleLicenses extends StatefulWidget {
  const _AppleLicenses({this.applicationName, this.applicationVersion});
  final String? applicationName, applicationVersion;
  @override
  State<_AppleLicenses> createState() => _AppleLicensesState();
}

class _AppleLicensesState extends State<_AppleLicenses> {
  late final entries = LicenseRegistry.licenses.toList();
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: const AppNavigationBar(title: Text('开源许可')),
    body: FutureBuilder<List<LicenseEntry>>(
      future: entries,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('暂时无法读取许可'));
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '${widget.applicationName ?? ''} ${widget.applicationVersion ?? ''}',
              ),
            ),
            for (final entry in snapshot.data!)
              AppExpansionTile(
                title: Text(entry.packages.join(', ')),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      entry.paragraphs.map((p) => p.text).join('\n\n'),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}
