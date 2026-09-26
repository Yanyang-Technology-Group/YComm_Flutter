import 'package:flutter/services.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'apple_theme.dart';
import 'apple_accessibility.dart';
import 'motion.dart';
import 'tokens.dart';

/// 内缩发丝分隔线。
///
/// iOS 列表的分隔线**不从屏幕边缘起笔**：它从内容（头像/图标）之后开始，
/// 到右边缘止。这样每一行的视觉起点是内容而不是线，列表读起来是一列条目，
/// 而不是一张表格。现有 Material 版本用的是通栏 `Divider`。
class AppleSeparator extends StatelessWidget {
  const AppleSeparator({
    super.key,
    this.inset = AppleSpacing.row,
    this.endInset = 0,
  });

  /// 左侧内缩，默认与行内边距对齐。
  final double inset;

  /// 右侧内缩，默认贴边（iOS 系统设置就是贴边的）。
  final double endInset;

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    if (tokens == null) {
      return const Divider(height: 1);
    }
    return Padding(
      padding: EdgeInsets.only(left: inset, right: endInset),
      child: SizedBox(
        width: double.infinity,
        height: hairlineOf(context),
        child: ColoredBox(color: tokens.separator),
      ),
    );
  }
}

/// 读取当前 Apple token；不在 Apple 风格下返回 null。
///
/// 每个组件都自带一次判空，这样它们可以在两种风格下同时被引用而不会炸——
/// 调用方不需要自己判断风格。
AppleTokens? appleTokensOf(BuildContext context) =>
    Theme.of(context).extension<AppleTokens>();

/// 半透明材质层。
///
/// iOS 的导航栏、输入条、sheet 不是「一块不透明的条」，而是一层会模糊背后内容的
/// 材质：内容从它下面滚过去，边缘还有一道被光打亮的高光。所以这里用
/// [BackdropFilter] 而不是纯色。
///
/// 材质重量编码层级：大面积的栏用更强的模糊和更深的底色，小控件用轻的。
/// 「浅色半透明叠在另一个浅色半透明上」会让可读性塌掉，所以这个组件假定自己
/// 下面是不透明的页面内容。
class TranslucentBar extends StatelessWidget {
  const TranslucentBar({
    super.key,
    required this.child,
    this.blur = 20,
    this.edge = TranslucentEdge.none,
  });

  final Widget child;

  /// 模糊半径。大栏 20~30，小控件 10 左右。
  final double blur;

  /// 高光/分隔线画在哪条边。
  final TranslucentEdge edge;

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    if (tokens == null) return child;
    if (MediaQuery.highContrastOf(context) ||
        AppleAccessibility.reduceTransparencyOf(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.elevatedBackground,
          border: switch (edge) {
            TranslucentEdge.top => Border(
              top: BorderSide(color: tokens.opaqueSeparator),
            ),
            TranslucentEdge.bottom => Border(
              bottom: BorderSide(color: tokens.opaqueSeparator),
            ),
            TranslucentEdge.none => null,
          },
        ),
        child: child,
      );
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.materialColor,
            border: switch (edge) {
              TranslucentEdge.top => Border(
                top: BorderSide(color: tokens.materialHighlight),
              ),
              TranslucentEdge.bottom => Border(
                bottom: BorderSide(color: tokens.materialHighlight),
              ),
              TranslucentEdge.none => null,
            },
          ),
          child: child,
        ),
      ),
    );
  }
}

enum TranslucentEdge { none, top, bottom }

/// 滚动边缘效果：内容滚到浮动 chrome 下面时，用一小段渐隐代替硬分割线。
///
/// iOS 里看不到「1px 边框压在滚动内容上」这种处理——那条线是靠材质边缘和
/// 渐隐暗示出来的。只在浮动 UI 真的与内容重叠处用，不要到处加。
class ScrollEdgeFade extends StatelessWidget {
  const ScrollEdgeFade({
    super.key,
    required this.child,
    this.edge = TranslucentEdge.top,
    this.extent = 16,
  });

