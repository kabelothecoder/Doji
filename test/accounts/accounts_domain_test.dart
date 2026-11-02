// Accounts: switching, adding and deleting on profile.doji, the first account
// onboarding makes, and the conditions doji measures (or leaves to the chart).
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/features/accounts/domain/condition_eval.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:doji_app/features/journal/domain/trade_filter.dart';
import 'package:doji_app/features/markets/domain/pair_brief.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/clocks.dart';
import '../helpers/sample_profile.dart';
import '../journal/journal_fixtures.dart';

const _synthetic = TradingAccount(
  id: 'deriv',
  name: 'deriv synthetics',
  kind: AccountKind.derivSynthetic,
  instruments: ['R_75'],
  rules: TradingRules(riskPerTrade: 0.5, maxTradesPerDay: 5, dailyLossLimit: 3),
);

Map<String, ConditionStatus> _statuses(MeasuredConditions m) => {
  for (final c in m.conditions) c.text: c.status,
};

void main() {
  group('accounts on profile.doji', () {
    final two = profileWith(
      instruments: const ['XAUUSD'],
      rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3),
    ).upsertAccount(_synthetic);

    test('the first account is active until another is picked; readers follow it', () {
      expect(two.activeAccount!.id, kFirstAccountId);
      expect(two.instruments, ['XAUUSD']);
      final switched = two.switchAccount('deriv');
      expect(switched.activeAccount!.id, 'deriv');
      expect(switched.instruments, ['R_75']);
      expect(switched.rules!.maxTradesPerDay, 5);
    });

    test('switching to an id that does not exist changes nothing', () {
      expect(two.switchAccount('nope'), two);
    });

    test('upsert replaces by id and adds new ones', () {
      final renamed = two.upsertAccount(_synthetic.copyWith(name: 'boom and crash'));
      expect(renamed.accounts, hasLength(2));
      expect(renamed.accounts.last.name, 'boom and crash');
    });

    test('deleting the active account makes the first remaining one active', () {
      final p = two.switchAccount('deriv').removeAccount('deriv');
      expect(p.accounts.map((a) => a.id), [kFirstAccountId]);
      expect(p.activeAccount!.id, kFirstAccountId);
    });

    test('the last account cannot be deleted', () {
      final one = two.removeAccount('deriv');
      expect(one.removeAccount(kFirstAccountId), one);
    });

    test('withActive edits only the active account', () {
      final p = two.withActive((a) => a.copyWith(instruments: const ['EURUSD']));
      expect(p.accounts.first.instruments, ['EURUSD']);
      expect(p.accounts.last.instruments, ['R_75']);
    });

    test('the stricter daily limit of the trader and the firm', () {
      const a = TradingAccount(
        id: 'p',
        name: 'prop',
        rules: TradingRules(dailyLossLimit: 2),
        prop: PropRules(dailyLossLimitPct: 1),
      );
      expect(a.strictestDailyLossPct, 1);
    });

    test('accounts survive a JSON round trip', () {
      final back = ProfileDoji.fromJson(_roundTrip(two.switchAccount('deriv').toJson()));
      expect(back.accounts, two.accounts);
      expect(back.activeAccount!.id, 'deriv');
    });
  });

  group('onboarding makes the first account', () {
    test('a prop goal: a prop challenge sized by the goal answer, with the london break measured', () {
      final p = profileFromAnswers(answersBefore(StepIds.compile));
      final a = p.activeAccount!;
      expect(a.id, kFirstAccountId);
      expect(a.kind, AccountKind.propChallenge);
      expect(a.startingSize, 50000);
      expect(a.instruments, ['XAUUSD', 'NAS100']);
      expect(a.rules!.maxTradesPerDay, 3);
      expect(a.strategy!.conditions, [
        const StrategyCondition(kind: ConditionKind.session, session: 'london'),
        const StrategyCondition(kind: ConditionKind.tradesVsMax),
        const StrategyCondition(kind: ConditionKind.dailyLossVsLimit),
        const StrategyCondition(kind: ConditionKind.rangeBreak, closeBack: true),
        const StrategyCondition(kind: ConditionKind.newsBuffer),
      ]);
    });

    test('only synthetics, no prop goal: a deriv synthetics account without a size', () {
      final p = profileFromAnswers({
        ...answersBefore(StepIds.compile),
        StepIds.markets: ['R_75', 'BOOM1000'],
        StepIds.goal: {'goal': 'consistent'},
      });
      expect(p.activeAccount!.kind, AccountKind.derivSynthetic);
      expect(p.startingSize, isNull);
      expect(p.prop, isNull);
    });

    test('a strategy doji cannot read becomes a manual condition, never a guess', () {
      final c = defaultConditions(
        const ParsedStrategy(setup: 'order block mitigation', timeframe: 'H1', entry: 'engulfing close'),
      );
      expect(
        c,
        contains(
          const StrategyCondition(kind: ConditionKind.manual, text: 'your entry: engulfing close (H1)'),
        ),
      );
      expect(c.any((x) => x.kind == ConditionKind.rangeBreak), isFalse);
    });
  });

  group('measuring conditions', () {
    // 12:00 UTC on a summer weekday: London (BST) is open, Tokyo is not.
    final now = summerDay.now();

    ConditionFacts facts({
      bool marketOpen = true,
      int trades = 0,
      double loss = 0,
      bool newsInWindow = false,
      bool rangeBroke = false,
    }) => ConditionFacts(
      now: now,
      marketOpen: marketOpen,
      traderSessions: const ['london'],
      tradesToday: trades,
      lossTodayPct: loss,
      maxTradesPerDay: 3,
      dailyLossLimitPct: 2,
      newsKnown: true,
      newsInWindow: newsInWindow,
      rangeBroke: rangeBroke,
    );

    test('each measurable kind, in the order the trader listed them', () {
      withClock(summerDay, () {
        final m = measureConditions(const [
          StrategyCondition(kind: ConditionKind.newsBuffer),
          StrategyCondition(kind: ConditionKind.session),
          StrategyCondition(kind: ConditionKind.tradesVsMax),
          StrategyCondition(kind: ConditionKind.dailyLossVsLimit),
        ], facts(trades: 3, loss: 0.5));
        expect(m.conditions.map((c) => c.text), [
          'No high-impact news within 30 min',
          'London session is open',
          'Trades today under your max of 3',
          "Today's loss under your 2% limit",
        ]);
        expect(m.conditions.map((c) => c.status), [
          ConditionStatus.met,
          ConditionStatus.met,
          ConditionStatus.notMet,
          ConditionStatus.met,
        ]);
      });
    });

    test('a session that is closed waits, and says when it opens', () {
      withClock(summerDay, () {
        final m = measureConditions(const [
          StrategyCondition(kind: ConditionKind.session, session: 'tokyo'),
        ], facts());
        expect(_statuses(m), {'Tokyo session is open': ConditionStatus.waiting});
        expect(m.sessionOpensAt!.isAfter(now), isTrue);
      });
    });

    test('market closed: the session reads as the market, and the range cannot break', () {
      final m = measureConditions(const [
        StrategyCondition(kind: ConditionKind.session),
        StrategyCondition(kind: ConditionKind.rangeBreak, closeBack: true),
      ], facts(marketOpen: false));
      expect(_statuses(m), {
        'The market is open': ConditionStatus.notMet,
        'Price breaks the Asian range high or low': ConditionStatus.notMet,
        'M15 candle closes back beyond the broken level': ConditionStatus.notMet,
      });
    });

    test('range broken, close back not yet: met, then waiting', () {
      final m = measureConditions(const [
        StrategyCondition(kind: ConditionKind.rangeBreak, closeBack: true),
      ], facts(rangeBroke: true));
      expect(m.conditions.map((c) => c.status), [ConditionStatus.met, ConditionStatus.waiting]);
    });

    test('news inside the buffer is not met', () {
      final m = measureConditions(const [
        StrategyCondition(kind: ConditionKind.newsBuffer),
      ], facts(newsInWindow: true));
      expect(m.conditions.single.status, ConditionStatus.notMet);
    });

    test('manual rules always wait and point to the chart; empty ones are dropped', () {
      final m = measureConditions(const [
        StrategyCondition(kind: ConditionKind.manual, text: 'price above the 50 ema on H1'),
        StrategyCondition(kind: ConditionKind.manual, text: '  '),
      ], facts());
      expect(_statuses(m), {'Price above the 50 ema on H1 · check on your chart': ConditionStatus.waiting});
    });

    test('a limit the account does not have is left out, not guessed', () {
      final m = measureConditions(
        const [
          StrategyCondition(kind: ConditionKind.tradesVsMax),
          StrategyCondition(kind: ConditionKind.newsBuffer),
        ],
        ConditionFacts(now: now, marketOpen: true, traderSessions: const [], tradesToday: 9, lossTodayPct: 0),
      );
      expect(m.conditions, isEmpty);
    });
  });

  group('trades and accounts', () {
    test('accountId is saved with the trade', () {
      final t = sampleTrade(id: 'a', pnl: 10, accountId: 'deriv');
      expect(Trade.fromJson(_roundTrip(t.toJson()))!.accountId, 'deriv');
    });

    test('older trades without an account show under all accounts only', () {
      final old = sampleTrade(id: 'old', pnl: 10, accountId: null);
      final mine = sampleTrade(id: 'mine', pnl: 10);
      const one = TradeFilter({
        FilterGroup.account: {kFirstAccountId},
      });
      expect(one.apply([old, mine]).map((t) => t.id), ['mine']);
      expect(const TradeFilter().apply([old, mine]), hasLength(2));
      expect(one.chipLabel(FilterGroup.account, name: (_) => 'prop challenge'), 'account: prop challenge');
      expect(const TradeFilter().chipLabel(FilterGroup.account), 'all accounts');
    });
  });
}

Map<String, dynamic> _roundTrip(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
