import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/chart/presentation/widgets/doji_chart.dart';
import 'package:doji_app/features/gym/data/gym_repository.dart';
import 'package:doji_app/features/home/presentation/widgets/mini_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chart/chart_fixtures.dart';
import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';

void main() {
  testWidgets('me tab: practice, then a backtest on cached history', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.me, seed: chartSeed());
      expect(find.text('practice'), findsOneWidget);
      expect(find.text('account and settings'), findsOneWidget);
      await h.tapText('open backtest');
      expect(h.location, Routes.meBacktest);
      expect(find.text('not tested, needs replay'.toUpperCase()), findsNothing);
      await h.tapText('30 days');
      await h.tapText('fetch history and run', settle: 2000);
      await h.wait(2000);
      expect(find.textContaining('sample prices · not a live feed'), findsWidgets);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.textContaining('in this sample:'), 300, scrollable: list);
      await tester.scrollUntilVisible(
        find.textContaining('when a bar reaches both your stop and your target'),
        300,
        scrollable: list,
      );
      await tester.scrollUntilVisible(find.text('refine this strategy'), 300, scrollable: list);
      await h.tapText('refine this strategy');
      expect(h.location, Routes.meCompare);
      await h.tapText('3R');
      expect(find.textContaining('changed: target 2R → 3R'), findsOneWidget);
      expect(find.text('stop · waits for the run'), findsOneWidget);
    });
  });

  testWidgets('replay: next bar shows exactly one more bar, never the ones ahead', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.replay('EURUSD', day: DateTime.utc(2026, 7, 14)),
        seed: chartSeed(),
      );
      await h.wait(1500);
      List<DateTime> shown() =>
          tester.widget<DojiChart>(find.byType(DojiChart)).bars.map((b) => b.at).toList();
      final before = shown();
      expect(before, isNotEmpty);
      // The replay starts at the Tokyo open of the day: nothing of the day itself yet.
      expect(before.last.isBefore(DateTime.utc(2026, 7, 14)), isTrue);
      await h.tapText('next bar (N)');
      final after = shown();
      expect(after.length, before.length + 1);
      expect(after.last.isAfter(before.last), isTrue);
      expect(find.textContaining('bars ahead hidden'), findsOneWidget);
      await h.tapText('jump to london open');
      final london = shown();
      expect(london.last, DateTime.utc(2026, 7, 14, 7));
    });
  });

  testWidgets('gym drills without history: after-losses drills, then the day counts as practice on Home', (
    tester,
  ) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.drills, seed: chartSeed());
      await h.wait(500);
      expect(find.textContaining('run a backtest first'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await h.tapText('no');
        expect(find.textContaining('your rules'), findsWidgets);
        await h.tapText(i == 2 ? 'finish' : 'next drill');
      }
      expect(find.textContaining('set done:'), findsOneWidget);
      expect(h.container.read(gymProvider).where((e) => e.kind == GymEntryKind.drillSet), hasLength(1));
      expect(h.container.read(drillStreakProvider), 1);
      h.router.go(Routes.home);
      await h.wait(800);
      final grid = tester.widgetList<MiniGrid>(find.byType(MiniGrid)).last;
      expect(grid.practice, hasLength(1));
      expect(find.bySemanticsLabel(RegExp('1 practice day marked with a dot')), findsOneWidget);
    });
  });

  for (final at in [Routes.me, Routes.meGym, Routes.meReplays, Routes.meBacktest, Routes.drills]) {
    testWidgets('$at: labelled 44pt targets, contrast, 200% text', (tester) async {
      await withClock(summerDay, () async {
        final h = await AppHarness.pump(tester, at: at, seed: chartSeed(), textScale: 2);
        await h.wait(500);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }, variant: ios);
  }

  testWidgets('refine without history says so and points to the backtest', (tester) async {
    await withClock(summerDay, () async {
      await AppHarness.pump(tester, at: Routes.meCompare, seed: chartSeed());
      expect(find.text('no history cached yet. run a backtest first.'), findsOneWidget);
      expect(find.byType(DojiChart), findsNothing);
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
