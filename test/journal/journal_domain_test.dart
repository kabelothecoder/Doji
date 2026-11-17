// The journal's arithmetic: P&L and R from the instrument model, grades, stats,
// the day's tilt, filters, storage, and what Home reads from it.
import 'dart:convert';

import 'package:doji_app/features/home/domain/home_models.dart';
import 'package:doji_app/features/journal/data/journal_repository.dart';
import 'package:doji_app/features/journal/domain/formatting.dart';
import 'package:doji_app/features/journal/domain/journal_stats.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:doji_app/features/journal/domain/trade_filter.dart';
import 'package:doji_app/features/journal/domain/trade_math.dart';
import 'package:doji_app/features/markets/data/placeholder_rate_source.dart';
import 'package:doji_app/features/markets/domain/instrument_catalog.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journal_fixtures.dart';
import '../helpers/sample_profile.dart';

void main() {
  const rates = PlaceholderRateSource();

  group('TradeMath', () {
    final gold = instrumentBySymbol('XAUUSD');

    test('gold long: 10 points on 0.1 lot is 100 in USD, and the stop sets the risk', () {
      final pnl = TradeMath.pnl(
        instrument: gold,
        direction: TradeDirection.long,
        entry: 2000,
        exit: 2010,
        size: 0.1,
        accountCurrency: 'USD',
        rates: rates,
      );
      final risk = TradeMath.riskMoney(
        instrument: gold,
        entry: 2000,
        stop: 1995,
        size: 0.1,
        accountCurrency: 'USD',
        rates: rates,
      );
      expect(pnl, closeTo(100, 1e-6));
      expect(risk, closeTo(50, 1e-6));
    });

    test('a short gains when price falls', () {
      final pnl = TradeMath.pnl(
        instrument: gold,
        direction: TradeDirection.short,
        entry: 2000,
        exit: 1990,
        size: 0.1,
        accountCurrency: 'USD',
        rates: rates,
      );
      expect(pnl, closeTo(100, 1e-6));
    });

    test('the account currency converts the quote currency', () {
      final usd = TradeMath.pnl(
        instrument: gold,
        direction: TradeDirection.long,
        entry: 2000,
        exit: 2010,
        size: 0.1,
        accountCurrency: 'USD',
        rates: rates,
      )!;
      final zar = TradeMath.pnl(
        instrument: gold,
        direction: TradeDirection.long,
        entry: 2000,
        exit: 2010,
        size: 0.1,
        accountCurrency: 'ZAR',
        rates: rates,
      )!;
      expect(zar / usd, closeTo(18.5, 1e-9));
      expect(TradeMath.usesRate(gold, 'ZAR'), isTrue);
      expect(TradeMath.usesRate(gold, 'USD'), isFalse);
    });

    test('instruments without sizing data return null instead of a guess', () {
      final synthetic = instrumentBySymbol('R_75');
      expect(synthetic, isNotNull);
      expect(
        TradeMath.pnl(
          instrument: synthetic,
          direction: TradeDirection.long,
          entry: 100,
          exit: 110,
          size: 1,
          accountCurrency: 'USD',
          rates: rates,
        ),
        isNull,
      );
      expect(
        TradeMath.pnl(
          instrument: null,
          direction: TradeDirection.long,
          entry: 1,
          exit: 2,
          size: 1,
          accountCurrency: 'USD',
          rates: rates,
        ),
        isNull,
      );
      expect(
        TradeMath.riskMoney(
          instrument: gold,
          entry: 2000,
          stop: null,
          size: 0.1,
          accountCurrency: 'USD',
          rates: rates,
        ),
        isNull,
      );
    });

    test('price places follow the tick size', () {
      expect(TradeMath.decimals(instrumentBySymbol('EURUSD')), 5);
      expect(TradeMath.decimals(gold), 2);
      expect(TradeMath.decimals(instrumentBySymbol('USDJPY')), 3);
      expect(TradeMath.decimals(null), 5);
    });
  });

  group('ProcessGrade', () {
    test('grades the process, never the result', () {
      ProcessGrade g(PlanFollowed p, List<String> m, [String? setup = 'london breakout']) =>
          ProcessGrade.of(plan: p, mistakes: m, setup: setup);
      expect(g(PlanFollowed.yes, []), ProcessGrade.a);
      expect(g(PlanFollowed.yes, ['early exit']), ProcessGrade.b);
      expect(g(PlanFollowed.partly, ['early exit']), ProcessGrade.c);
      expect(g(PlanFollowed.partly, ['a', 'b', 'c']), ProcessGrade.d);
      expect(g(PlanFollowed.no, ['revenge']), ProcessGrade.d);
      expect(g(PlanFollowed.no, ['revenge', 'FOMO']), ProcessGrade.f);
      expect(g(PlanFollowed.yes, [], kNoSetup), ProcessGrade.f, reason: 'no setup is an F even on a win');
      expect(ProcessGrade.a.keptPlan && ProcessGrade.b.keptPlan, isTrue);
      expect(ProcessGrade.c.keptPlan || ProcessGrade.c.brokePlan, isFalse);
      expect(ProcessGrade.d.brokePlan && ProcessGrade.f.brokePlan, isTrue);
    });

    test('a trade has no grade until it is reviewed', () {
      expect(sampleTrade(id: 'a', pnl: 50).grade, isNull);
      expect(sampleTrade(id: 'b', pnl: -50, plan: PlanFollowed.yes, setup: 'x').grade, ProcessGrade.a);
    });

    test('the review notes read the tags and stay about the trade', () {
      final clean = TradeReviewNotes.of(setup: 'london breakout', mistakes: const [], won: false);
      expect(clean.broke, startsWith('nothing'));
      expect(clean.lesson, contains('planned loss is a good trade'));
      final bad = TradeReviewNotes.of(setup: 'x', mistakes: const ['moved stop', 'early exit'], won: false);
      expect(bad.broke, contains('stop moved after entry'));
      expect(bad.broke, contains('then closed before target'));
    });
  });

  group('Trade', () {
    test('survives a round trip through json, including the review', () {
      final t = sampleTrade(
        id: 'x',
        pnl: -50,
        plan: PlanFollowed.partly,
        setup: 'london breakout',
        mistakes: const ['moved stop'],
        before: const TradeEmotion('anxious', 7),
        after: const TradeEmotion('angry', 8),
        note: 'moved it.',
      );
      final back = Trade.fromJson(t.toJson())!;
      expect(back.id, 'x');
      expect(back.r, closeTo(-1, 1e-9));
      expect(back.grade, ProcessGrade.c);
      expect(back.before, const TradeEmotion('anxious', 7));
      expect(back.after?.label, 'angry 8');
      expect(back.closedAt, t.closedAt);
    });

    test('R is unknown without a stop', () {
      final t = Trade(
        id: 'n',
        symbol: 'R_75',
        direction: TradeDirection.long,
        openedAt: DateTime.utc(2026, 1, 1),
        closedAt: DateTime.utc(2026, 1, 1, 1),
        entry: 1,
        exit: 2,
        size: 1,
        pnl: 12,
      );
      expect(t.r, isNull);
    });

    test('a record missing its essentials is skipped, not a crash', () {
      expect(Trade.fromJson({'id': 'x'}), isNull);
      expect(Trade.fromJson('nope'), isNull);
    });
  });

  group('JournalStats', () {
    final trades = [
      sampleTrade(id: '1', pnl: 100, minutesAgo: 400, plan: PlanFollowed.yes, setup: 's'), // +2R, kept
      sampleTrade(id: '2', pnl: -50, minutesAgo: 300, plan: PlanFollowed.yes, setup: 's'), // -1R, kept
      sampleTrade(
        id: '3',
        pnl: -100,
        minutesAgo: 200,
        plan: PlanFollowed.no,
        setup: 's',
        mistakes: ['revenge'],
      ),
      sampleTrade(id: '4', pnl: 25, minutesAgo: 100, plan: PlanFollowed.yes, setup: 's'), // +0.5R, kept
    ];

    test('R figures', () {
      final s = JournalStats.of(trades, ResultUnit.r);
      expect(s.count, 4);
      expect(s.net, closeTo(-0.5, 1e-9)); // 2 - 1 - 2 + 0.5
      expect(s.winRate, 0.5);
      expect(s.expectancy, closeTo(-0.125, 1e-9));
      expect(s.profitFactor, closeTo(2.5 / 3, 1e-9));
      expect(s.avgWin, closeTo(1.25, 1e-9));
      expect(s.avgLoss, closeTo(1.5, 1e-9));
      expect(s.maxDrawdown, closeTo(3, 1e-9), reason: 'from +2R down to -1R');
      expect(s.adherence, 0.75);
    });

    test('money figures use the same trades', () {
      final s = JournalStats.of(trades, ResultUnit.money);
      expect(s.net, closeTo(-25, 1e-9));
      expect(s.actual, [0, 100, 50, -50, -25]);
    });

    test('the dashed line leaves out the trade that broke the plan', () {
      final s = JournalStats.of(trades, ResultUnit.money);
      expect(s.ghost, [0, 100, 50, 50, 75]);
      expect(s.brokenCount, 1);
      expect(s.costOfBreaking, closeTo(100, 1e-9), reason: 'breaking the plan cost 100');
    });

    test('a plan-breaking win shows as luck, not as a cost', () {
      final s = JournalStats.of([
        sampleTrade(id: 'w', pnl: 80, plan: PlanFollowed.no, setup: kNoSetup, mistakes: ['FOMO']),
      ], ResultUnit.money);
      expect(s.costOfBreaking, closeTo(-80, 1e-9));
    });

    test('in R, trades without a stop are left out and the count says so', () {
      final noStop = Trade(
        id: 'ns',
        symbol: 'R_75',
        direction: TradeDirection.long,
        openedAt: DateTime.utc(2026, 1, 1),
        closedAt: DateTime.utc(2026, 1, 2),
        entry: 1,
        exit: 2,
        size: 1,
        pnl: 12,
      );
      expect(JournalStats.of([...trades, noStop], ResultUnit.r).count, 4);
      expect(JournalStats.of([...trades, noStop], ResultUnit.money).count, 5);
    });

    test('nothing to count gives empty figures, not zeros pretending to be results', () {
      final s = JournalStats.of(const [], ResultUnit.r);
      expect(s.winRate, isNull);
      expect(s.expectancy, isNull);
      expect(s.profitFactor, isNull);
      expect(s.adherence, isNull);
    });

    test('periods are calendar based', () {
      final now = DateTime(2026, 10, 8, 10); // a Thursday
      expect(JournalPeriod.week.contains(DateTime(2026, 10, 5, 0, 1), now), isTrue, reason: 'Monday');
      expect(JournalPeriod.week.contains(DateTime(2026, 10, 4, 23), now), isFalse, reason: 'last Sunday');
      expect(JournalPeriod.month.contains(DateTime(2026, 10, 1), now), isTrue);
      expect(JournalPeriod.month.contains(DateTime(2026, 9, 30), now), isFalse);
      expect(JournalPeriod.threeMonths.contains(DateTime(2026, 8, 1), now), isTrue);
      expect(JournalPeriod.threeMonths.contains(DateTime(2026, 7, 31), now), isFalse);
      expect(JournalPeriod.all.contains(DateTime(2001), now), isTrue);
    });

    test('the calendar sums each day', () {
      final days = calendarMonth(
        [
          sampleTrade(id: 'a', pnl: 50, minutesAgo: 60),
          sampleTrade(id: 'b', pnl: -150, minutesAgo: 120),
          sampleTrade(id: 'c', pnl: 50, daysAgo: 2, minutesAgo: 10),
        ],
        journalNow,
        ResultUnit.money,
      );
      expect(days[8]!.net, -100);
      expect(days[8]!.trades, 2);
      expect(days[8]!.down, isTrue);
      expect(days[6]!.up, isTrue);
      expect(days.containsKey(7), isFalse);
    });
  });

  group('DaySummary', () {
    test('counts only today and the losses in a row at the end of the day', () {
      final day = DaySummary.of([
        sampleTrade(id: 'old', pnl: -50, daysAgo: 1),
        sampleTrade(id: 'a', pnl: 50, minutesAgo: 300),
        sampleTrade(id: 'b', pnl: -50, minutesAgo: 200),
        sampleTrade(id: 'c', pnl: -50, minutesAgo: 100),
      ], journalNow);
      expect(day.count, 3);
      expect(day.lossStreak, 2);
      expect(day.pnl, -50);
    });

    test('a win after losses ends the streak', () {
      final day = DaySummary.of([
        sampleTrade(id: 'a', pnl: -50, minutesAgo: 300),
        sampleTrade(id: 'b', pnl: -50, minutesAgo: 200),
        sampleTrade(id: 'c', pnl: 50, minutesAgo: 100),
      ], journalNow);
      expect(day.lossStreak, 0);
    });

    test('daily loss: money over the account when the size is known, else R × planned risk', () {
      final day = DaySummary.of([sampleTrade(id: 'a', pnl: -100, risk: 50)], journalNow); // -2R, -100
      expect(day.lossPercent(accountSize: 10000, riskPerTradePct: 1), closeTo(1, 1e-9));
      expect(day.lossPercent(riskPerTradePct: 1), closeTo(2, 1e-9));
      final up = DaySummary.of([sampleTrade(id: 'a', pnl: 100)], journalNow);
      expect(up.lossPercent(accountSize: 10000, riskPerTradePct: 1), 0);
    });

    test('the account state follows closed trades and remembers its high', () {
      final s = accountStateFrom([
        sampleTrade(id: 'a', pnl: 500, minutesAgo: 300),
        sampleTrade(id: 'b', pnl: -200, minutesAgo: 100),
      ], 10000);
      expect(s.balance, 10300);
      expect(s.peakBalance, 10500);
      expect(s.equity, s.balance);
    });
  });

  group('sessions and filters', () {
    test('summer: London opened an hour ago at 08:00 UTC, and it wins over the older Tokyo open', () {
      expect(sessionOf(DateTime.utc(2026, 7, 15, 8)), 'london');
    });

    test('summer: New York is the latest open at 13:00 UTC', () {
      expect(sessionOf(DateTime.utc(2026, 7, 15, 13)), 'new york');
    });

    test('daylight saving moves the open: 07:30 UTC is London in summer, still Tokyo in winter', () {
      expect(sessionOf(DateTime.utc(2026, 7, 15, 7, 30)), 'london');
      expect(sessionOf(DateTime.utc(2026, 12, 15, 7, 30)), 'tokyo');
    });

    test('outside a session window it is off hours', () {
      expect(sessionOf(DateTime.utc(2026, 7, 15, 10, 30), window: const Duration(hours: 1)), 'off hours');
    });

    final all = [
      sampleTrade(id: 'a', pnl: 50, symbol: 'XAUUSD', plan: PlanFollowed.yes, setup: 'one'),
      sampleTrade(
        id: 'b',
        pnl: -50,
        symbol: 'EURUSD',
        plan: PlanFollowed.no,
        setup: 'two',
        mistakes: ['revenge'],
      ),
      sampleTrade(id: 'c', pnl: -50, symbol: 'EURUSD'),
    ];

    test('groups AND together, values inside a group OR together', () {
      const none = TradeFilter();
      expect(none.apply(all).length, 3);
      final pair = none.toggled(FilterGroup.pair, 'EURUSD');
      expect(pair.apply(all).map((t) => t.id), ['b', 'c']);
      final both = pair.toggled(FilterGroup.pair, 'XAUUSD');
      expect(both.apply(all).length, 3);
      final tagged = pair.toggled(FilterGroup.tag, 'revenge');
      expect(tagged.apply(all).map((t) => t.id), ['b']);
      expect(tagged.activeGroups, 2);
      expect(tagged.toggled(FilterGroup.tag, 'revenge').activeGroups, 1, reason: 'toggled off again');
    });

    test('unreviewed trades have no grade, setup or tags to match', () {
      final grade = const TradeFilter().toggled(FilterGroup.grade, 'A');
      expect(grade.apply(all).map((t) => t.id), ['a']);
      final result = const TradeFilter().toggled(FilterGroup.result, 'loss');
      expect(result.apply(all).map((t) => t.id), ['b', 'c']);
    });

    test('chip labels read like the design', () {
      expect(const TradeFilter().chipLabel(FilterGroup.tag), 'mistake tag');
      expect(
        const TradeFilter().toggled(FilterGroup.pair, 'XAUUSD').chipLabel(FilterGroup.pair),
        'pair: XAUUSD',
      );
      expect(
        const TradeFilter()
            .toggled(FilterGroup.grade, 'A')
            .toggled(FilterGroup.grade, 'B')
            .chipLabel(FilterGroup.grade),
        'grade: 2',
      );
    });
  });

  group('formatting', () {
    test('signs use a real minus and units follow the toggle', () {
      expect(formatR(1.84), '+1.8R');
      expect(formatR(-0.9), '−0.9R');
      expect(formatR(0.01), '0.0R');
      expect(formatMoney(1234.5, r'$'), r'+$1,234.50');
      expect(formatMoney(-45.5, '£'), '−£45.50');
      expect(formatMoney(0, r'$'), r'$0.00');
      expect(formatValue(2, ResultUnit.r, r'$'), '+2.0R');
      expect(durationLabel(const Duration(minutes: 125)), '2h 05m');
      expect(durationLabel(const Duration(minutes: 42)), '42 min');
    });

    test('a trade with no R shows money even when R is picked', () {
      final t = Trade(
        id: 'n',
        symbol: 'R_75',
        direction: TradeDirection.long,
        openedAt: DateTime.utc(2026, 1, 1),
        closedAt: DateTime.utc(2026, 1, 1, 1),
        entry: 1,
        exit: 2,
        size: 1,
        pnl: 12,
      );
      expect(tradeResult(t, ResultUnit.r, r'$'), r'+$12.00');
    });
  });

  group('storage', () {
    test('saves and loads on this device, newest data intact', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PrefsJournalRepository(await SharedPreferences.getInstance());
      expect(repo.load(), isEmpty);
      await repo.save([sampleTrade(id: 'a', pnl: 50), sampleTrade(id: 'b', pnl: -50)]);
      expect(repo.load().map((t) => t.id), ['a', 'b']);
      await repo.clear();
      expect(repo.load(), isEmpty);
    });

    test('corrupt storage opens an empty journal instead of crashing', () async {
      SharedPreferences.setMockInitialValues({PrefsJournalRepository.key: '{not json'});
      final repo = PrefsJournalRepository(await SharedPreferences.getInstance());
      expect(repo.load(), isEmpty);
    });

    test('one bad record is skipped, the rest stay', () async {
      SharedPreferences.setMockInitialValues({
        PrefsJournalRepository.key:
            '{"version":1,"trades":[{"id":"broken"},${jsonEncode(sampleTrade(id: 'ok', pnl: 10).toJson())}]}',
      });
      final repo = PrefsJournalRepository(await SharedPreferences.getInstance());
      expect(repo.load().map((t) => t.id), ['ok']);
    });
  });

  group('Home reads the journal', () {
    final profile = profileWith(
      name: 'sam',
      instruments: ['XAUUSD'],
      rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
    );

    test('no trades: nothing taken, nothing lost, no tilt', () {
      final snap = HomeSnapshot.fromJournal(profile, trades: const [], now: journalNow);
      expect(snap.losses, 0);
      expect(snap.tilt, isFalse);
      expect(snap.usage.firstWhere((u) => u.label == 'trades').used, 0);
      expect(snap.usage.firstWhere((u) => u.label == 'daily loss').used, 0);
    });

    test('two losses in a row today is tilt, and the trade count and daily loss follow', () {
      final snap = HomeSnapshot.fromJournal(
        profile,
        trades: [
          sampleTrade(id: 'a', pnl: -50, minutesAgo: 200),
          sampleTrade(id: 'b', pnl: -50, minutesAgo: 100),
        ],
        now: journalNow,
      );
      expect(snap.losses, 2);
      expect(snap.tilt, isTrue);
      expect(snap.usage.firstWhere((u) => u.label == 'trades').used, 2);
      expect(
        snap.usage.firstWhere((u) => u.label == 'daily loss').used,
        closeTo(2, 1e-9),
        reason: '-2R × 1%',
      );
    });

    test('a prop challenge gets a real drawdown from the trades, in the type the user chose', () {
      final prop = profileWith(
        instruments: ['XAUUSD'],
        startingSize: 10000,
        prop: const PropRules(
          maxDrawdownPct: 10,
          dailyLossLimitPct: 5,
          drawdownType: DrawdownType.trailing,
          trailingBasis: TrailingBasis.balance,
        ),
      );
      final snap = HomeSnapshot.fromJournal(
        prop,
        trades: [
          sampleTrade(id: 'a', pnl: 500, daysAgo: 1),
          sampleTrade(id: 'b', pnl: -200, minutesAgo: 100),
        ],
        now: journalNow,
      );
      final dd = snap.usage.firstWhere((u) => u.label.startsWith('prop'));
      expect(dd.label, 'prop trailing balance drawdown');
      expect(dd.used, closeTo(2, 1e-9), reason: '200 below the 10,500 high of a 10,000 account');
      expect(dd.limit, 10);
      expect(snap.usage.firstWhere((u) => u.label == 'daily loss').used, closeTo(2, 1e-9));
    });

    test('a prop firm without an account size gets no drawdown meter, not an invented one', () {
      final prop = profileWith(instruments: ['XAUUSD'], prop: const PropRules(maxDrawdownPct: 10));
      final snap = HomeSnapshot.fromJournal(prop, trades: const [], now: journalNow);
      expect(snap.usage.where((u) => u.label.startsWith('prop')), isEmpty);
    });
  });
}
