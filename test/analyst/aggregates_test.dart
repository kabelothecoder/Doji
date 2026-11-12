import 'package:doji_app/features/analyst/domain/aggregates.dart';
import 'package:doji_app/features/backtest/data/backtest_repository.dart';
import 'package:doji_app/features/backtest/domain/backtest.dart';
import 'package:doji_app/features/backtest/domain/fills.dart';
import 'package:doji_app/features/chart/domain/chart_note.dart';
import 'package:doji_app/features/chart/domain/drawing.dart';
import 'package:doji_app/features/gym/data/gym_repository.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/onboarding/domain/sessions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'analyst_fixtures.dart';

const _strategy = 'Trade the london break of the asian range. Wait for a close back inside.';

final _trades = [
  at('t1', utc(3), -50, plan: PlanFollowed.yes), // A, tokyo
  at('t2', utc(3, 45), 50, plan: PlanFollowed.no, mistakes: ['revenge']), // D, 15 min after t1's loss
  at('t3', utc(10), 100, plan: PlanFollowed.yes, mistakes: ['early exit']), // B, london
  at('t4', utc(11), -50, plan: PlanFollowed.partly, mistakes: ['revenge', 'oversized', 'moved stop']), // D
  at('t5', utc(11, 45), -25, plan: PlanFollowed.no, mistakes: ['revenge', 'FOMO']), // F, after t4's loss
  at('t6', utc(16, 30), 50, risk: null), // not reviewed, no risk, outside sessions
  at('t7', utc(10, 0, 1), 50, plan: PlanFollowed.yes, symbol: 'GBPUSD'), // A, next day
];

ChartNote _note(String id, String? tradeId, String reason, {bool deleted = false}) => ChartNote(
  id: id,
  accountId: 'acc',
  symbol: 'EURUSD',
  timeframe: Timeframe.m15,
  createdAt: utc(9),
  updatedAt: utc(9),
  drawing: Drawing(id: id, kind: DrawingKind.level, a: ChartPoint(utc(9), 1.1)),
  reason: reason,
  tradeId: tradeId,
  deleted: deleted,
);

BacktestTrade _bt(int i, {double exit = 101}) => BacktestTrade(
  symbol: 'EURUSD',
  session: 'london',
  entryAt: utc(8, 0, -i),
  entry: 100,
  stop: 99,
  target: 102,
  exitAt: utc(9, 0, -i),
  exit: exit,
  reason: ExitReason.target,
);

BacktestSession _session(List<BacktestTrade> trades, {BacktestKind kind = BacktestKind.auto}) =>
    BacktestSession(
      id: 's',
      accountId: 'acc',
      strategyVersion: 1,
      kind: kind,
      symbols: const ['EURUSD'],
      timeframe: Timeframe.m15,
      from: utc(0, 0, -30),
      to: utc(0, 0, 30),
      createdAt: utc(0),
      trades: trades,
    );

