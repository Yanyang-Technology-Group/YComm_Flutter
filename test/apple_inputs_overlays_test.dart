import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/design/apple_theme.dart';
import 'package:ycomm_client/core/design/adaptive_inputs.dart';
import 'package:ycomm_client/core/design/adaptive_overlays.dart';

void main() {
  Widget app(Widget child) => m.MaterialApp(
    theme: m.ThemeData(extensions: [AppleTokens.of(m.Brightness.light)]),
    home: m.Scaffold(body: child),
  );

  testWidgets('Apple form field validates and preserves typed text', (
    tester,
  ) async {
    final form = GlobalKey<m.FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        m.Form(
          key: form,
          child: AppTextFormField(
            controller: controller,
            decoration: const m.InputDecoration(labelText: 'Name'),
            validator: (value) => value == 'Ada' ? null : 'Enter Ada',
          ),
        ),
      ),
    );
    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Enter Ada'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField), 'Ada');
    expect(controller.text, 'Ada');
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets('Apple dropdown saves the selected value', (tester) async {
    final form = GlobalKey<m.FormState>();
    String? saved;
    await tester.pumpWidget(
      app(
        m.Form(
          key: form,
          child: AppDropdownButtonFormField<String>(
            decoration: const m.InputDecoration(labelText: 'Choice'),
            items: const [
              m.DropdownMenuItem(value: 'a', child: m.Text('Alpha')),
              m.DropdownMenuItem(value: 'b', child: m.Text('Beta')),
            ],
            onChanged: (_) {},
            onSaved: (value) => saved = value,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CupertinoButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta').last);
    await tester.pumpAndSettle();
    form.currentState!.save();
    expect(saved, 'b');
    expect(find.byType(m.DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('Apple form field follows controller updates and reset', (
    tester,
  ) async {
    final form = GlobalKey<m.FormState>();
    final controller = TextEditingController(text: 'start');
    addTearDown(controller.dispose);
    String? saved;
    await tester.pumpWidget(
      app(
        m.Form(
          key: form,
          child: AppTextFormField(
            controller: controller,
            onSaved: (value) => saved = value,
          ),
        ),
      ),
    );
    controller.text = 'external';
    await tester.pump();
    form.currentState!.save();
    expect(saved, 'external');
    await tester.enterText(find.byType(CupertinoTextField), 'edited');
    form.currentState!.reset();
    await tester.pump();
    expect(controller.text, 'start');
  });

  testWidgets('Apple dialog returns the action result', (tester) async {
    String? result;
    await tester.pumpWidget(
      app(
        m.Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => result = await appShowDialog<String>(
              context: context,
              builder: (dialogContext) => AppAlertDialog(
                title: const m.Text('Confirm'),
                actions: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(dialogContext, 'yes'),
                    child: const m.Text('Yes'),
                  ),
                ],
              ),
            ),
            child: const m.Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(result, 'yes');
  });

  testWidgets('Apple setting labels toggle their controls', (tester) async {
    bool switchValue = false;
    bool? checkValue = false;
    await tester.pumpWidget(
      app(
        m.Column(
          children: [
            AppSwitchListTile(
              value: false,
              onChanged: (value) => switchValue = value,
              title: const m.Text('Switch setting'),
            ),
            AppCheckboxListTile(
              value: false,
              onChanged: (value) => checkValue = value,
              title: const m.Text('Check setting'),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Switch setting'));
    await tester.tap(find.text('Check setting'));
    expect(switchValue, isTrue);
    expect(checkValue, isTrue);
  });

  testWidgets('disabled popup item is announced disabled and cannot select', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      app(
        AppPopupMenuButton<String>(
          onSelected: (value) => selected = value,
          itemBuilder: (_) => const [
            m.PopupMenuItem(
              value: 'locked',
              enabled: false,
              child: m.Text('Locked'),
            ),
            m.PopupMenuItem(value: 'open', child: m.Text('Open item')),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(CupertinoButton));
    await tester.pumpAndSettle();
    expect(find.byType(m.PopupMenuItem<String>), findsNothing);
    final semantics = tester.getSemantics(find.text('Locked'));
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    await tester.tap(find.text('Locked'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('Open item'));
    await tester.pumpAndSettle();
    expect(selected, 'open');
  });

  testWidgets('Apple text field honors decoration state and character count', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'ab');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        AppTextField(
          controller: controller,
          maxLength: 4,
          decoration: const m.InputDecoration(
            labelText: 'Code',
            enabled: false,
            errorText: 'Invalid',
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .enabled,
      isFalse,
    );
    expect(find.text('Invalid'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
  });

  testWidgets('empty counterText hides the Apple character counter', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        AppTextField(
          controller: controller,
          maxLength: 100000,
          decoration: const m.InputDecoration(counterText: ''),
        ),
      ),
    );
    expect(find.text('0/100000'), findsNothing);
  });

  testWidgets('Apple chip inherits app font family and fallback', (
    tester,
  ) async {
    TextStyle? labelStyle;
    await tester.pumpWidget(
      m.MaterialApp(
        theme: m.ThemeData(
          extensions: [AppleTokens.of(m.Brightness.light)],
          textTheme: const m.TextTheme(
            bodyMedium: m.TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: ['CJKFallback'],
            ),
          ),
        ),
        home: m.Scaffold(
          body: AppChoiceChip(
            selected: true,
            onSelected: (_) {},
            label: Builder(
              builder: (context) {
                labelStyle = DefaultTextStyle.of(context).style;
                return const Text('Chip');
              },
            ),
          ),
        ),
      ),
    );
    expect(labelStyle?.fontFamily, 'AppFont');
    expect(labelStyle?.fontFamilyFallback, ['CJKFallback']);
  });

  testWidgets(
    'Apple form field fits narrow enlarged text with error and icons',
    (tester) async {
      tester.view.physicalSize = const Size(240, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final form = GlobalKey<m.FormState>();
      await tester.pumpWidget(
        app(
          m.MediaQuery(
            data: const m.MediaQueryData(textScaler: m.TextScaler.linear(2)),
            child: m.Form(
              key: form,
              child: AppTextFormField(
                maxLength: 8,
                decoration: const m.InputDecoration(
                  labelText: 'Verification code',
                  helperText: 'Enter the code from your email',
                  prefixIcon: Icon(CupertinoIcons.lock),
                  suffixIcon: Icon(CupertinoIcons.clear),
                ),
                validator: (_) => 'Required',
              ),
            ),
          ),
        ),
      );
      form.currentState!.validate();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Required'), findsOneWidget);
    },
  );

  testWidgets('Apple dialog stays within narrow keyboard-safe viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      app(
        m.MediaQuery(
          data: const m.MediaQueryData(
            viewInsets: m.EdgeInsets.only(bottom: 180),
            textScaler: m.TextScaler.linear(2),
          ),
          child: AppDialog(
            child: m.SizedBox(height: 460, child: m.Text('Captcha')),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(SingleChildScrollView)).height,
      lessThanOrEqualTo(172),
    );
  });

  testWidgets('reduced motion dialog has no scale transition', (tester) async {
    await tester.pumpWidget(
      app(
        m.MediaQuery(
          data: const m.MediaQueryData(disableAnimations: true),
          child: m.Builder(
            builder: (context) => CupertinoButton(
              onPressed: () => appShowDialog<void>(
                context: context,
                builder: (_) => const AppAlertDialog(title: m.Text('Reduced')),
              ),
              child: const m.Text('Show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pump();
    expect(
      find.ancestor(
        of: find.text('Reduced'),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('reduced motion dropdown and popup do not slide', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      app(
        m.MediaQuery(
          data: const m.MediaQueryData(disableAnimations: true),
          child: m.Column(
            children: [
              AppDropdownButtonFormField<String>(
                items: const [
                  m.DropdownMenuItem(value: 'b', child: m.Text('Beta')),
                ],
                onChanged: (_) {},
              ),
              AppPopupMenuButton<String>(
                itemBuilder: (_) => const [
                  m.PopupMenuItem(value: 'one', child: m.Text('Menu item')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CupertinoButton).first);
    await tester.pump();
    expect(
      find.ancestor(
        of: find.text('Beta'),
        matching: find.byType(FractionalTranslation),
      ),
      findsNothing,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppPopupMenuButton<String>));
    await tester.pump();
    // Cupertino uses fractional translations for anchor alignment even when
    // stationary. Check screen geometry under the real iOS accessibility flag.
    final opening = tester.getRect(find.text('Menu item'));
    await tester.pump(const Duration(milliseconds: 100));
    final later = tester.getRect(find.text('Menu item'));
    expect(later, opening);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Menu item')), opening);
  });

  testWidgets('reduced motion sheet and date picker do not slide', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        m.MediaQuery(
          data: const m.MediaQueryData(disableAnimations: true),
          child: m.Builder(
            builder: (context) => m.Column(
              children: [
                CupertinoButton(
                  onPressed: () => appShowModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const m.Text('Sheet content'),
                  ),
                  child: const m.Text('Sheet'),
                ),
                CupertinoButton(
                  onPressed: () => appShowDatePicker(
                    context: context,
                    firstDate: DateTime(2026),
                    lastDate: DateTime(2028),
                    initialDate: DateTime(2027),
                  ),
                  child: const m.Text('Date'),
                ),
                CupertinoButton(
                  onPressed: () => appShowTimePicker(
                    context: context,
                    initialTime: const m.TimeOfDay(hour: 9, minute: 30),
                  ),
                  child: const m.Text('Time'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sheet'));
    await tester.pump();
    expect(
      find.ancestor(
        of: find.text('Sheet content'),
        matching: find.byType(FractionalTranslation),
      ),
      findsNothing,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date'));
    await tester.pump();
    expect(
      find.ancestor(
        of: find.byType(CupertinoDatePicker),
        matching: find.byType(FractionalTranslation),
      ),
      findsNothing,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Time'));
    await tester.pump();
    expect(
      find.ancestor(
        of: find.byType(CupertinoDatePicker),
        matching: find.byType(FractionalTranslation),
      ),
      findsNothing,
    );
  });
}
