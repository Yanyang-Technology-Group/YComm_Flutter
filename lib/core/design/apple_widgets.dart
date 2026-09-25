import 'adaptive.dart';

import 'package:flutter/material.dart';

import 'apple_chrome.dart';
import 'motion.dart';
import 'tokens.dart';

/// Apple 风格下的共享组件实现。
///
/// 这些组件不直接被页面引用——页面用的是 `core/widgets/design.dart` 里那几个
/// 同名组件，由它们判断当前风格后转发到这里。这样加一整套排版语言不需要在
/// 十几个页面文件里写 `if (apple)`。
///
/// 页面按导航、内容与操作的语义选择分组和层级。

/// 页面主体宽度。
///
/// 比 Material 版窄一点：iOS 的阅读宽度更收，且分组列表在宽屏上拉太宽会散。
class ApplePageWidth extends StatelessWidget {
  const ApplePageWidth({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: child,
    ),
  );
}

/// 大标题。
///
/// 34pt 粗体与紧凑行高构成页面层级；副标题和操作不另占品牌栏。
class ApplePageIntro extends StatelessWidget {
  const ApplePageIntro(
    this.title, {
    super.key,
    this.action,
    this.markdown = false,
    this.buildTitle,
  });

  final String title;
  final Widget? action;
  final bool markdown;

  /// 自定义标题构建（正文页需要 Markdown 渲染标题时用）。
  final Widget Function(TextStyle style)? buildTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppleType.largeTitle.copyWith(
      color: scheme.onSurface,
      fontFamilyFallback: appleFontFallback,
    );
    final child =
        buildTitle?.call(style) ??
        Text(title, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppleSpacing.title,
        AppleSpacing.md,
        AppleSpacing.title,
        AppleSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Semantics(header: true, child: child)),
          ?action,
        ],
      ),
    );
  }
}

/// 空状态 / 错误状态面板。
///
/// 空状态使用中性色符号与居中文案，主操作使用强调色。
class AppleStatePanel extends StatelessWidget {
  const AppleStatePanel({
    super.key,
    required this.title,
    this.message = '',
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title, message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppleSpacing.xxl,
        vertical: 56,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            icon,
            size: 44,
            color: tokens?.tertiaryLabel ?? scheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppleSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppleType.title3.copyWith(
              color: scheme.onSurface,
              fontFamilyFallback: appleFontFallback,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: AppleSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppleType.subheadline.copyWith(
                color: tokens?.secondaryLabel ?? scheme.onSurfaceVariant,
                fontFamilyFallback: appleFontFallback,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppleSpacing.xl),
            action!,
          ],
        ],
      ),
    );
  }
}

/// 加载骨架。
///
/// 不用转圈占位整屏：iOS 更常见的是让内容骨架先出来，再用一次很轻的
/// 呼吸（透明度脉动）说明「还在加载」。脉动幅度压到 0.35~0.7，
/// 并且尊重「减少动画」——那时换成静态骨架。
class AppleLoadingRows extends StatefulWidget {
  const AppleLoadingRows({super.key});
  @override
  State<AppleLoadingRows> createState() => _AppleLoadingRowsState();
}

class _AppleLoadingRowsState extends State<AppleLoadingRows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    final scheme = Theme.of(context).colorScheme;
    final base = (tokens?.fill ?? scheme.surfaceContainerHighest);
    final reduced = MediaQuery.disableAnimationsOf(context);
    Widget bar(double widthFactor, double height, double alpha) =>
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: base.withValues(alpha: alpha),
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );
    return Semantics(
      label: '正在加载',
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = reduced ? .5 : Curves.easeInOut.transform(_pulse.value);
          // 骨架条自身的透明度在 0.5~1 之间走，避免整块内容一起闪烁。
          final k = lerpValue(.5, 1, t);
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppleSpacing.title,
              AppleSpacing.lg,
              AppleSpacing.title,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: AppleSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(.32, 12, .8 * k),
                      const SizedBox(height: AppleSpacing.md),
                      bar(.92, 16, .5 * k),
                      const SizedBox(height: AppleSpacing.sm),
                      bar(.66, 12, .35 * k),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 小标签（置顶 / 楼主 / 待审核）。
///
/// iOS 里这类标记是胶囊形、填充底、次要色文字；不用描边也不用阴影。
class AppleSmallTag extends StatelessWidget {
  const AppleSmallTag(this.text, {super.key, this.buildChild});

  final String text;

  /// 需要 Markdown 渲染时由调用方给出子组件。
  final Widget Function(TextStyle style)? buildChild;

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context);
    final scheme = Theme.of(context).colorScheme;
    final style = AppleType.caption1.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.primary,
      fontFamilyFallback: appleFontFallback,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(
          alpha: tokens?.isDark == true ? .22 : .12,
        ),
        borderRadius: BorderRadius.circular(AppleRadius.chip),
      ),
      child: DefaultTextStyle.merge(
        style: style,
        child: buildChild?.call(style) ?? Text(text),
      ),
    );
  }
}

/// 列表行 / 设置项。
///
/// 用 [PressableScale] 而不是 [InkWell]：按下立即整行高亮 + 轻微缩放，
/// 没有水波纹。分隔线由调用方在行之间插 [AppleSeparator]。
class AppleRow extends StatelessWidget {
  const AppleRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppleSpacing.row,
      vertical: 12,
    ),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onTap,
    pressedScale: .98,
    child: Padding(padding: padding, child: child),
  );
}