  final Widget child;
  final TranslucentEdge edge;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    if (tokens == null) return child;
    final transparent = tokens.groupedBackground.withValues(alpha: 0);
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: edge == TranslucentEdge.top
            ? Alignment.topCenter
            : Alignment.bottomCenter,
        end: edge == TranslucentEdge.top
            ? Alignment.bottomCenter
            : Alignment.topCenter,
        colors: [tokens.groupedBackground, transparent],
        stops: [
          0,
          (extent / (rect.height == 0 ? 1 : rect.height)).clamp(0.0, 1.0),
        ],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

/// 按压即反馈。
///
/// Apple 的第一条要求是「按下就响应，不等抬手」：在 `onTapDown` 立刻开始缩小。
/// [InkWell] 做的是水波纹，在 Apple 语言的列表里是错的——iOS 用的是整行底色
/// 短暂加深 + 轻微缩放。
///
/// 两条手势细节：
/// - 按下后往外拖超过 10px 视为取消（迟滞），拖回来还能恢复；
/// - 抬手或取消都走弹簧回弹，不用固定时长。
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onLongPress,
    this.pressedScale = 0.975,
    this.pressedColor,
    this.borderRadius,
    this.enabled = true,
    this.haptic = true,
  });

  final Widget child;

  final VoidCallback? onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final VoidCallback? onTapCancel;
  final VoidCallback? onLongPress;

  /// 按下的缩放比例。列表行用 0.975 就够，按钮可以到 0.96。
  final double pressedScale;

  /// 按下时叠加的底色。为空时只缩放。
  final Color? pressedColor;

  /// 高亮裁剪用的圆角，要和 child 的形状一致。
  final BorderRadius? borderRadius;

  final bool enabled;

  /// 是否在按下时给触觉反馈。桌面端会自动忽略。
  final bool haptic;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final SpringMotion _scale;
  bool _pressed = false;
  bool _focused = false;

  /// 按下点，用来判断手指有没有滑开。
  Offset? _origin;

  /// 按下后手指移出多远算取消。太小会被手指抖动误触，太大又从不了
  /// 「按住后发现不想点，滑开取消」这个 iOS 上很自然的动作。
  static const _hysteresis = 10.0;

  @override
  void initState() {
    super.initState();
    _scale = SpringMotion(
      vsync: this,
      value: 1,
      spec: SpringSpec.defaultSpec,
      // 缩放只在小数位上变化，容差放宽一点可以更早停下，省掉无意义的帧。
      tolerance: 1e-4,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _scale.snapTo(1);
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  bool get _reducedMotion =>
      !mounted || MediaQuery.disableAnimationsOf(context);

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    // 减少动画时不缩放，但仍然换底色——反馈不能整个消失，只是换成
    // 不引起前庭反应的形式（技能第 14 条）。
    if (_reducedMotion || widget.pressedScale == 1) return;
    _scale.animateTo(value ? widget.pressedScale : 1);
  }

  /// 原始指针事件，负责「按下立即高亮」。
  ///
  /// 不能只靠 [GestureDetector.onTapDown]：它要等点击识别器在竞技场里胜出才触发，
  /// 如果外层的可滚动区域正在竞争，这个反馈会晚到几十毫秒——Apple 的第一条原则
  /// 就是不能有这种延迟。所以高亮从指针落下的那一刻开始，而语义动作仍然交给
  /// [GestureDetector]，无障碍与点击判定不受影响。
  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || event.buttons != 1) return;
    _origin = event.position;
    _setPressed(true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final origin = _origin;
    if (origin == null) return;
    // 超过迟滞距离就当作「滑开取消」，但保留 _origin，
    // 手指拖回来还能恢复高亮。
    _setPressed((event.position - origin).distance <= _hysteresis);
  }

  void _onPointerEnd() {
    _origin = null;
    _setPressed(false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    final highlight = widget.pressedColor ?? tokens?.fill;
    final content = Stack(
      children: [
        widget.child,
        // 按下高亮：独立一层，不参与布局，所以列表行的高度不会跳。
        if (highlight != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _pressed ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 110),
                curve: const Cubic(.23, 1, .32, 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: highlight,
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final inner = widget.borderRadius == null
        ? content
        : ClipRRect(borderRadius: widget.borderRadius!, child: content);

    return FocusableActionDetector(
      enabled: widget.enabled && widget.onTap != null,
      mouseCursor: widget.enabled && widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (widget.enabled) widget.onTap?.call();
            return null;
          },
        ),
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: _focused
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: (_) => _onPointerEnd(),
          onPointerCancel: (_) => _onPointerEnd(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? widget.onTap : null,
            onLongPress: widget.enabled ? widget.onLongPress : null,
            // 语义层的回调照旧往外传，调用方感觉不到下面换了一套实现。
            onTapDown: widget.enabled ? (_) => widget.onTapDown?.call() : null,
            onTapUp: widget.enabled ? (_) => widget.onTapUp?.call() : null,
            onTapCancel: widget.enabled
                ? () => widget.onTapCancel?.call()
                : null,
            child: _reducedMotion
                ? inner
                : SpringBuilder(
                    motion: _scale,
                    builder: (context, value, _) => Transform.scale(
                      scale: value,
                      // 缩放只沿视觉中心发生，不需要额外的对齐偏移。
                      child: inner,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
