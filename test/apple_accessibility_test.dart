import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/design/apple_accessibility.dart';

const _channel = MethodChannel('cn.yanyn.community/accessibility');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('native preferences augment MediaQuery and preserve other data', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => {
        'reduceMotion': true,
        'reduceTransparency': true,
        'highContrast': true,
      },
    );
    const original = MediaQueryData(
      size: Size(712, 400),
      textScaler: TextScaler.linear(1.6),
    );
    await tester.pumpWidget(
      const MediaQuery(
        data: original,
        child: AppleAccessibility(child: SizedBox(key: ValueKey('content'))),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byKey(const ValueKey('content')));
    final merged = MediaQuery.of(context);
    expect(merged.disableAnimations, isTrue);
    expect(merged.highContrast, isTrue);
    expect(merged.size, const Size(712, 400));
    expect(merged.textScaler, const TextScaler.linear(1.6));
    expect(AppleAccessibility.reduceTransparencyOf(context), isTrue);
  });

  testWidgets('native callback updates and clears preferences', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => {
        'reduceMotion': false,
        'reduceTransparency': false,
        'highContrast': false,
      },
    );
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: AppleAccessibility(child: SizedBox(key: ValueKey('content'))),
      ),
    );
    await tester.pump();

    Future<void> notify(Map<String, bool> values) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('preferencesChanged', values),
        ),
        null,
      );
      await tester.pump();
    }

    await notify({
      'reduceMotion': true,
      'reduceTransparency': true,
      'highContrast': true,
    });
    var context = tester.element(find.byKey(const ValueKey('content')));
    expect(MediaQuery.of(context).disableAnimations, isTrue);
    expect(MediaQuery.of(context).highContrast, isTrue);
    expect(AppleAccessibility.reduceTransparencyOf(context), isTrue);

    await notify({
      'reduceMotion': false,
      'reduceTransparency': false,
      'highContrast': false,
    });
    context = tester.element(find.byKey(const ValueKey('content')));
    expect(MediaQuery.of(context).disableAnimations, isFalse);
    expect(MediaQuery.of(context).highContrast, isFalse);
    expect(AppleAccessibility.reduceTransparencyOf(context), isFalse);
  });

  testWidgets('Flutter accessibility changes update motion and contrast', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: AppleAccessibility(child: SizedBox(key: ValueKey('content'))),
      ),
    );
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true, highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    final context = tester.element(find.byKey(const ValueKey('content')));
    expect(MediaQuery.of(context).disableAnimations, isTrue);
    expect(MediaQuery.of(context).highContrast, isTrue);
    expect(AppleAccessibility.reduceTransparencyOf(context), isFalse);
  });

  testWidgets(
    'inherited flags survive absent bridge and disappear on dispose',
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true, highContrast: true),
          child: AppleAccessibility(child: SizedBox(key: ValueKey('content'))),
        ),
      );
      await tester.pump();
      var context = tester.element(find.byKey(const ValueKey('content')));
      expect(MediaQuery.of(context).disableAnimations, isTrue);
      expect(MediaQuery.of(context).highContrast, isTrue);
      expect(AppleAccessibility.reduceTransparencyOf(context), isFalse);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(key: ValueKey('outside')),
        ),
      );
      context = tester.element(find.byKey(const ValueKey('outside')));
      expect(AppleAccessibility.reduceTransparencyOf(context), isFalse);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('preferencesChanged', {'reduceTransparency': true}),
        ),
        null,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
