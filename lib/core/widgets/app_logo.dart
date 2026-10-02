import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../window/desktop_settings.dart';

class AppLogo extends ConsumerWidget {
  const AppLogo({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        desktopIconAsset(ref.watch(desktopSettingsProvider).icon),
        width: compact ? 36 : 34,
        height: compact ? 36 : 34,
        semanticLabel: '晏阳社区 Logo',
      ),
      if (!compact) ...[
        const SizedBox(width: 10),
        const Text(
          '晏阳社区',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    ],
  );
}
