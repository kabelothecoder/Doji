// Accessibility floor from the brief: touch targets ≥ 44pt (48dp Android),
// labelled tap targets, contrast ≥ 4.5:1, text scaling to 200% without
// clipping, and keyboard-first on Windows.
import 'package:doji_app/core/theme/doji_theme.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:doji_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/sample_profile.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  String step, {
  Size size = const Size(390, 844),
  double textScale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(resumeAt(step));
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: testOverrides(prefs));
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dojiDarkTheme(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const OnboardingScreen(),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return container;
}

void main() {
  const steps = [
    StepIds.boot,
    StepIds.experience,
    StepIds.markets,
    StepIds.goal,
    StepIds.risk,
    StepIds.coach,
    StepIds.ritual,
  ];

  for (final step in steps) {
    testWidgets('$step: tap targets, labels and contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, step);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('android: 48dp targets', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final handle = tester.ensureSemantics();
      await _pump(tester, StepIds.risk, size: const Size(412, 915), platform: TargetPlatform.android);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final step in [
    StepIds.boot,
    StepIds.name,
    StepIds.goal,
    StepIds.risk,
    StepIds.rules,
    StepIds.pledge,
  ]) {
    testWidgets('$step renders at 200% text without overflow', (tester) async {
      await _pump(tester, step, textScale: 2);
      // Any RenderFlex overflow or clipped layout throws during pump.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard only: number keys pick, Enter continues, Esc goes back', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final c = await _pump(
      tester,
      StepIds.style,
      size: const Size(1440, 900),
      platform: TargetPlatform.windows,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2); // "day trader" (multi-select)
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(c.read(onboardingControllerProvider).currentId, StepIds.markets);
    expect(c.read(onboardingControllerProvider).answers[StepIds.style], ['day_trader']);

    await tester.sendKeyEvent(
      LogicalKeyboardKey.digit1,
    ); // first instrument: EURUSD (forex is the first group)
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(c.read(onboardingControllerProvider).currentId, StepIds.sessions);
    expect(c.read(onboardingControllerProvider).answers[StepIds.markets], ['EURUSD']);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(c.read(onboardingControllerProvider).currentId, StepIds.markets);
    debugDefaultTargetPlatformOverride = null;
  });
}
