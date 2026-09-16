import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/ycomm_mark.png',
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
