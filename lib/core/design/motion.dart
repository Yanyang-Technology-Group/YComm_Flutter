import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Apple 的弹簧参数：**阻尼比** + **响应时间**，而不是质量/刚度/阻尼那三件套。
///
/// - 阻尼比（damping）：1.0 是临界阻尼，不越过目标；小于 1 会过冲振荡。
/// - 响应（response）：值到达目标的大致快慢，单位秒。**它不是 duration**——
///   弹簧没有固定时长，收敛时间由这两个参数自然涌现。
class SpringSpec {
  const SpringSpec({required this.damping, required this.response});

  final double damping;
  final double response;

  /// 通用 UI 动效：临界阻尼，平稳收住，不弹。
  static const defaultSpec = SpringSpec(damping: 1, response: 0.35);

  /// 位移/重定位：更快一点，同样不弹。
  static const move = SpringSpec(damping: 1, response: 0.3);

  /// drawer 与 sheet：允许一点点回弹，因为它是被「甩」出来的。
  static const sheet = SpringSpec(damping: 0.8, response: 0.3);

  /// 只有确实由滑动/抛掷带来的动量才用带弹跳的规格。
  static const momentum = SpringSpec(damping: 0.8, response: 0.4);

  /// 换算成 Flutter 的弹簧描述。
  ///
  /// 角频率 ω = 2π / response，刚度 k = ω²，阻尼 c = 2ζ√k。
  /// 无单位质量约定为 1，这样得到的运动与 Apple 公布的手感一致。
  SpringDescription toDescription() {
    final omega = 2 * math.pi / response;
    final stiffness = omega * omega;
    return SpringDescription(
      mass: 1,
      stiffness: stiffness,
      damping: 2 * damping * math.sqrt(stiffness),
    );
  }

  /// 收敛所需的时间上界，用于给动画控制器一个安全时长。
  ///
  /// 弹簧本身没有时长，但 [AnimationController] 需要拿到一个 duration 才能
  /// 进入驱动状态；这里给 8 倍时间常数，足够让速度衰减到不可见。
  Duration get settleTimeout =>
      Duration(milliseconds: (response * 8 * 1000).round().clamp(1, 60000));
}

/// 动量投影：估算一次滑动松手后，元素**本来会停在哪里**。
///
/// 这是「小输入大输出」的来源——不是从松手点就近吸附，而是先按速度算出终点，
/// 再吸附到离终点最近的那个目标。公式取自 Apple *Designing Fluid Interfaces*
/// 的示例代码，是**指数衰减**形式，不是物理课本里的 v²/(2a)。
///
/// 减速率 0.998 是常规滚动手感，0.99 更「脆」一些。
double project(double initialVelocity, {double decelerationRate = 0.998}) =>
    (initialVelocity / 1000) * decelerationRate / (1 - decelerationRate);

/// 弹性边界：越往边界外拖，跟随得越少。
///
/// 硬停在手感上等于「卡住」，连续的阻力才读得出「到边了，但还可以再拉一点」。
/// [dimension] 是被拖拽方向的尺寸，[constant] 越大阻力越强。
double rubberband(
  double overshoot,
  double dimension, {
  double constant = 0.55,
}) {
  if (dimension <= 0) return 0;
  return (overshoot * dimension * constant) /
      (dimension + constant * overshoot.abs());
}

/// 把 [t] 从 [a]~[b] 映射到 0~1，越界时钳制。
double progressBetween(double t, double a, double b) {
  if (b <= a) return t >= b ? 1 : 0;
  return ((t - a) / (b - a)).clamp(0.0, 1.0);
}

/// 弹簧驱动的值。换目标时**从当前值继续、并把当前速度带上**，
/// 所以反向重定向不会出现速度突变的「撞墙」感。
///
/// 用 [Ticker] 直接驱动，不走 [AnimationController]，后者会把值钳在
/// lowerBound~upperBound 之间，而弹簧仿真在过冲时需要越界才自然。
class SpringMotion extends ChangeNotifier {
  // 这两条 prefer_initializing_formals 是误报：Dart 不允许把私有命名参数
  // 写成 `this._vsync` / `this._spec`，只能走初始化列表。
  // ignore_for_file: prefer_initializing_formals
  SpringMotion({
    required TickerProvider vsync,
    required double value,
    SpringSpec spec = SpringSpec.defaultSpec,
    this.tolerance,
  }) : _vsync = vsync,
       _value = value,
       _spec = spec,
       _target = value;

