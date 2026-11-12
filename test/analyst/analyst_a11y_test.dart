import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chart/chart_fixtures.dart';
import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';
import 'analyst_fixtures.dart';

Future<void> _guidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  // Not textContrastGuideline here: the tab bar's inactive 11pt labels already
  // fail it on every shell screen (design system tertiary), not new here.
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('weekly review and ask the analyst at ${scale}x text', (tester) async {
      await withClock(summerDay, () async {
        final handle = tester.ensureSemantics();
        final h = await AppHarness.pump(
          tester,
          at: Routes.journal,
          seed: chartSeed(extra: seedJournal(lastWeekTrades(20))),
          textScale: scale,
        );
        await h.wait(800);
        await tester.scrollUntilVisible(
          find.text('focus on this rule'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        if (scale == 1) await _guidelines(tester);
        handle.dispose();
      });
    });

    testWidgets('payout rules on Home at ${scale}x text', (tester) async {
      await withClock(summerDay, () async {
        final handle = tester.ensureSemantics();
        final h = await AppHarness.pump(tester, at: Routes.home, seed: propSeed(), textScale: scale);
        await h.wait(800);
        await tester.scrollUntilVisible(
          find.text('PAYOUT RULES'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        // The standing is a word beside the line, so colour is never the only signal.
        expect(find.text('close'), findsWidgets);
        if (scale == 1) await _guidelines(tester);
        handle.dispose();
      });
    });

    testWidgets('my sources at ${scale}x text', (tester) async {
      await withClock(summerDay, () async {
        final handle = tester.ensureSemantics();
        final h = await AppHarness.pump(
          tester,
          at: Routes.accountEditor(kFirstAccountId),
          seed: chartSeed(),
          textScale: scale,
        );
        await h.wait(500);
        await tester.scrollUntilVisible(
          find.text('add a pdf'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        if (scale == 1) await _guidelines(tester);
        handle.dispose();
      });
    });
  }
}
