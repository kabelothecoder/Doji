// Goldens for the mind toolkit (design: Doji Me Phone › toolkit) on iPhone 390 × 844.
//
//   flutter test test/goldens --update-goldens   # after an intended change
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';

final _seed = {
  ...seedProfile(),
  ...seedJournal([
    sampleTrade(id: 'a', pnl: 1, plan: PlanFollowed.yes, now: summerDay.now()),
    sampleTrade(id: 'b', pnl: -1, daysAgo: 1, plan: PlanFollowed.no, now: summerDay.now()),
  ]),
};

void main() {
  for (final (route, name) in [
    (Routes.mind, 'toolkit'),
    (Routes.mindScorecard, 'scorecard'),
    (Routes.mindPrompts, 'prompts'),
    (Routes.mindAffirmations, 'affirmations'),
    (Routes.mindReading, 'reading'),
  ]) {
    testWidgets('mind · $name phone', (tester) async {
      await withClock(summerDay, () async {
        final h = await AppHarness.pump(tester, at: route, seed: _seed);
        await h.wait(500);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('mind_${name}_phone.png'));
      });
    }, variant: ios);
  }
}
