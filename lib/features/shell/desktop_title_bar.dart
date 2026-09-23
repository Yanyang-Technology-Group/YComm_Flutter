// 自绘的窗口标题栏。
//
// 系统标题栏被隐藏后，拖动、最大化、关闭都要自己来：
//   拖动    —— 按住标题栏空白处调 startDragging
//   双击    —— 最大化 / 还原
//   右侧三个按钮 —— 最小化 / 最大化还原 / 关闭
// 关闭按钮走 windowManager.close()，由 AppShell 的 onWindowClose 决定
// 「托盘开启就隐藏，否则退出」，逻辑只放一处。
//
// 颜色全部取自当前主题，所以换主题时标题栏会跟着变——这正是当初要自绘的原因。
import 'package:flutter/material.dart';

import '../../core/window/desktop_shell.dart';

class DesktopTitleBar extends StatelessWidget {
  const DesktopTitleBar({super.key, this.title = '晏阳社区'});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => startWindowDrag(),
      onDoubleTap: toggleMaximizeWindow,
      child: Container(
        height: desktopTitleBarHeight,
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            bottom: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Image.asset(
              'assets/ycomm_mark.png',
              width: 18,
              height: 18,
              semanticLabel: '晏阳社区',
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const Spacer(),
            _WindowButton(
              icon: Icons.remove_rounded,
              tooltip: '最小化',
              onTap: minimizeWindow,
            ),
            _WindowButton(
              icon: Icons.crop_square_rounded,
              tooltip: '最大化 / 还原',
              onTap: toggleMaximizeWindow,
            ),
            _WindowButton(
              icon: Icons.close_rounded,
              tooltip: '关闭',
              onTap: closeWindow,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        hoverColor: danger
            ? scheme.error
            : scheme.onSurface.withValues(alpha: .08),
        child: SizedBox(
          width: 46,
          height: desktopTitleBarHeight,
          child: Icon(
            icon,
            size: 16,
            color: danger ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
