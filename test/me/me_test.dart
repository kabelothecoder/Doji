// Doji Me Phone: profile, rank ladder, badges from kept days.
import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/core/widgets/grid_cell.dart';
import 'package:doji_app/features/me/data/badge_repository.dart';
import 'package:doji_app/features/me/domain/me.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doji_app/features/journal/presentation/journal_controller.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';

void main() {
  test('kept days, streak and badges', () {
    final kept = [
      for (var d = 0; d < 8; d++) sampleTrade(id: 'k$d', pnl: -10, daysAgo: d, plan: PlanFollowed.yes),
    ];
    final broke = sampleTrade(id: 'b', pnl: 50, daysAgo: 9, plan: PlanFollowed.no);
    final unreviewed = sampleTrade(id: 'u', pnl: 5, daysAgo: 10);
    final days = keptDays([...kept, broke, unreviewed]);
    expect(days.length, 9);
    expect(keptStreak(days), 8);
    expect(bestKeptStreak(days), 8);
    final practice = {for (var d = 1; d <= 3; d++) DateTime(2026, 7, d)};
    final ids = earnedBadgeIds([...kept, broke], practice);
    expect(ids, {'streak7', 'cleanWeek', 'firstPractice'});
    final badges = badgesFor([...kept, broke], practice, ids);
    expect(badges.map((b) => b.earned), [false, true, false, true, true, false]);
    expect(badges[2].line, 'locked · 8 of 30 days');
    expect(badges[5].line, 'locked · 3 of 10 days');
    expect(keptStreak(keptDays([broke])), 0);
    // Nothing is earned from nothing: founding never, streaks need reviewed days.
    expect(earnedBadgeIds([], {}), isEmpty);
    expect(earnedBadgeIds([unreviewed], {}), isEmpty);
    expect(earnedBadgeIds([], {for (var d = 1; d <= 10; d++) DateTime(2026, 7, d)}), {
      'firstPractice',
      'practice10',
    });
  });

  test('grid cells: kept L4, broken L1, empty L0, today, future', () {
    final today = DateTime(2026, 7, 15, 10);
    final kept = {DateTime(2026, 7, 13): true, DateTime(2026, 7, 14): false};
    expect(dayCell(DateTime(2026, 7, 13), kept, today), GridCellState.l4);
    expect(dayCell(DateTime(2026, 7, 14), kept, today), GridCellState.l1);
    expect(dayCell(DateTime(2026, 7, 12), kept, today), GridCellState.l0);
    expect(dayCell(DateTime(2026, 7, 15), kept, today), GridCellState.today);
    expect(dayCell(DateTime(2026, 7, 16), kept, today), GridCellState.future);
  });

  testWidgets('badges are stored under doji.badges.v1 and stay earned when the trades go', (tester) async {
    await withClock(summerDay, () async {
      final trades = [
        for (var d = 0; d < 7; d++)
          sampleTrade(id: 'k$d', pnl: 1, daysAgo: d, plan: PlanFollowed.yes, now: summerDay.now()),
      ];
      final h = await AppHarness.pump(tester, at: Routes.meBadges, seed: seedJournal(trades));
      expect(find.bySemanticsLabel(RegExp('7-day streak badge, earned')), findsOneWidget);
      expect(h.prefs.getString(BadgeRepository.key), contains('streak7'));
      await h.prefs.remove('doji.journal.v1');
      h.container.invalidate(journalControllerProvider);
      expect(h.container.read(earnedBadgesProvider).keys, contains('streak7'));
    });
  });

  testWidgets('me tab shows the profile; badges, practice and the panic flow open from it', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.me);
      expect(find.text('RANK LADDER'), findsOneWidget);
      expect(find.text('you are here'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('i blew my account'), 300);
      await h.tapText('badges');
      expect(h.location, Routes.meBadges);
      expect(find.bySemanticsLabel(RegExp('7-day streak badge, locked')), findsOneWidget);
      await h.tap(find.bySemanticsLabel('back').last);
      await tester.scrollUntilVisible(find.text('i blew my account'), 300);
      await h.tapText('practice');
      expect(h.location, Routes.mePractice);
      await h.tap(find.bySemanticsLabel('back').last);
      await tester.scrollUntilVisible(find.text('i blew my account'), 300);
      await h.tapText('i blew my account');
      expect(h.location, Routes.panic);
    });
  });
}
