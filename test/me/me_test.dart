// Doji Me Phone: profile, rank ladder, badges from kept days.
import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/features/me/domain/me.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final badges = badgesFor([...kept, broke]);
    expect(badges.map((b) => b.earned), [false, true, false, true]);
    expect(badges[2].line, 'locked · 8 of 30 days');
    expect(keptStreak(keptDays([broke])), 0);
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
