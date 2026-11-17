// Goldens for the analyst slice (no design file; design/SOURCE.md › Missing):
// the weekly review, Home's payout rules and the account's sources, on iPhone
// 390 × 844, and the weekly review on Windows.
//
//   flutter test test/goldens --update-goldens   # after an intended change
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../analyst/analyst_fixtures.dart';
import '../chart/chart_fixtures.dart';
import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';

Future<void> _match(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('analyst_$name.png'));

Future<void> _review(WidgetTester tester, Size size) async {
  final h = await AppHarness.pump(
    tester,
    at: Routes.journal,
    seed: chartSeed(extra: seedJournal(lastWeekTrades(20))),
    size: size,
  );
  await h.wait(800);
  await tester.scrollUntilVisible(find.text('WEEKLY REVIEW'), 300, scrollable: find.byType(Scrollable).first);
  await h.wait(300);
}

void main() {
  testWidgets('analyst · weekly review phone', (tester) async {
    await withClock(summerDay, () async {
      await _review(tester, const Size(390, 844));
      await _match('review_phone');
    });
  }, variant: ios);

  testWidgets('analyst · weekly review windows', (tester) async {
    await withClock(summerDay, () async {
      await _review(tester, const Size(1280, 800));
      await _match('review_windows');
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('analyst · payout rules phone', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.home, seed: propSeed());
      await h.wait(800);
      await tester.scrollUntilVisible(
        find.text('PAYOUT RULES'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await h.wait(300);
      await _match('payout_phone');
    });
  }, variant: ios);

  testWidgets('analyst · sources phone', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.accountEditor(kFirstAccountId), seed: chartSeed());
      await h.wait(500);
      await tester.scrollUntilVisible(find.text('add a pdf'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('my sources'));
      await h.wait(300);
      await _match('sources_phone');
    });
  }, variant: ios);
}
