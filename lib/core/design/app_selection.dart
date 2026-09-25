import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;

import 'apple_chrome.dart';

/// Text selection belongs to the Apple branch too, including its context menu.
class AppSelection extends StatelessWidget {
  const AppSelection({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => appleTokensOf(context) == null
      ? child
      : SelectableRegion(
          selectionControls: cupertinoTextSelectionHandleControls,
          contextMenuBuilder: (context, state) =>
              CupertinoAdaptiveTextSelectionToolbar.buttonItems(
                buttonItems: state.contextMenuButtonItems,
                anchors: state.contextMenuAnchors,
              ),
          child: child,
        );
}

class AppSelectableText extends StatelessWidget {
  const AppSelectableText(this.data, {super.key, this.style});
  final String data;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => appleTokensOf(context) == null
      ? m.SelectableText(data, style: style)
      : AppSelection(child: Text(data, style: style));
}
