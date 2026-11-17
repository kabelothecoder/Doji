// Me tab at 1x and 2x text: profile, badges, share card.
import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';

final _seed = seedJournal([
  for (var d = 0; d < 8; d++)
    sampleTrade(id: 'k$d', pnl: 1, daysAgo: d, plan: PlanFollowed.yes, now: summerDay.now()),
]);

Future<void> _guidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final route in [Routes.me, Routes.meBadges, Routes.shareCard]) {
      testWidgets('$route at ${scale}x text', (tester) async {
        await withClock(summerDay, () async {
          final h = await AppHarness.pump(tester, at: route, seed: _seed, textScale: scale);
          await h.wait(300);
          expect(tester.takeException(), isNull, reason: 'no overflow at ${scale}x');
          await _guidelines(tester);
          if (route == Routes.me) {
            expect(find.bySemanticsLabel(RegExp('doji grid jan – jun')), findsOneWidget);
          }
          if (route == Routes.meBadges) {
            expect(find.bySemanticsLabel(RegExp('first practice day badge, locked')), findsOneWidget);
          }
        });
      }, variant: ios);
    }
  }
}
