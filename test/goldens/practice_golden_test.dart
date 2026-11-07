// Goldens for practice (no design file; design/SOURCE.md › Missing): the
// refine comparison on iPhone 390 × 844 and Windows, and a drill on iPhone.
//
//   flutter test test/goldens --update-goldens   # after an intended change
//
// Sample prices, 30 days up to a pinned summer Wednesday.
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chart/chart_fixtures.dart';
import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';

Future<void> _match(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('practice_$name.png'));

Future<void> _compare(WidgetTester tester, Size size) async {
  final h = await AppHarness.pump(tester, at: Routes.meBacktest, seed: chartSeed(), size: size);
  await h.tapText('30 days');
  await h.tapText('fetch history and run', settle: 2000);
  h.router.go(Routes.meCompare);
  await h.wait(500);
  await h.tapText('3R');
  await h.tapText('run both on the tuning period', settle: 1500);
  await tester.scrollUntilVisible(find.text('TUNING PERIOD'), 300, scrollable: find.byType(Scrollable).first);
  await h.wait(300);
}

void main() {
  testWidgets('practice · compare phone', (tester) async {
    await withClock(summerDay, () async {
      await _compare(tester, const Size(390, 844));
      await _match('compare_phone');
    });
  }, variant: ios);

  testWidgets('practice · compare windows', (tester) async {
    await withClock(summerDay, () async {
      await _compare(tester, const Size(1280, 800));
      await _match('compare_windows');
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('practice · drill phone', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.drills, seed: chartSeed());
      await h.wait(500);
      await h.tapText('no');
      await _match('drill_phone');
    });
  }, variant: ios);
}
