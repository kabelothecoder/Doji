// Mind toolkit: scorecard rules on fixtures, the catalogue seeding, the store, and the flow.
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/auth/presentation/auth_controller.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/features/mind/data/mind_repository.dart';
import 'package:doji_app/features/mind/domain/mind_catalog.dart';
import 'package:doji_app/features/mind/domain/scorecard.dart';
import 'package:doji_app/features/mood/domain/mood.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';

// A Wednesday, local time: the week started Monday 13 July.
final _now = DateTime(2026, 7, 15, 12);

const _account = TradingAccount(
  id: kFirstAccountId,
  name: 'main',
  startingSize: 1000,
  rules: TradingRules(riskPerTrade: 1, dailyGainCap: 0.5),
);

MoodEntry _mood(String id, int daysAgo, MoodMoment m) => MoodEntry(
  id: id,
  feeling: 'calm',
  time: _now.subtract(Duration(days: daysAgo)),
  moment: m,
);

/// The back button sits in the scrolled list: scroll to the top first.
Future<void> _back(WidgetTester tester, AppHarness h) async {
  await tester.fling(find.byType(ListView).last, const Offset(0, 2000), 3000);
  await h.wait();
  await h.tap(find.bySemanticsLabel('back').last);
}

void main() {
  test('scorecard counts discipline on this week only, each with its sample', () {
    final trades = [
      // Wednesday: +1% reaches the 0.5% cap, then another trade opens after it.
      sampleTrade(id: 'w1', pnl: 10, risk: 5, minutesAgo: 60, plan: PlanFollowed.yes, now: _now),
      sampleTrade(id: 'w2', pnl: 1, risk: 5, minutesAgo: 10, plan: PlanFollowed.yes, now: _now),
      // Tuesday: plan broken, risked 5% on a 1% plan.
      sampleTrade(id: 't', pnl: -5, risk: 50, daysAgo: 1, plan: PlanFollowed.no, now: _now),
      // Monday: unreviewed.
      sampleTrade(id: 'm', pnl: 1, risk: 5, daysAgo: 2, now: _now),
      // Last week: left out.
      sampleTrade(id: 'old', pnl: 1, risk: 50, daysAgo: 5, plan: PlanFollowed.no, now: _now),
    ];
    final moods = [
      _mood('a', 1, MoodMoment.checkIn),
      _mood('b', 1, MoodMoment.checkIn),
      _mood('c', 0, MoodMoment.open),
      _mood('d', 6, MoodMoment.checkIn),
    ];
    final card = Scorecard.of(trades: trades, account: _account, moods: moods, now: _now);
    expect(card.weekStart, DateTime(2026, 7, 13));
    expect(
      [for (final l in card.lines) l.line],
      [
        '2 of 3 reviewed trades',
        '2 of 3 graded trades',
        '3 of 4 trades · stop, risk, trading window',
        '0 of 1 days a walk-away rule was reached',
        '1 of 2 reviewed trading days',
        '1 of 3 days so far this week',
      ],
    );
  });

  test('scorecard with nothing logged and no walk-away rule says so', () {
    final card = Scorecard.of(trades: const [], account: null, moods: const [], now: _now);
    expect(card.lines[0].line, 'none yet · reviewed trades');
    expect(card.lines[3].line, 'none yet · days · no walk-away rule set');
    expect(card.lines[5].line, '0 of 3 days so far this week');
  });

  test('walk-away kept when nothing opens after the rule is reached', () {
    final day = [sampleTrade(id: 'a', pnl: 10, risk: 5, now: _now)];
    expect(walkAwayDays(day, _account.rules, accountSize: 1000), [true]);
    expect(walkAwayDays(day, const TradingRules(), accountSize: 1000), isEmpty);
  });

  test('affirmation and prompt of the day are seeded by the date', () {
    final a = affirmationOfDay(DateTime(2026, 7, 15, 6));
    expect(affirmationOfDay(DateTime(2026, 7, 15, 23)).id, a.id);
    expect(affirmationOfDay(DateTime(2026, 7, 16, 6)).id, isNot(a.id));
    expect(promptStartOfDay(DateTime(2026, 7, 15)), inInclusiveRange(0, kMindPrompts.length - 1));
    expect(
      {
        for (final x in [...kMindPrompts.map((p) => p.id), ...kAffirmations.map((a) => a.id)]) x,
      }.length,
      kMindPrompts.length + kAffirmations.length,
    );
  });

  test('mind state round-trips and skips broken records', () {
    final s = MindState(
      favourites: {'job'},
      own: const [Affirmation('own-1', 'mine', own: true)],
      read: {'boredom'},
      answers: [PromptAnswer('calm', 'after lunch', DateTime.utc(2026, 7, 15))],
    );
    final back = MindState.fromJson(jsonDecode(jsonEncode(s.toJson())));
    expect(back.favourites, {'job'});
    expect(back.own.single.own, isTrue);
    expect(back.read, {'boredom'});
    expect(back.answers.single.text, 'after lunch');
    final broken = MindState.fromJson({
      'favourites': ['job', 3],
      'answers': [
        {'promptId': 'x'},
      ],
    });
    expect(broken.favourites, {'job'});
    expect(broken.answers, isEmpty);
  });

  testWidgets('me › mind toolkit: scorecard, favourite, own affirmation, read, answer; sign out clears', (
    tester,
  ) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.me, seed: {...seedProfile(), ...seedSession()});
      await tester.scrollUntilVisible(find.text('mind toolkit'), 300);
      await h.tapText('mind toolkit');
      expect(h.location, Routes.mind);

      await h.tapText('weekly scorecard');
      expect(find.text('plan kept'), findsOneWidget);
      expect(find.text('none yet · reviewed trades'), findsOneWidget);
      await _back(tester, h);

      await h.tapText('affirmation vault');
      final today = affirmationOfDay(clock.now());
      expect(find.text(today.text), findsWidgets);
      await h.tapText('add to favourites');
      expect(find.text('in your favourites'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'my stop stays where i put it.');
      await tester.tap(find.byTooltip('add affirmation'));
      await h.wait();
      expect(find.text('my stop stays where i put it.'), findsOneWidget);
      await _back(tester, h);

      await h.tapText('reading list');
      await h.tapText('boredom is not a setup');
      expect(h.location, Routes.mindArticle('boredom'));
      await h.wait();
      await _back(tester, h);
      expect(find.textContaining('· read'), findsOneWidget);
      await _back(tester, h);

      await h.tapText('reflection prompts');
      await h.tapText('answer');
      await tester.enterText(find.byType(EditableText), 'after i closed the screen.');
      await h.tapText('save answer');
      expect(find.text('after i closed the screen.'), findsOneWidget);

      final stored = h.prefs.getString(MindRepository.key)!;
      expect(stored, contains(today.id));
      expect(stored, contains('boredom'));
      expect(stored, contains('my stop stays'));
      expect(stored, contains('after i closed'));

      await h.container.read(accountActionsProvider).signOut();
      expect(h.prefs.getString(MindRepository.key), isNull);
      expect(h.container.read(mindControllerProvider).favourites, isEmpty);
    });
  }, variant: ios);
}
