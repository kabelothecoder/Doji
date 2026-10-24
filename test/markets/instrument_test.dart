// The market-neutral instrument model, its hours, sizing and the prop limits.
import 'dart:convert';

import 'package:doji_app/features/markets/data/placeholder_rate_source.dart';
import 'package:doji_app/features/markets/domain/currency.dart';
import 'package:doji_app/features/markets/domain/instrument.dart';
import 'package:doji_app/features/markets/domain/instrument_catalog.dart';
import 'package:doji_app/features/markets/domain/rate_source.dart';
import 'package:doji_app/features/markets/domain/risk_sizing.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/domain/config_lines.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:doji_app/features/onboarding/domain/prop_drawdown.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/sample_profile.dart';

Instrument _i(String symbol) => instrumentBySymbol(symbol)!;

/// A rate source that knows nothing.
class _NoRates implements RateSource {
  const _NoRates();

  @override
  double? rate(String from, String to) => null;
}

void main() {
  group('catalogue', () {
    test('symbols are unique and every instrument can be spoken about', () {
      final symbols = instrumentCatalog.map((i) => i.symbol).toList();
      expect(symbols.toSet(), hasLength(symbols.length));
      for (final i in instrumentCatalog) {
        expect(i.name, isNotEmpty, reason: i.symbol);
        expect(i.name, i.name.toLowerCase(), reason: 'lowercase voice: ${i.symbol}');
      }
    });

    test('forex, CFDs, crypto and synthetics are offered; futures and stocks are hidden', () {
      final shown = visibleInstruments.map((i) => i.assetClass).toSet();
      expect(shown, {AssetClass.forex, AssetClass.cfd, AssetClass.crypto, AssetClass.synthetic});
      expect(visibleInstruments.any((i) => i.group == InstrumentGroup.futures), isFalse);
      expect(visibleInstruments.any((i) => i.group == InstrumentGroup.stocks), isFalse);
      // …but the model has them.
      expect(_i('ES').assetClass, AssetClass.futures);
      expect(_i('AAPL').assetClass, AssetClass.stock);
      expect(marketOptions.map((o) => o.value), isNot(contains('ES')));
      expect(marketOptions.map((o) => o.value), isNot(contains('AAPL')));
    });

    test('CFD indices, metals and oil, and Deriv Volatility and Boom/Crash are all there', () {
      final groups = visibleInstruments.map((i) => i.group).toSet();
      expect(
        groups,
        containsAll([
          InstrumentGroup.forex,
          InstrumentGroup.metals,
          InstrumentGroup.indices,
          InstrumentGroup.oil,
          InstrumentGroup.crypto,
          InstrumentGroup.volatility,
          InstrumentGroup.boomCrash,
        ]),
      );
      for (final s in ['R_10', 'R_25', 'R_50', 'R_75', 'R_100']) {
        expect(_i(s).group, InstrumentGroup.volatility);
      }
      for (final s in ['BOOM300N', 'BOOM500', 'BOOM1000', 'CRASH300N', 'CRASH500', 'CRASH1000']) {
        expect(_i(s).group, InstrumentGroup.boomCrash);
      }
    });

    test('options keep chips in catalogue order so number keys stay stable', () {
      expect(marketOptions.first.value, 'EURUSD');
      expect(marketOptions.firstWhere((o) => o.value == 'R_75').label, 'Volatility 75');
    });

    test('lookups: unknown symbols are custom, not errors', () {
      expect(instrumentBySymbol('xauusd'), _i('XAUUSD'));
      expect(instrumentBySymbol('MYCUSTOM'), isNull);
      expect(instrumentLabel('MYCUSTOM'), 'MYCUSTOM');
      expect(instrumentLabel('R_75'), 'Volatility 75');
    });
  });

  group('search', () {
    test('finds by symbol, name and broker alias', () {
      expect(instrumentMatches('XAUUSD', 'gold'), isTrue);
      expect(instrumentMatches('R_75', 'v75'), isTrue);
      expect(instrumentMatches('R_75', 'volatility 75'), isTrue);
      expect(instrumentMatches('CRASH1000', 'crash 1000'), isTrue);
      expect(instrumentMatches('GER40', 'dax'), isTrue);
      expect(instrumentMatches('USOIL', 'wti'), isTrue);
      expect(instrumentMatches('BTCUSD', 'bitcoin'), isTrue);
      expect(instrumentMatches('EURUSD', 'gold'), isFalse);
      expect(instrumentMatches('EURUSD', ''), isTrue);
    });

    test('exact spellings are not offered as a new custom symbol', () {
      expect(instrumentIsExact('XAUUSD', 'gold'), isTrue);
      expect(instrumentIsExact('R_75', 'V75'), isTrue);
      expect(instrumentIsExact('XAUUSD', 'xau'), isTrue);
      expect(instrumentIsExact('EURUSD', 'EURU'), isFalse);
    });
  });

  group('market hours (real zones, daylight saving)', () {
    DateTime utc(int month, int day, int hour, [int minute = 0]) =>
        DateTime.utc(2026, month, day, hour, minute);

    // The FX week is Sunday 17:00 to Friday 17:00 in New York.
    test('forex and CFDs in summer (EDT): close Friday 21:00 UTC, open Sunday 21:00 UTC', () {
      final gold = _i('XAUUSD').hours;
      expect(gold.isOpenAt(utc(10, 12, 10)), isTrue, reason: 'Monday');
      expect(gold.isOpenAt(utc(10, 9, 20, 59)), isTrue, reason: 'Friday just before close');
      expect(gold.isOpenAt(utc(10, 9, 21)), isFalse, reason: 'Friday 17:00 EDT');
      expect(gold.isOpenAt(utc(10, 10, 12)), isFalse, reason: 'Saturday');
      expect(gold.isOpenAt(utc(10, 11, 20, 59)), isFalse, reason: 'Sunday before the open');
      expect(gold.isOpenAt(utc(10, 11, 21)), isTrue, reason: 'Sunday 17:00 EDT (wraps the week)');
    });

    test('the same market in winter (EST) closes and opens an hour later in UTC', () {
      final gold = _i('XAUUSD').hours;
      expect(gold.isOpenAt(utc(12, 11, 21, 59)), isTrue, reason: 'Friday 16:59 EST');
      expect(gold.isOpenAt(utc(12, 11, 22)), isFalse, reason: 'Friday 17:00 EST');
      expect(gold.isOpenAt(utc(12, 13, 21, 59)), isFalse, reason: 'Sunday 16:59 EST');
      expect(gold.isOpenAt(utc(12, 13, 22)), isTrue, reason: 'Sunday 17:00 EST');
    });

    test('the clocks change on one weekend: before it the close is 22:00 UTC, after it 21:00 UTC', () {
      // New York moved to EDT on Sunday 2026-03-08.
      final fx = _i('EURUSD').hours;
      expect(fx.isOpenAt(utc(3, 6, 21, 30)), isTrue, reason: 'Friday 03-06 16:30 EST');
      expect(fx.isOpenAt(utc(3, 6, 22)), isFalse, reason: 'Friday 03-06 17:00 EST');
      expect(fx.isOpenAt(utc(3, 13, 20, 30)), isTrue, reason: 'Friday 03-13 16:30 EDT');
      expect(fx.isOpenAt(utc(3, 13, 21)), isFalse, reason: 'Friday 03-13 17:00 EDT');
    });

    test('crypto and synthetic indices never close', () {
      for (final s in ['BTCUSD', 'R_75', 'BOOM1000', 'CRASH500']) {
        expect(_i(s).hours.alwaysOpen, isTrue, reason: s);
        expect(_i(s).hours.isOpenAt(utc(10, 10, 3)), isTrue, reason: '$s on a Saturday night');
      }
    });

    test('stocks follow New York exchange hours, in summer and winter', () {
      final aapl = _i('AAPL').hours;
      // 09:30–16:00 New York: 13:30–20:00 UTC in summer, 14:30–21:00 UTC in winter.
      expect(aapl.isOpenAt(utc(7, 15, 13, 29)), isFalse);
      expect(aapl.isOpenAt(utc(7, 15, 13, 30)), isTrue);
      expect(aapl.isOpenAt(utc(7, 15, 20)), isFalse);
      expect(aapl.isOpenAt(utc(12, 15, 13, 30)), isFalse);
      expect(aapl.isOpenAt(utc(12, 15, 14, 30)), isTrue);
      expect(aapl.isOpenAt(utc(12, 15, 21)), isFalse);
      expect(aapl.isOpenAt(utc(7, 18, 15)), isFalse, reason: 'Saturday');
    });

    test('futures: Globex opens Sunday 17:00 and closes Friday 16:00 Chicago time', () {
      final es = _i('ES').hours;
      expect(es.isOpenAt(utc(7, 14, 3)), isTrue, reason: 'Tuesday');
      expect(es.isOpenAt(utc(7, 17, 20, 59)), isTrue, reason: 'Friday 15:59 CDT');
      expect(es.isOpenAt(utc(7, 17, 21)), isFalse, reason: 'Friday 16:00 CDT');
      expect(es.isOpenAt(utc(7, 18, 12)), isFalse, reason: 'Saturday');
    });
  });

  group('risk sizing (percent in, lots or contracts out, any account currency)', () {
    const rates = PlaceholderRateSource();

    double? size(
      String symbol, {
      double balance = 10000,
      String currency = 'USD',
      double risk = 1,
      double stop = 1,
      RateSource source = rates,
    }) => RiskSizing.contractsForRisk(
      instrument: _i(symbol),
      accountBalance: balance,
      accountCurrency: currency,
      riskPercent: risk,
      stopDistance: stop,
      rates: source,
    );

    test('forex: 1% of 10,000 with a 20-pip stop on EURUSD is 0.5 lots', () {
      expect(size('EURUSD', stop: 0.0020), closeTo(0.5, 1e-9));
    });

    test('metals: 1% of 10,000 with a 5.00 stop on gold is 0.2 lots', () {
      expect(size('XAUUSD', stop: 5), closeTo(0.2, 1e-9));
    });

    test('futures use the published tick value: 1% of 50,000 with a 10-point stop is 1 ES', () {
      expect(size('ES', balance: 50000, stop: 10), closeTo(1, 1e-9));
    });

    test('stocks: 1% of 10,000 with a 2.00 stop is 50 shares', () {
      expect(size('AAPL', stop: 2), closeTo(50, 1e-9));
    });

    test('a ZAR account is sized through the exchange rate', () {
      // 185,000 ZAR is 10,000 USD at the placeholder 18.5, so the position is the same…
      final inUsd = size('EURUSD', stop: 0.0020)!;
      expect(size('EURUSD', balance: 185000, currency: 'ZAR', stop: 0.0020)!, closeTo(inUsd, 1e-9));
      // …and 10,000 ZAR is only about 540 USD: a far smaller position.
      expect(
        size('EURUSD', balance: 10000, currency: 'ZAR', stop: 0.0020)!,
        closeTo(inUsd * 10000 / 185000, 1e-9),
      );
    });

    test('a quote currency other than USD is converted: USDJPY in a EUR account', () {
      // Per lot, a 0.20 stop is 0.20 / 0.001 ticks × (0.001 × 100,000 = 100 JPY) = 20,000 JPY.
      // At the placeholder rates 1 JPY = 0.92 / 150 EUR. Risk is 1% of 10,000 = 100 EUR.
      final lots = size('USDJPY', currency: 'EUR', stop: 0.20)!;
      expect(lots, closeTo(100 / (20000 * 0.92 / 150), 1e-9));
    });

    test('a GBP account on a USD-quoted instrument', () {
      // 200 ticks × $1 per lot = $200 = 158 GBP at 0.79; risk is 100 GBP.
      expect(size('EURUSD', currency: 'GBP', stop: 0.0020)!, closeTo(100 / (200 * 0.79), 1e-9));
    });

    test('unknown sizing data, an unknown rate or bad input: no guess', () {
      expect(_i('R_75').effectiveTickValue, isNull);
      expect(size('R_75'), isNull, reason: 'synthetics: sizing comes from the feed');
      expect(size('EURUSD', balance: 0), isNull);
      expect(size('EURUSD', risk: -1), isNull);
      expect(size('EURUSD', stop: 0), isNull);
      expect(size('EURUSD', currency: 'XYZ'), isNull, reason: 'no rate for that currency');
      expect(size('EURUSD', source: const _NoRates()), isNull);
    });

    test('placeholder rates: same currency is 1, crosses go through USD, unknown is null', () {
      expect(rates.rate('USD', 'USD'), 1);
      expect(rates.rate('zar', 'usd'), closeTo(1 / 18.5, 1e-12));
      expect(rates.rate('EUR', 'GBP'), closeTo(0.79 / 0.92, 1e-12));
      expect(rates.rate('XYZ', 'USD'), isNull);
    });

    test('the four account currencies', () {
      expect(AccountCurrency.values.map((c) => c.code), ['USD', 'ZAR', 'EUR', 'GBP']);
      expect(AccountCurrency.fromCode('zar'), AccountCurrency.zar);
      expect(AccountCurrency.fromCode('JPY'), isNull);
      expect(AccountCurrency.fromCode(null), isNull);
    });
  });

  group('drawdown: static or trailing, and what trailing follows', () {
    // A 100,000 account that went up and then gave some back.
    const state = AccountState(balance: 101000, equity: 101500, peakBalance: 103000, peakEquity: 104000);
    PropRules rules(DrawdownType type, [TrailingBasis basis = TrailingBasis.equity]) =>
        PropRules(accountSize: 100000, maxDrawdownPct: 10, drawdownType: type, trailingBasis: basis);

    DrawdownStatus status(PropRules r, [AccountState s = state]) =>
        PropDrawdown.evaluate(r, accountSize: 100000, state: s)!;

    test('static: measured from the starting balance, so a winning account has used none', () {
      final s = status(rules(DrawdownType.fixed));
      expect(s.usedPct, 0);
      expect(s.floor, 90000);
      expect(s.label, 'static drawdown');
      expect(s.basis, isNull);
    });

    test('static: equity below the start counts, open losses included', () {
      final s = status(
        rules(DrawdownType.fixed),
        const AccountState(balance: 97000, equity: 95500, peakBalance: 103000, peakEquity: 104000),
      );
      expect(s.usedPct, closeTo(4.5, 1e-9));
      expect(s.fraction, closeTo(0.45, 1e-9));
    });

    test('trailing balance follows the highest balance', () {
      final s = status(rules(DrawdownType.trailing, TrailingBasis.balance));
      expect(s.usedPct, closeTo(2, 1e-9)); // 103,000 − 101,000
      expect(s.floor, 93000); // 103,000 − 10,000
      expect(s.label, 'trailing balance drawdown');
    });

    test('trailing equity follows the highest equity', () {
      final s = status(rules(DrawdownType.trailing));
      expect(s.usedPct, closeTo(2.5, 1e-9)); // 104,000 − 101,500
      expect(s.floor, 94000);
      expect(s.label, 'trailing equity drawdown');
    });

    test('the same account reads differently under each type (so warnings must use the right one)', () {
      final used = {
        for (final r in [
          rules(DrawdownType.fixed),
          rules(DrawdownType.trailing, TrailingBasis.balance),
          rules(DrawdownType.trailing),
        ])
          r.drawdownLabel: status(r).usedPct,
      };
      expect(used, {
        'static': 0,
        'trailing balance': closeTo(2, 1e-9),
        'trailing equity': closeTo(2.5, 1e-9),
      });
    });

    test('breach: at the limit, by the type chosen', () {
      const deep = AccountState(balance: 96000, equity: 93900, peakBalance: 103000, peakEquity: 104000);
      expect(status(rules(DrawdownType.fixed), deep).breached, isFalse, reason: '6.1% below the start');
      expect(
        status(rules(DrawdownType.trailing), deep).breached,
        isTrue,
        reason: '10.1% below the equity high',
      );
      expect(
        status(rules(DrawdownType.trailing, TrailingBasis.balance), deep).breached,
        isFalse,
        reason: '7%',
      );
    });

    test('no limit or no account size: nothing to evaluate', () {
      expect(PropDrawdown.evaluate(const PropRules(), accountSize: 100000, state: state), isNull);
      expect(PropDrawdown.evaluate(rules(DrawdownType.fixed), accountSize: 0, state: state), isNull);
    });

    test('defaults: static, and equity when trailing', () {
      const r = PropRules(maxDrawdownPct: 5);
      expect(r.drawdownType, DrawdownType.fixed);
      expect(r.trailingBasis, TrailingBasis.equity);
      expect(r.drawdownLabel, 'static');
      expect(r.isEmpty, isFalse);
      expect(
        const PropRules(drawdownType: DrawdownType.trailing).isEmpty,
        isTrue,
        reason: 'a setting is not a limit',
      );
    });

    test('the choice comes from the goal answer and survives JSON', () {
      final p = profileFromAnswers({
        ...answersBefore(StepIds.compile),
        StepIds.goal: {
          'goal': 'prop_challenge',
          'propMaxDrawdown': 8,
          'propDrawdownType': 'trailing',
          'propTrailingBasis': 'balance',
        },
      });
      expect(p.prop?.drawdownType, DrawdownType.trailing);
      expect(p.prop?.trailingBasis, TrailingBasis.balance);
      final back = ProfileDoji.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.prop, p.prop);
    });

    test('profile.doji says which drawdown it is', () {
      String limits(Map<String, Object?> goal) {
        final lines = buildConfigLines({...answersBefore(StepIds.compile), StepIds.goal: goal});
        final l = lines.firstWhere((l) => l.keyName == 'prop.limits');
        return '${l.value}${l.comment}';
      }

      expect(
        limits({'goal': 'prop_challenge', 'propMaxDrawdown': 10}),
        '- / 10.0% / -  # daily loss / static drawdown / target',
      );
      expect(
        limits({'goal': 'prop_challenge', 'propMaxDrawdown': 10, 'propDrawdownType': 'trailing'}),
        '- / 10.0% / -  # daily loss / trailing equity drawdown / target',
      );
    });
  });

  group('account currency', () {
    test('comes from the risk answer, USD when unset or unknown', () {
      ProfileDoji with_(Object? currency) => profileFromAnswers({
        ...answersBefore(StepIds.compile),
        StepIds.risk: {'riskPct': 1.0, 'maxTrades': 3, 'dailyLoss': 2.0, 'currency': ?currency},
      });
      expect(with_('ZAR').accountCurrency, 'ZAR');
      expect(with_('gbp').accountCurrency, 'GBP');
      expect(with_(null).accountCurrency, 'USD');
      expect(with_('JPY').accountCurrency, 'USD');
    });
  });

  group('prop limits', () {
    final goal = {
      'goal': 'prop_challenge',
      'propFirm': 'My Firm',
      'propSize': 100000,
      'propDailyLoss': 5,
      'propMaxDrawdown': 10.0,
      'propTarget': 8,
    };

    test('the goal answer becomes PropRules on the profile', () {
      final p = profileFromAnswers({...answersBefore(StepIds.compile), StepIds.goal: goal});
      expect(
        p.prop,
        const PropRules(
          firm: 'My Firm',
          accountSize: 100000,
          dailyLossLimitPct: 5,
          maxDrawdownPct: 10,
          profitTargetPct: 8,
        ),
      );
    });

    test('limits are optional; nothing entered means no PropRules', () {
      final onlyGoal = profileFromAnswers({
        ...answersBefore(StepIds.compile),
        StepIds.goal: {'goal': 'prop_challenge'},
      });
      expect(onlyGoal.prop, isNull);
      final partial = profileFromAnswers({
        ...answersBefore(StepIds.compile),
        StepIds.goal: {'goal': 'prop_challenge', 'propMaxDrawdown': 6},
      });
      expect(partial.prop?.maxDrawdownPct, 6);
      expect(partial.prop?.dailyLossLimitPct, isNull);
    });

    test('other goals drop stale prop answers', () {
      final p = profileFromAnswers({
        ...answersBefore(StepIds.compile),
        StepIds.goal: {...goal, 'goal': 'learn'},
      });
      expect(p.prop, isNull);
    });

    test('profile.doji prints the size and the three limits', () {
      final lines = buildConfigLines({...answersBefore(StepIds.compile), StepIds.goal: goal});
      String line(String k) {
        final l = lines.firstWhere((l) => l.keyName == k);
        return '${l.value}${l.comment}';
      }

      expect(line('prop.size'), '100_000  # my firm');
      expect(line('prop.limits'), '5.0% / 10.0% / 8.0%  # daily loss / static drawdown / target');
    });

    test('an empty prop goal prints optional placeholders', () {
      final lines = buildConfigLines({
        ...answersBefore(StepIds.compile),
        StepIds.goal: {'goal': 'prop_challenge'},
      });
      final limits = lines.firstWhere((l) => l.keyName == 'prop.limits');
      expect('${limits.value}${limits.comment}', 'null  # optional');
    });
  });

  group('profile shape (reset, no migration)', () {
    test('the old keys are gone from the stored JSON', () {
      final json = profileFromAnswers(answersBefore(StepIds.compile)).toJson();
      expect(json.containsKey('instruments'), isTrue);
      expect(json.containsKey('prop'), isTrue);
      for (final old in ['pairs', 'propFirm', 'propSize']) {
        expect(json.containsKey(old), isFalse, reason: old);
      }
      expect(json['onboardingVersion'], kOnboardingVersion);
    });

    Future<PrefsOnboardingRepository> repo(Map<String, Object> seed) async {
      SharedPreferences.setMockInitialValues(seed);
      return PrefsOnboardingRepository(await SharedPreferences.getInstance());
    }

    test('a profile saved by the old shape is forgotten, not half-read', () async {
      final r = await repo({
        PrefsOnboardingRepository.profileKey: jsonEncode({
          'name': 'sam',
          'pairs': ['XAUUSD'],
          'propSize': 50000,
          'onboardingVersion': 1,
          'completedAt': '2026-10-01T00:00:00.000Z',
        }),
      });
      expect(r.loadProfile(), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(r.loadProfile(), isNull);
    });

    test('a version 2 profile (before sessions became real zones) is forgotten too', () async {
      final r = await repo({
        PrefsOnboardingRepository.profileKey: jsonEncode({
          'name': 'sam',
          'sessions': ['asia'],
          'onboardingVersion': 2,
          'completedAt': '2026-10-01T00:00:00.000Z',
        }),
      });
      expect(r.loadProfile(), isNull);
    });

    test('a half-finished onboarding from the old shape starts over', () async {
      final r = await repo({
        PrefsOnboardingRepository.snapshotKey: jsonEncode({
          'currentStepId': StepIds.sessions,
          'answers': {
            StepIds.markets: ['XAUUSD'],
          },
          'version': 1,
        }),
      });
      expect(r.loadSnapshot(), isNull);
    });

    test('current-version data is kept', () async {
      final r = await repo({
        PrefsOnboardingRepository.profileKey: jsonEncode(
          const ProfileDoji(name: 'sam', instruments: ['R_75']).toJson(),
        ),
        ...resumeAt(StepIds.sessions),
      });
      expect(r.loadProfile()?.instruments, ['R_75']);
      expect(r.loadSnapshot()?.currentStepId, StepIds.sessions);
    });
  });

  group('doji replies', () {
    test('synthetics and crypto are fast movers; forex pairs are just noted', () {
      expect(
        marketsReply(['R_75', 'BOOM1000'], const {}),
        "volatility 75 and boom 1000. both move fast — we'll keep you steady.",
      );
      expect(marketsReply(['EURUSD'], const {}), 'euro. noted.');
      expect(marketsReply(['XAUUSD', 'EURUSD'], const {}), 'gold and euro. noted.');
      expect(marketsReply(['MYCUSTOM'], const {}), 'mycustom. noted.');
    });
  });
}