void main() {
  final now = utc(12, 0, 1);
  final f = AnalystFacts.from(
    trades: _trades,
    notes: [
      _note('n1', 't3', 'asian range break with the close back'),
      _note('n2', 't4', 'felt like it'),
      _note('n3', 't7', 'asian range break', deleted: true),
      _note('n4', null, 'asian range break'),
    ],
    sessions: const [TradingSession.tokyo, TradingSession.london],
    strategyWords: _strategy,
    maxTrades: 3,
    now: now,
  );

  test('all trades: counts, R only where risk is known, kept and broke', () {
    expect(f.trades, 7);
    expect(f.all.count, 7);
    expect(f.all.withRisk, 6);
    expect(f.all.rTotal, closeTo(-1 + 1 + 2 - 1 - 0.5 + 1, 1e-9));
    expect(f.all.reviewed, 6);
    expect(f.all.keptPlan, 3);
    expect(f.all.brokePlan, 3);
    expect(f.all.brokeShare, 50);
  });

  test('breaks by tag: most used first, share of reviewed trades', () {
    expect(f.breaksByTag.first.tag, 'revenge');
    expect(f.breaksByTag.first.count, 3);
    expect(f.breaksByTag.first.sharePct, 50);
    expect(f.breaksByTag.map((t) => t.tag).toSet(), {
      'revenge',
      'oversized',
      'moved stop',
      'early exit',
      'FOMO',
    });
    expect(f.breaksByTag.skip(1).every((t) => t.count == 1), isTrue);
  });

  test('after a loss: within 60 minutes of a losing close, same day', () {
    expect(f.afterLoss.count, 2);
    expect(f.afterLoss.brokeShare, 100);
    expect(f.afterLoss.averageR, closeTo(0.25, 1e-9));
    expect(f.afterLoss.smallSample, isTrue);
    expect(f.otherTrades.count, 5);
    expect(f.otherTrades.reviewed, 4);
    expect(f.otherTrades.brokeShare, 25);
    // 61 minutes after the close is not "after a loss".
    final late = [at('a', utc(3), -50), at('b', utc(4, 31), 50)];
    expect(isAfterLoss(late[1], late), isFalse);
    final soon = [at('a', utc(3), -50), at('b', utc(4, 30), 50)];
    expect(isAfterLoss(soon[1], soon), isTrue);
  });

  test('by session, instrument and hour', () {
    Bucket s(String k) => f.bySession.firstWhere((b) => b.key == k);
    expect(s('London').count, 4);
    expect(s('Tokyo').count, 2);
    expect(s('outside your sessions').count, 1);
    expect({for (final b in f.byInstrument) b.key: b.count}, {'EURUSD': 6, 'GBPUSD': 1});
    final hour = '${utc(11).toLocal().hour.toString().padLeft(2, '0')}:00';
    final b = f.byHour.firstWhere((x) => x.key == hour);
    expect(b.count, 2); // t4 and t5
    expect(b.brokePlan, 2);
  });

  test('max trades: days past the max and when the extra trade opened', () {
    expect(f.maxTradesBreaks, hasLength(1));
    expect(f.maxTradesBreaks.single.count, 6);
    expect(f.maxTradesBreaks.single.extraAt, utc(11).toLocal());
    expect(maxTradesBreaksOf(_trades, 6), isEmpty);
  });

  test('grade trend: 8 weeks, the fixture week counted by letter', () {
    expect(f.gradeTrend, hasLength(kGradeWeeks));
    final week = f.gradeTrend.last.counts;
    expect(week, {'A': 2, 'B': 1, 'C': 0, 'D': 2, 'F': 1});
    expect(f.gradeTrend.first.counts.values.every((n) => n == 0), isTrue);
  });

  test('chart-note reasons vs outcomes: matched to the written rules', () {
    expect(f.notesMatching.count, 1);
    expect(f.notesMatching.averageR, 2);
    expect(f.notesNotMatching.count, 1);
    expect(f.notesNotMatching.averageR, -1);
  });

  test('backtest vs live: small sample gives no gap', () {
    final g = backtestGapOf([
      _session([for (var i = 0; i < 10; i++) _bt(i)]),
    ], _trades)!;
    expect(g.backtest.withRisk, 10);
    expect(g.backtest.averageR, 1);
    expect(g.live.withRisk, 5); // EURUSD with risk
    expect(g.smallSample, isTrue);
    expect(g.gapR, isNull);
    expect(backtestGapOf([_session(const [], kind: BacktestKind.replay)], _trades), isNull);
  });

  test('backtest vs live: the gap from 10 each', () {
    final live = [for (var i = 0; i < 10; i++) at('l$i', utc(10, 0, -i), i.isEven ? 50 : -50)];
    final g = backtestGapOf([
      _session([for (var i = 0; i < 10; i++) _bt(i, exit: 99)]),
    ], live)!;
    expect(g.backtest.averageR, -1);
    expect(g.live.averageR, 0);
    expect(g.gapR, 1);
  });

  test('gym: last 28 days only', () {
    GymEntry e(
      String id,
      int daysAgo, {
      bool? correct,
      String? grade,
      GymEntryKind kind = GymEntryKind.drill,
    }) => GymEntry(
      id: id,
      at: now.subtract(Duration(days: daysAgo)),
      accountId: 'acc',
      kind: kind,
      correct: correct,
      grade: grade,
    );
    final g = gymFactsOf(
      [
        e('a', 1, correct: true),
        e('b', 2, correct: true),
        e('c', 3, correct: false),
        e('old', 40, correct: true),
        e('p', 5, grade: 'B', kind: GymEntryKind.practice),
      ],
      now,
      4,
    );
    expect(g.drills, 3);
    expect(g.correct, 2);
    expect(g.correctPct, closeTo(66.67, 0.01));
    expect(g.replayGrades, ['B']);
    expect(g.streak, 4);
  });
}
