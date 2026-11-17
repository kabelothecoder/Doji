import 'dart:io';

import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/accounts/domain/payout_readiness.dart';
import 'package:doji_app/features/analyst/data/fake_analyst.dart';
import 'package:doji_app/features/analyst/domain/aggregates.dart';
import 'package:doji_app/features/analyst/domain/analyst.dart';
import 'package:doji_app/features/chart/domain/copilot.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/features/onboarding/domain/sessions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'analyst_fixtures.dart';

final _trades = [
  at('t1', utc(3), -50, plan: PlanFollowed.yes),
  at('t2', utc(3, 45), 50, plan: PlanFollowed.no, mistakes: ['revenge']),
  at('t3', utc(10), 100, plan: PlanFollowed.yes, mistakes: ['early exit']),
  at('t4', utc(11), -50, plan: PlanFollowed.partly, mistakes: ['revenge', 'oversized', 'moved stop']),
  at('t5', utc(11, 45), -25, plan: PlanFollowed.no, mistakes: ['revenge', 'FOMO']),
];

AnalystFacts _facts({int? max = 3, List<RuleDistance> payout = const []}) => AnalystFacts.from(
  trades: _trades,
  sessions: const [TradingSession.tokyo, TradingSession.london],
  maxTrades: max,
  payout: payout,
  now: utc(12),
);

bool _clean(String s) => !breaksCopyRules(s) && !ratesOdds(s);

const _questions = [
  'when do i break my max trades?',
  'what happens after a loss?',
  'which session do i break rules in?',
  'what time of day is worst?',
  'which instrument?',
  'are my grades improving?',
  'how close am i to my payout?',
  'how does my backtest compare to live?',
  'how is my practice going in the gym?',
  'do my chart notes match my rules?',
  'what are my most common mistakes?',
  'hello',
  'will eurusd go up today?',
  'where is price going next?',
];