  final TickerProvider _vsync;
  Ticker? _ticker;
  SpringSpec _spec;

  /// 收敛容差。为空时用 1e-3（亚像素级，肉眼不可见）。
  /// 缩放这类只在小数位上变化的量可以放宽，让动画更早停下。
  final double? tolerance;

  double _value;
  double _velocity = 0;
  double _target;
  Duration _lastTick = Duration.zero;

  /// 懒建 Ticker：只有真正发起过动画的实例才占一个 ticker，
  /// 纯静态的按压层（比如从没被按过）不会白白注册。
  Ticker get _tickerOrCreate => _ticker ??= _vsync.createTicker(_onTick);

  /// 当前应当渲染的值（即 presentation value）。
  double get value => _value;

  /// 当前速度，单位与值相同每秒。
  double get velocity => _velocity;

  bool get isAnimating => _ticker?.isActive ?? false;

  set spec(SpringSpec next) => _spec = next;

  /// 跳到某个值并且不产生速度。用于初始化呈现，不算一次运动。
  void snapTo(double next) {
    _ticker?.stop();
    _velocity = 0;
    _lastTick = Duration.zero;
    _target = next;
    if (_value != next) {
      _value = next;
      notifyListeners();
    }
  }

  /// 起弹到 [target]。
  ///
  /// [velocity] 为空时沿用当前速度——手势松手接到动画上时正是靠这一条把
  /// 手指的速度原样交接过去，接缝才看不出来。
  void animateTo(double target, {double? velocity, SpringSpec? spec}) {
    if (spec != null) _spec = spec;
    _target = target;
    if (velocity != null) _velocity = velocity;
    final ticker = _tickerOrCreate;
    if (!ticker.isActive) {
      _lastTick = Duration.zero;
      ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    // 第一帧只用来建立时间基准：Ticker 的 elapsed 从启动时刻算起，
    // 没有上一帧就没有 dt 可算。
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    // 必须写回，否则 dt 恒为 0，仿真永远不会推进（曾经的实际 bug）。
    _lastTick = elapsed;
    if (dt <= 0) return;

    final limit = tolerance;
    final simulation = SpringSimulation(
      _spec.toDescription(),
      _value,
      _target,
      _velocity,
      tolerance: limit == null
          ? const Tolerance(distance: 1e-3, velocity: 1e-3)
          : Tolerance(distance: limit, velocity: limit, time: 1e-3),
    );
    final nextValue = simulation.x(dt);
    final nextVelocity = simulation.dx(dt);
    final done = simulation.isDone(dt);

    _value = done ? _target : nextValue;
    _velocity = done ? 0 : nextVelocity;
    notifyListeners();
    if (done) _tickerOrCreate.stop();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}

/// 一个跟随 [SpringMotion] 重建的构建器。
///
/// 相比 `AnimatedBuilder`，这里用的是自绘的弹簧源，好处是中断时天然从当前值
/// 起步、并携带速度。
class SpringBuilder extends StatelessWidget {
  const SpringBuilder({super.key, required this.motion, required this.builder});

  final SpringMotion motion;
  final ValueWidgetBuilder<double> builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: motion,
    builder: (context, _) => builder(context, motion.value, null),
  );
}

/// 手势速度采样。
///
/// 只存最近一小段时间的采样点：太长的历史会把速度抹平，短了又容易被单帧抖动
/// 带偏。80ms 是滑动松手时常用的一档。
class VelocityTracker1D {
  VelocityTracker1D({this.window = const Duration(milliseconds: 80)});

  final Duration window;
  final _samples = <({Duration time, double position})>[];

  void add(Duration time, double position) {
    _samples.add((time: time, position: position));
    while (_samples.length > 2 && time - _samples.first.time > window) {
      _samples.removeAt(0);
    }
  }

  /// 单位每秒。样本不足时返回 0，调用方据此退回「无速度」的普通动画。
  double get velocity {
    if (_samples.length < 2) return 0;
    final first = _samples.first;
    final last = _samples.last;
    final seconds = (last.time - first.time).inMicroseconds / 1e6;
    if (seconds <= 0) return 0;
    return (last.position - first.position) / seconds;
  }

  void clear() => _samples.clear();
}

/// 值域插值，读起来比 `lerpDouble` 直接。
double lerpValue(double a, double b, double t) => lerpDouble(a, b, t)!;
