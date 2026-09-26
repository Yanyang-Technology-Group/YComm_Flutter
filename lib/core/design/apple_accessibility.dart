import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Applies Apple display accessibility preferences to an existing widget tree.
class AppleAccessibility extends StatefulWidget {
  const AppleAccessibility({super.key, required this.child});

  final Widget child;

  static bool reduceTransparencyOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_AppleAccessibilityScope>()
          ?.reduceTransparency ??
      false;

  @override
  State<AppleAccessibility> createState() => _AppleAccessibilityState();
}

class _AppleAccessibilityState extends State<AppleAccessibility>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('cn.yanyn.community/accessibility');

  bool _reduceMotion = false;
  bool _reduceTransparency = false;
  bool _highContrast = false;
  bool _receivedNativeChange = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleNativeCall);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await _channel.invokeMapMethod<String, dynamic>(
        'getPreferences',
      );
      if (mounted && !_receivedNativeChange && preferences != null) {
        _applyPreferences(preferences);
      }
    } on MissingPluginException {
      // The bridge is available only on Apple platforms.
    } on PlatformException {
      // Keep Flutter's accessibility values when a native bridge is unavailable.
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'preferencesChanged' || !mounted) return;
    final preferences = call.arguments;
    if (preferences is! Map) return;
    _receivedNativeChange = true;
    _applyPreferences(preferences);
  }

  void _applyPreferences(Map preferences) {
    final reduceMotion = preferences['reduceMotion'] == true;
    final reduceTransparency = preferences['reduceTransparency'] == true;
    final highContrast = preferences['highContrast'] == true;
    if (_reduceMotion == reduceMotion &&
        _reduceTransparency == reduceTransparency &&
        _highContrast == highContrast) {
      return;
    }
    setState(() {
      _reduceMotion = reduceMotion;
      _reduceTransparency = reduceTransparency;
      _highContrast = highContrast;
    });
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    final merged = original.copyWith(
      disableAnimations:
          original.disableAnimations ||
          features.disableAnimations ||
          features.reduceMotion ||
          _reduceMotion,
      highContrast:
          original.highContrast || features.highContrast || _highContrast,
    );
    return _AppleAccessibilityScope(
      reduceTransparency: _reduceTransparency,
      child: MediaQuery(data: merged, child: widget.child),
    );
  }
}

class _AppleAccessibilityScope extends InheritedWidget {
  const _AppleAccessibilityScope({
    required this.reduceTransparency,
    required super.child,
  });

  final bool reduceTransparency;

  @override
  bool updateShouldNotify(_AppleAccessibilityScope oldWidget) =>
      reduceTransparency != oldWidget.reduceTransparency;
}
