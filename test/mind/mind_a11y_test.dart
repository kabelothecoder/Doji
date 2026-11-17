// Mind toolkit at 1x and 2x text: every screen, no overflow, labelled targets.
import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';

final _seed = {
  ...seedProfile(),
  ...seedJournal([
    for (var d = 0; d < 3; d++)
      sampleTrade(id: 'k$d', pnl: 1, daysAgo: d, plan: PlanFollowed.yes, now: summerDay.now()),
  ]),
};

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final route in [
      Routes.mind,
      Routes.mindScorecard,
      Routes.mindPrompts,
      Routes.mindAffirmations,
      Routes.mindReading,
      Routes.mindArticle('after-a-loss'),
    ]) {
      testWidgets('$route at ${scale}x text', (tester) async {
        await withClock(summerDay, () async {
          final h = await AppHarness.pump(tester, at: route, seed: _seed, textScale: scale);
          await h.wait(300);
          expect(tester.takeException(), isNull, reason: 'no overflow at ${scale}x');
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          if (route == Routes.mindScorecard) {
            expect(find.bySemanticsLabel(RegExp('plan kept: 3 of 3 reviewed trades')), findsOneWidget);
          }
        });
      }, variant: ios);
    }
  }
}
