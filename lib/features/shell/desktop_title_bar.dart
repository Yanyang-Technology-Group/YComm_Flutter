import '../../core/design/adaptive.dart';

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
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';

import '../../core/window/desktop_shell.dart';

/// 在 Navigator 外保留窗口标题栏，并为其提示提供全窗口 Overlay。
class DesktopWindowFrame extends StatelessWidget {
  const DesktopWindowFrame({
    super.key,
    required this.child,
    this.titleBar = const DesktopTitleBar(),
  });

  final Widget? child;
  final Widget titleBar;

  @override
  Widget build(BuildContext context) => Overlay.wrap(
    child: Column(
      children: [
        titleBar,
        Expanded(child: child ?? const SizedBox.shrink()),
      ],
    ),
  );
}

/// 拖动区域的 key：三个窗口按钮必须放在这块区域**外面**。
const titleBarDragAreaKey = ValueKey<String>('title-bar-drag-area');

class DesktopTitleBar extends StatelessWidget {
  const DesktopTitleBar({super.key, this.title = '晏阳社区'});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 布局分两层（Stack）：
    //   1. 拖动层铺满整条标题栏，标题文字在其中水平居中——只有文字，
    //      没有图标也没有下划线；
    //   2. 三个按钮压在拖动层之上。命中测试先落到按钮，按下按钮就不会
    //      触发 startWindowDrag。之前按钮也在拖动层里，按下时 startDragging
    //      进入系统拖拽循环吞掉 mouse-up，三个按钮全都点不动。
    //
    // 拖动用 Listener 而不是 GestureDetector：GestureDetector 的 onPanStart
    // 会和页面里 TextField 的拖拽选择手势竞争 arena，路由推入后 TextField 抢到
    // 焦点就会把标题栏的拖拽挤掉。Listener 直接转发指针事件，不参与竞争。
    return Container(
      height: desktopTitleBarHeight,
      color: scheme.surface,
      child: Stack(
        children: [
          Listener(
            key: titleBarDragAreaKey,
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (event.buttons == kPrimaryButton) {
                startWindowDrag();
              }
            },
            child: SizedBox.expand(
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                    // 显式关闭 decoration：标题就是纯文字，不允许出现下划线。
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
        ],
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
    // IconButton 自带 Material + Tooltip + 46×38 点击热区，正好是
    // Windows 窗口按钮的规范尺寸。用它而不是手搓 InkWell，省掉「按钮
    // 需要 Material 祖先」和「Tooltip 热区比按钮宽」两类问题。
    return AppIconButton(
      onPressed: onTap,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        fixedSize: const Size(46, 38),
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
        foregroundColor: danger ? scheme.error : scheme.onSurfaceVariant,
        hoverColor: danger
            ? scheme.error
            : scheme.onSurface.withValues(alpha: .08),
      ),
      icon: AppIcon(icon, size: 16),
    );
  }
}