void main() {
  group('weekly review', () {
    test('kept, broke and the focus rule come from the counts', () {
      final r = FakeAnalyst.reviewFor(accountId: 'acc', weekStart: DateTime(2026, 7, 13), week: _facts());
      expect(r.kept, '2 of 5 reviewed trades kept your plan (graded A or B).');
      expect(r.kept, isNot(contains('stayed within')));
      expect(
        FakeAnalyst.reviewFor(accountId: 'acc', weekStart: DateTime(2026, 7, 13), week: _facts(max: 9)).kept,
        '2 of 5 reviewed trades kept your plan (graded A or B). you stayed within 9 trades every day.',
      );
      expect(r.broke, '"revenge" came up on 3 of 5 reviewed trades. 1 day went past 3 trades.');
      expect(r.focusRule, kFocusRules['revenge']);
      expect(r.accepted, isFalse);
    });

    test('max trades wins the focus when more days broke it than any tag', () {
      final f = AnalystFacts.from(
        trades: [
          for (var d = 0; d < 3; d++)
            for (var i = 0; i < 3; i++) at('$d$i', utc(9 + i, 0, d), 10),
        ],
        maxTrades: 2,
        now: utc(12, 0, 3),
      );
      expect(focusRuleFor(f), 'stop at your max trades a day');
    });

    test('nothing broken: no focus rule', () {
      final f = AnalystFacts.from(
        trades: [at('a', utc(9), 10, plan: PlanFollowed.yes)],
        now: utc(12),
      );
      final r = FakeAnalyst.reviewFor(accountId: 'acc', weekStart: DateTime(2026, 7, 13), week: f);
      expect(r.focusRule, isNull);
      expect(r.broke, 'no broken rules were tagged this week.');
    });

    test('json round trip, accept', () {
      final r = FakeAnalyst.reviewFor(
        accountId: 'acc',
        weekStart: DateTime(2026, 7, 13),
        week: _facts(),
      ).accept();
      final back = WeeklyReview.fromJson(r.toJson())!;
      expect(back.weekStart, DateTime(2026, 7, 13));
      expect(back.accepted, isTrue);
      expect(back.focusRule, r.focusRule);
      expect(WeeklyReview.fromJson({'bad': 1}), isNull);
    });
  });

  group('ask the analyst', () {
    test('max trades: days, the hour and weekday of the extra trade', () {
      final hour = utc(11).toLocal().hour.toString().padLeft(2, '0');
      expect(
        FakeAnalyst.replyFor(_facts(), 'when do i break my max trades?'),
        'you went past 3 trades on 1 day. the extra trade most often opened around $hour:00, '
        'and most often on a wednesday. what is usually going on at that time?',
      );
    });

    test('after a loss: counted, with the small-sample note', () {
      final line = FakeAnalyst.replyFor(_facts(), 'what happens after a loss?');
      expect(
        line,
        startsWith('2 trades opened within an hour of a loss. 100% of the reviewed ones broke your plan'),
      );
      expect(line, contains('small sample'));
    });

    test('asked where price goes: declines, says no direction', () {
      for (final q in ['will eurusd go up today?', 'where is price going next?', 'predict the next move']) {
        expect(FakeAnalyst.replyFor(_facts(), q), kAnalystNoCalls);
      }
    });

    test('crisis words get the helpline first', () {
      expect(FakeAnalyst.replyFor(_facts(), 'i want to kill myself'), contains('SADAG'));
    });

    test('a line that breaks the copy rules is replaced', () {
      final f = AnalystFacts.from(
        trades: [
          at('a', utc(9), -50, plan: PlanFollowed.no, mistakes: ['FOMO'], symbol: 'PROFIT'),
        ],
        now: utc(12),
      );
      expect(FakeAnalyst.replyFor(f, 'which instrument?'), kAnalystFallback);
    });

    test('payout: the code-written lines', () {
      const lines = [
        RuleDistance(rule: 'trading days', line: '4 of 5 trading days', standing: RuleStanding.close),
      ];
      expect(FakeAnalyst.replyFor(_facts(payout: lines), 'my payout?'), '4 of 5 trading days (close).');
    });
  });

  test('copy rules and odds words: every reply and review on varied facts', () {
    final all = [
      _facts(),
      _facts(max: null),
      AnalystFacts.from(trades: const [], now: utc(12)),
      AnalystFacts.from(trades: [at('a', utc(9), 10)], maxTrades: 1, now: utc(12)),
    ];
    for (final f in all) {
      for (final q in _questions) {
        final s = FakeAnalyst.replyFor(f, q);
        expect(_clean(s), isTrue, reason: '$q → $s');
      }
      final r = FakeAnalyst.reviewFor(accountId: 'a', weekStart: DateTime(2026, 7, 13), week: f);
      for (final s in [r.kept, r.broke, ?r.focusRule]) {
        expect(_clean(s), isTrue, reason: s);
      }
    }
    for (final s in [kAnalystFallback, kAnalystNoCalls, ...kFocusRules.values]) {
      expect(_clean(s), isTrue, reason: s);
    }
  });

  test('copy rules: every string in lib/features/analyst and the payout lines', () {
    final single = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
    final double = RegExp(r'"((?:[^"\\\n]|\\.)*)"');
    final files = [
      ...Directory('lib/features/analyst').listSync(recursive: true).whereType<File>(),
      File('lib/features/accounts/domain/payout_readiness.dart'),
      File('lib/features/accounts/presentation/widgets/payout_card.dart'),
    ].where((f) => f.path.endsWith('.dart'));
    var n = 0;
    for (final f in files) {
      for (final line in f.readAsLinesSync()) {
        final t = line.trimLeft();
        if (t.startsWith('import ') || t.startsWith('//')) continue;
        for (final m in [...single.allMatches(line), ...double.allMatches(line)]) {
          n++;
          expect(breaksCopyRules(m.group(1)!), isFalse, reason: '${f.path}: ${m.group(1)}');
        }
      }
    }
    expect(n, greaterThan(80));
  });
}
