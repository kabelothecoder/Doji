// Goldens for the four onboarding moments the brief asks for, on the two
// frame sizes the handoff draws: iPhone 390 × 844 and Windows 1440 × 900.
//
//   flutter test test/goldens --update-goldens   # after an intended change
//
// Rendered with reduce motion on, so typing is complete and cursors are solid.
// Goldens are generated on Windows; font rasterisation differs slightly per
// OS, so CI should run them on the same platform (see README).
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:doji_app/core/theme/doji_theme.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/clocks.dart';
import '../helpers/fakes.dart';
import '../helpers/sample_profile.dart';

enum _Frame {
  phone(Size(390, 844), TargetPlatform.iOS),
  windows(Size(1440, 900), TargetPlatform.windows);

  const _Frame(this.size, this.platform);

  final Size size;
  final TargetPlatform platform;
}

/// On a fixed summer day: the ritual time and "30m pre-london" follow daylight
/// saving, so the golden must not depend on the season it is run in.
Future<void> _pumpStep(
  WidgetTester tester,
  _Frame frame,
  String stepId, {
  String? lastAnswered,
  Future<void> Function()? arrange,
}) => withClock(summerDay, () => _pump(tester, frame, stepId, lastAnswered: lastAnswered, arrange: arrange));

Future<void> _pump(
  WidgetTester tester,
  _Frame frame,
  String stepId, {
  String? lastAnswered,
  Future<void> Function()? arrange,
}) async {
  tester.view.physicalSize = frame.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(resumeAt(stepId, lastAnswered: lastAnswered));
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(prefs),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dojiDarkTheme(platform: frame.platform),
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: const OnboardingScreen(),
      ),
    ),
  );
  // Let zero-length timers (line pauses, compile) and post-frame callbacks run.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (arrange != null) {
    await arrange();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

void main() {
  for (final frame in _Frame.values) {
    group(frame.name, () {
      setUp(() => debugDefaultTargetPlatformOverride = frame.platform);
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      testWidgets('boot', (tester) async {
        await _pumpStep(tester, frame, StepIds.boot);
        await expectLater(find.byType(OnboardingScreen), matchesGoldenFile('boot_${frame.name}.png'));
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('question · risk per trade (custom 3%)', (tester) async {
        await _pumpStep(
          tester,
          frame,
          StepIds.risk,
          lastAnswered: StepIds.strategyParsed,
          arrange: () => tester.tap(find.text('custom')),
        );
        expect(find.textContaining('3% is above what most plans allow'), findsOneWidget);
        await expectLater(
          find.byType(OnboardingScreen),
          matchesGoldenFile('question_risk_${frame.name}.png'),
        );
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('compile', (tester) async {
        await _pumpStep(tester, frame, StepIds.compile, lastAnswered: StepIds.ritual);
        expect(find.text('everyone starts here.'), findsOneWidget);
        await expectLater(find.byType(OnboardingScreen), matchesGoldenFile('compile_${frame.name}.png'));
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('pledge', (tester) async {
        await _pumpStep(tester, frame, StepIds.pledge);
        await expectLater(find.byType(OnboardingScreen), matchesGoldenFile('pledge_${frame.name}.png'));
        debugDefaultTargetPlatformOverride = null;
      });
    });
  }
}
