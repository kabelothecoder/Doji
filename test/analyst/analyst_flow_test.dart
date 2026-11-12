import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/core/widgets/widgets.dart';
import 'package:doji_app/features/analyst/domain/analyst.dart';
import 'package:doji_app/features/analyst/presentation/analyst_controller.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chart/chart_fixtures.dart';
import 'analyst_fixtures.dart';
import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';

void main() {
  testWidgets('under 20 trades: the analyst is locked and says why', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.journal,
        seed: chartSeed(extra: seedJournal(lastWeekTrades(7))),
      );
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.textContaining('this account has 7'), 300, scrollable: list);
      expect(find.text('ask the analyst'), findsNothing);
      expect(find.text('WEEKLY REVIEW'), findsNothing);
      expect(h.container.read(reviewsProvider), isEmpty);
    });
  });

  testWidgets('weekly review: focus on its rule, then Home shows it', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.journal,
        seed: chartSeed(extra: seedJournal(lastWeekTrades(20))),
      );
      await h.wait(800);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('focus on this rule'), 300, scrollable: list);
      expect(find.text('WEEKLY REVIEW'), findsOneWidget);
      expect(find.text(kFocusRules['revenge']!), findsOneWidget);
      await h.tapText('focus on this rule');
      expect(
        find.textContaining('focus for this week. it shows on home.', findRichText: true),
        findsOneWidget,
      );
      expect(h.container.read(reviewsProvider).single.accepted, isTrue);

      h.router.go(Routes.home);
      await h.wait(800);
      expect(
        find.textContaining('focus this week: ${kFocusRules['revenge']}', findRichText: true),
        findsOneWidget,
      );
    });
  });

  testWidgets('ask the analyst: a suggested question gets counted facts', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.journal,
        seed: chartSeed(extra: seedJournal(lastWeekTrades(20))),
      );
      await h.wait(800);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('ask the analyst'), 300, scrollable: list);
      await h.tapText('ask the analyst');
      expect(find.text('ask the analyst'), findsWidgets);
      await h.tapText('what happens after a loss?', settle: 800);
      await h.wait(800);
      expect(find.textContaining('after a loss'), findsWidgets);
      expect(find.textContaining('opened within an hour of a loss'), findsOneWidget);
    });
  });

  testWidgets('prop account: Home shows the payout rules in plain words', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.home, seed: propSeed());
      await h.wait(800);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('PAYOUT RULES'), 300, scrollable: list);
      await tester.scrollUntilVisible(find.text('0 of 5 trading days'), 200, scrollable: list);
      expect(find.text('no gains yet to measure consistency on; the firm allows 40%'), findsOneWidget);
    });
  });

  testWidgets('my sources: a note is saved at once on the account', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.accountEditor(kFirstAccountId), seed: chartSeed());
      await h.wait(500);
      final list = find.byType(Scrollable).first;
      final text = find.byWidgetPredicate((w) => w is DojiTextField && w.hint == 'your note');
      await tester.scrollUntilVisible(find.text('add note'), 300, scrollable: list);
      await tester.enterText(
        find.descendant(of: text, matching: find.byType(EditableText)).first,
        'I only trade the london break.',
      );
      await h.wait();
      await h.tapText('add note');
      expect(find.text('note · 30 characters'), findsOneWidget);
      final s = h.container.read(sourcesProvider).single;
      expect(s.accountId, kFirstAccountId);
      expect(s.title, 'note');
      expect(strategyWordsWithSources('x', [s]), 'x\nI only trade the london break.');
      expect(clock.now(), summerDay.now());
    });
  });
}
