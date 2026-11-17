// Goldens for mood (check-in, trends, tracker) and coach history on iPhone
// 390 × 844, on summerDay.
//
//   flutter test test/goldens --update-goldens   # after an intended change
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../mood/mood_a11y_test.dart' show moodSeed;

Future<void> _shot(WidgetTester tester, String route, String name) async {
  final h = await AppHarness.pump(tester, at: route, seed: moodSeed());
  await h.wait(500);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('mood_$name.png'));
}

void main() {
  testWidgets('mood · phone', (tester) async {
    await withClock(summerDay, () => _shot(tester, Routes.mood, 'phone'));
  }, variant: ios);

  testWidgets('coach history · phone', (tester) async {
    await withClock(summerDay, () => _shot(tester, Routes.coachHistory, 'coach_history_phone'));
  }, variant: ios);

  testWidgets('coach transcript · phone', (tester) async {
    await withClock(summerDay, () => _shot(tester, Routes.coachTranscript('s1'), 'coach_transcript_phone'));
  }, variant: ios);
}
