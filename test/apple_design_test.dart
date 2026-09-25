import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/design/apple_chrome.dart';
import 'package:ycomm_client/core/design/apple_theme.dart';
import 'package:ycomm_client/core/design/design_style.dart';
import 'package:ycomm_client/core/design/motion.dart';
import 'package:ycomm_client/core/design/tokens.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/core/theme/theme_controller.dart';

void main() {
  group('弹簧参数换算', () {
    test('临界阻尼下阻尼系数等于 2√k（不产生过冲）', () {
      final spec = SpringSpec.defaultSpec.toDescription();
      expect(spec.mass, 1);
      // ω = 2π / 0.35 ≈ 17.95，k = ω²
      final omega = 2 * math.pi / 0.35;
      expect(spec.stiffness, closeTo(omega * omega, 1e-6));
      expect(spec.damping, closeTo(2 * math.sqrt(spec.stiffness), 1e-6));
    });

    test('响应越短刚度越大', () {
      expect(
        const SpringSpec(damping: 1, response: 0.2).toDescription().stiffness,
        greaterThan(
          const SpringSpec(damping: 1, response: 0.4).toDescription().stiffness,
        ),
      );
    });

    test('阻尼比小于 1 时阻尼系数也同比缩小（会过冲）', () {
      const critical = SpringSpec(damping: 1, response: 0.4);
      const bouncy = SpringSpec(damping: 0.8, response: 0.4);
      expect(
        bouncy.toDescription().damping,
        closeTo(critical.toDescription().damping * 0.8, 1e-6),
      );
    });

    test('收敛超时与响应成正比，且始终为正', () {
      expect(
        const SpringSpec(damping: 1, response: 0.4).settleTimeout,
        const Duration(milliseconds: 3200),
      );
      for (final r in [0.1, 0.3, 0.5, 1.0]) {
        expect(
          SpringSpec(damping: 1, response: r).settleTimeout.inMilliseconds,
          greaterThan(0),
        );
      }
    });
  });

  group('动量投影', () {
    test('用的是指数衰减形式，不是 v²/(2a)', () {
      // d = 0.998 时，系数 = 0.998 / 0.002 = 499，位移与速度成正比。
      expect(project(1000), closeTo(499, 0.5));
      // 两者在低速段数值相近（这正是容易混过去的地方），
      // 但在高速段拉开数量级——指数形式是线性的，v²/(2a) 是二次的。
      final exponential = project(4000);
      final textbook = 4000 * 4000 / (2 * 998);
      expect(exponential, closeTo(1996, 1));
      expect(textbook, closeTo(8016, 1));
      expect(textbook / exponential, greaterThan(4));
    });

    test('位移与速度成正比（指数衰减的特征）', () {
      expect(project(2000) / project(1000), closeTo(2, 1e-9));
    });

    test('速度为零时不产生位移', () {
      expect(project(0), 0);
      expect(project(-0), 0);
    });

    test('减速率越小越「脆」，滑得越近', () {
      expect(
        project(2000, decelerationRate: 0.99),
        lessThan(project(2000, decelerationRate: 0.998)),
      );
    });

    test('方向跟着速度符号走', () {
      expect(project(-800), lessThan(0));
      expect(project(800), greaterThan(0));
    });
  });

  group('弹性边界', () {
    test('越界越多，实际位移越少（增长被压制）', () {
      const dimension = 400.0;
      final first = rubberband(50, dimension);
      final second = rubberband(100, dimension);
      expect(first, greaterThan(0));
      expect(second, greaterThan(first));
      // 但没有线性增长那么多
      expect(second, lessThan(first * 2));
      // 永远不超过用户实际拖出的距离
      expect(rubberband(100, dimension), lessThan(100));
    });

    test('尺寸为 0 时不产生越界位移', () {
      expect(rubberband(50, 0), 0);
    });
  });

  group('风格选择', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Apple 平台默认 Apple 风格，其余平台保持 Material', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(DesignStyle.defaultForPlatform(), DesignStyle.apple);
      }
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(DesignStyle.defaultForPlatform(), DesignStyle.material);
      }
    });

    test('没存过偏好时按平台解析', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(DesignStyle.resolve(null), DesignStyle.apple);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(DesignStyle.resolve(null), DesignStyle.material);
    });

    test('存过偏好时以用户选择为准，不认的值退回 Material', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(DesignStyle.resolve('apple'), DesignStyle.apple);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(DesignStyle.resolve('material'), DesignStyle.material);
      expect(DesignStyle.resolve('cupertino'), DesignStyle.material);
    });
  });

  group('Apple 主题', () {
    test('强调色与 Material 风格完全一致（品牌配色不漂移）', () {
      for (final colour in ThemeColour.values) {
        for (final brightness in Brightness.values) {
          final material = buildTheme(colour, brightness).colorScheme;
          final apple = buildAppleTheme(colour, brightness).colorScheme;
          expect(
            apple.primary,
            material.primary,
            reason: '$colour / $brightness',
          );
          expect(apple.onPrimary, material.onPrimary);
          expect(apple.primaryContainer, material.primaryContainer);
          expect(apple.onPrimaryContainer, material.onPrimaryContainer);
        }
      }
    });

    test('中性色换成 iOS 系统灰', () {
      final light = buildAppleTheme(ThemeColour.azure, Brightness.light);
      final dark = buildAppleTheme(ThemeColour.azure, Brightness.dark);
      expect(light.colorScheme.surface, ApplePalette.groupedBackground);
      expect(light.colorScheme.onSurface, ApplePalette.label);
      expect(light.colorScheme.outlineVariant, ApplePalette.separator);
      expect(dark.colorScheme.surface, ApplePalette.groupedBackgroundDark);
      expect(dark.colorScheme.onSurface, ApplePalette.labelDark);
      expect(dark.colorScheme.outlineVariant, ApplePalette.separatorDark);
    });

    test('每个明暗各挂一份 AppleTokens，且明暗标记正确', () {
      for (final brightness in Brightness.values) {
        final tokens = buildAppleTheme(
          ThemeColour.azure,
          brightness,
        ).extension<AppleTokens>();
        expect(tokens, isNotNull);
        expect(tokens!.brightness, brightness);
        expect(tokens.isDark, brightness == Brightness.dark);
      }
    });

    test('路由过渡在两种风格下不同：Apple 用 Cupertino 推入', () {
      final apple = buildAppleTheme(ThemeColour.azure, Brightness.light);
      final material = buildTheme(ThemeColour.azure, Brightness.light);
      expect(
        apple.pageTransitionsTheme.builders[TargetPlatform.android].runtimeType,
        isNot(
          material
              .pageTransitionsTheme
              .builders[TargetPlatform.android]
              .runtimeType,
        ),
      );
    });

    test('iOS 开关用系统绿，不跟品牌色', () {
      final scheme = buildAppleTheme(
        ThemeColour.red,
        Brightness.light,
      ).switchTheme;
      expect(
        scheme.trackColor?.resolve({WidgetState.selected}),
        const Color(0xFF34C759),
      );
    });

    test('发丝分隔线比 Material 细', () {
      final apple = buildAppleTheme(ThemeColour.azure, Brightness.light);
      final material = buildTheme(ThemeColour.azure, Brightness.light);
      expect(
        apple.dividerTheme.thickness,
        lessThan(material.dividerTheme.thickness!),
      );
      expect(apple.dividerTheme.thickness, 0.5);
    });
  });

  group('字级', () {
    test('字距随字号变化，不是固定值', () {
      final sizes = {
        AppleType.largeTitle.fontSize: AppleType.largeTitle.letterSpacing,
        AppleType.title2.fontSize: AppleType.title2.letterSpacing,
        AppleType.body.fontSize: AppleType.body.letterSpacing,
        AppleType.caption2.fontSize: AppleType.caption2.letterSpacing,
      };
      expect(sizes.values.toSet().length, sizes.length, reason: '每档字距应各不相同');

      // 大标题适度收紧；脚注保留更松的字距，避免固定字距用于所有字号。
      expect(
        AppleType.largeTitle.letterSpacing,
        lessThan(AppleType.body.letterSpacing!),
      );
      expect(AppleType.title2.letterSpacing, lessThan(0));
      expect(AppleType.body.letterSpacing, lessThan(0));
    });

    test('行高随字号反向变化：大字更紧', () {
      final large = AppleType.largeTitle.height!;
      final body = AppleType.body.height!;
      expect(large, lessThan(body));
      expect(body, closeTo(22 / 17, 1e-9));
    });
  });

  group('主题控制器持久化', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('切换风格会写入 prefs 并保留其他两项', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final control = container.read(themeControllerProvider.notifier);
      await control.setColour(ThemeColour.mint);
      await control.setMode(ThemeModePreference.dark);
      await control.setStyle(DesignStyle.apple);

      expect(container.read(themeControllerProvider).style, DesignStyle.apple);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeController.styleKey), 'apple');
      // 前两项不能被风格切换冲掉
      expect(prefs.getString(ThemeController.colourKey), 'mint');
      expect(prefs.getString(ThemeController.modeKey), 'dark');
    });

    test('load 读回存过的风格', () async {
      SharedPreferences.setMockInitialValues({
        ThemeController.styleKey: 'apple',
        ThemeController.colourKey: 'orange',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(themeControllerProvider.notifier).load();
      final state = container.read(themeControllerProvider);
      expect(state.style, DesignStyle.apple);
      expect(state.colour, ThemeColour.orange);
    });

    test('load 不会把按平台推导的默认值写回 prefs', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(themeControllerProvider.notifier).load();
      expect(container.read(themeControllerProvider).style, DesignStyle.apple);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeController.styleKey), isNull);
    });
  });

  group('材质与按压', () {
    testWidgets('非 Apple 风格下材质层直通，不报错', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TranslucentBar(child: const Text('内容'))),
        ),
      );
      expect(find.text('内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Apple 风格下材质层仍然渲染内容', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
          home: const Scaffold(body: TranslucentBar(child: Text('模糊内容'))),
        ),
      );
      expect(find.text('模糊内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('按下立即触发反馈，不等抬手', (tester) async {
      var down = false, up = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
          home: Scaffold(
            body: PressableScale(
              onTapDown: () => down = true,
              onTapUp: () => up = true,
              onTap: () {},
              child: const SizedBox(width: 100, height: 50),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      // 逐帧推进但**不抬手**：反馈必须已经发生。
      await tester.pump(const Duration(milliseconds: 16));
      expect(down, isTrue);
      expect(up, isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(up, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('拖开超过迟滞后取消点击', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
          home: Scaffold(
            body: Center(
              child: PressableScale(
                onTap: () => tapped = true,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      // 滑出 40px，超过 10px 迟滞
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tapped, isFalse, reason: '滑开应当取消，不该算一次点击');
      expect(tester.takeException(), isNull);
    });

    testWidgets('内缩分隔线在 Apple 主题下用发丝线，且左侧有内缩', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
          home: const Scaffold(
            body: Column(children: [AppleSeparator(inset: 16)]),
          ),
        ),
      );
      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(AppleSeparator),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.only(left: 16, right: 0));
      expect(tester.takeException(), isNull);
    });
  });

  group('速度采样', () {
    test('样本不足时速度为零', () {
      final tracker = VelocityTracker1D();
      expect(tracker.velocity, 0);
      tracker.add(Duration.zero, 0);
      expect(tracker.velocity, 0);
    });

    test('按时间窗口估算每秒速度', () {
      final tracker = VelocityTracker1D();
      tracker.add(Duration.zero, 0);
      tracker.add(const Duration(milliseconds: 50), 100);
      // 100px / 0.05s = 2000px/s
      expect(tracker.velocity, closeTo(2000, 1));
    });

    test('只保留窗口内的采样，避免旧样本把速度抹平', () {
      final tracker = VelocityTracker1D(
        window: const Duration(milliseconds: 80),
      );
      tracker.add(Duration.zero, 0);
      tracker.add(const Duration(milliseconds: 20), 1000); // 很快的一段
      tracker.add(const Duration(milliseconds: 400), 1010); // 之后几乎停住
      // 早先那段快速样本已被移出窗口，速度应当回落到接近 0 的低值
      expect(tracker.velocity, lessThan(100));
      tracker.clear();
      expect(tracker.velocity, 0);
    });
  });

  group('弹簧驱动', () {
    testWidgets('收敛到目标值并停下', (tester) async {
      late SpringMotion motion;
      await tester.pumpWidget(
        MaterialApp(home: _MotionHost(onInit: (m) => motion = m)),
      );
      motion.animateTo(1);
      await tester.pumpAndSettle();
      expect(motion.value, closeTo(1, 1e-3));
      expect(motion.isAnimating, isFalse);
    });

    testWidgets('中断时从当前值继续，不跳回起点', (tester) async {
      late SpringMotion motion;
      await tester.pumpWidget(
        MaterialApp(home: _MotionHost(onInit: (m) => motion = m)),
      );
      motion.animateTo(1);
      // 按真实帧率推进到半途（每帧 16ms）。
      await _pumpFrames(tester, 4);
      final midway = motion.value;
      expect(midway, greaterThan(0.05));
      expect(midway, lessThan(0.99));

      // 反向重定向：必须从当前值起步，而不是从 0 或从 1
      motion.animateTo(0);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        motion.value,
        closeTo(midway, 0.15),
        reason: '重定向应当从当前呈现值继续，否则会看到跳变',
      );
      await tester.pumpAndSettle();
      expect(motion.value, closeTo(0, 1e-3));
    });

    testWidgets('可以越出 0~1 区间过冲（这正是不能用 AnimationController 的原因）', (
      tester,
    ) async {
      late SpringMotion motion;
      await tester.pumpWidget(
        MaterialApp(home: _MotionHost(onInit: (m) => motion = m)),
      );
      // 给一个很猛的初速度冲过目标
      motion.animateTo(1, velocity: 60, spec: SpringSpec.momentum);
      var overshot = false;
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (motion.value > 1.0005) overshot = true;
      }
      expect(overshot, isTrue, reason: '弹簧应当允许越过目标再回来');
      await tester.pumpAndSettle();
      expect(motion.value, closeTo(1, 1e-2));
    });

    testWidgets('snapTo 不产生速度', (tester) async {
      late SpringMotion motion;
      await tester.pumpWidget(
        MaterialApp(home: _MotionHost(onInit: (m) => motion = m)),
      );
      motion.animateTo(1);
      await tester.pump(const Duration(milliseconds: 40));
      motion.snapTo(5);
      expect(motion.value, 5);
      expect(motion.velocity, 0);
      expect(motion.isAnimating, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}

/// 按 60fps 逐帧推进。
///
/// 不能写成一次 `pump(60ms)`：那只产生一帧，而弹簧的第一帧按设计只用来建立
/// 时间基准，真正的位移从第二帧开始。逐帧推进才等价于真实运行。
Future<void> _pumpFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// 提供一个 vsync 并暴露 [SpringMotion]，用于在不引入组件的情况下测试弹簧本身。
class _MotionHost extends StatefulWidget {
  const _MotionHost({required this.onInit});
  final void Function(SpringMotion motion) onInit;

  @override
  State<_MotionHost> createState() => _MotionHostState();
}

class _MotionHostState extends State<_MotionHost>
    with SingleTickerProviderStateMixin {
  late final SpringMotion motion = SpringMotion(vsync: this, value: 0);

  @override
  void initState() {
    super.initState();
    widget.onInit(motion);
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
