// Goldens for the me tab (design: Doji Me Phone, Doji Share Card) on iPhone
// 390 × 844, with eight kept days and three drill days.
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

final _seed = seedJournal([
  for (var d = 0; d < 8; d++)
    sampleTrade(id: 'k$d', pnl: 1, daysAgo: d, plan: PlanFollowed.yes, now: summerDay.now()),
  sampleTrade(id: 'b', pnl: 1, daysAgo: 10, plan: PlanFollowed.no, now: summerDay.now()),
]);

Future<void> _shot(WidgetTester tester, String route, String name) async {
  final h = await AppHarness.pump(tester, at: route, seed: _seed);
  await h.wait(500);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('me_$name.png'));
}

void main() {
  testWidgets('me · profile phone', (tester) async {
    await withClock(summerDay, () => _shot(tester, Routes.me, 'profile_phone'));
  }, variant: ios);

  testWidgets('me · badges phone', (tester) async {
    await withClock(summerDay, () => _shot(tester, Routes.meBadges, 'badges_phone'));
  }, variant: ios);

  testWidgets('me · share card phone', (tester) async {
    await withClock(summerDay, () => _shot(tester, Routes.shareCard, 'share_phone'));
  }, variant: ios);
}
