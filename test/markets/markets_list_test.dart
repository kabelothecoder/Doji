// The markets tab (design/handoff/Doji Core Tabs.dc.html › 01, drawn in Doji
// Markets Phone) in the real app: the watchlist and its strategy states,
// search with the synthetics tab, the wide layout's second pane, and 1b's
// states (loading, market closed, feed error, no strategy yet). Sample
// prices on a pinned summer day.
import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/markets/data/brief_allowance_repository.dart';
import 'package:doji_app/features/markets/data/fake_market_data.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/market_data.dart';
import 'package:doji_app/features/markets/domain/pair_brief.dart';
import 'package:doji_app/features/markets/domain/strategy_state.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/sample_profile.dart';
import '../helpers/clocks.dart';

const _strategy = StrategyProfile(
  parsed: ParsedStrategy(
    setup: 'london breakout of the asian range',
    timeframe: 'M15',
    entry: 'retest of the broken level, candle closes beyond',
  ),
);

Map<String, Object> _seed({
  List<String> instruments = const ['EURUSD', 'XAUUSD'],
  StrategyProfile? strategy = _strategy,
}) => seedProfile(
  profile: profileWith(
    name: 'sam',
    instruments: instruments,
    sessions: const ['london'],
    timeZone: 'Africa/Johannesburg',
    utcOffsetMinutes: 120,
    strategy: strategy,
    rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
    pledgedAt: DateTime.utc(2026, 7, 1),
    completedAt: DateTime.utc(2026, 7, 1),
  ),
);

List<String> _watchlist(AppHarness h) => List<String>.from(
  ProfileDoji.fromJson(
    jsonDecode(h.prefs.getString(PrefsOnboardingRepository.profileKey)!) as Map<String, dynamic>,
  ).instruments,
);

/// A Saturday: the FX week is closed.
final Clock _saturday = Clock.fixed(DateTime.utc(2026, 7, 18, 12));

/// Sample prices that can fail (feed error) or never arrive (loading).
class _Feed implements MarketData {
  _Feed({this.fail = false, this.hang = false});

  bool fail;
  final bool hang;
  final _real = const FakeMarketData(latency: Duration.zero);

  Future<T> _or<T>(Future<T> Function() real) {
    if (hang) return Completer<T>().future;
    if (fail) return Future.error(StateError('feed down'));
    return real();
  }

  @override
  FeedSource sourceOf(String symbol) => const FeedSource.sample();

  @override
  Future<Quote?> quote(String symbol, {required DateTime now}) => _or(() => _real.quote(symbol, now: now));

  @override
  Future<List<Candle>> candles(String symbol, Timeframe tf, {required DateTime now, int count = 36}) =>
      _or(() => _real.candles(symbol, tf, now: now, count: count));

  @override
  Future<List<Candle>> candlesBetween(
    String symbol,
    Timeframe tf, {
    required DateTime from,
    required DateTime to,
  }) => _or(() => _real.candlesBetween(symbol, tf, from: from, to: to));
}

EntryCondition _c(ConditionStatus s) => EntryCondition('x', s);

void main() {
  group('strategy state (owner rule 2026-10-24)', () {
    const met = ConditionStatus.met, not = ConditionStatus.notMet, wait = ConditionStatus.waiting;

    test('met = every condition met', () {
      expect(StrategyState.of([_c(met), _c(met), _c(met)]), StrategyState.met);
    });

    test('forming = at least half met, not all', () {
      expect(StrategyState.of([_c(met), _c(not)]), StrategyState.forming);
      expect(StrategyState.of([_c(met), _c(met), _c(wait), _c(not)]), StrategyState.forming);
      expect(StrategyState.of([_c(met), _c(met), _c(met), _c(not), _c(wait)]), StrategyState.forming);
    });

    test('waiting = fewer than half met, or nothing to measure', () {
      expect(StrategyState.of([_c(met), _c(not), _c(wait)]), StrategyState.waiting);
      expect(StrategyState.of([_c(wait)]), StrategyState.waiting);
      expect(StrategyState.of(const []), StrategyState.waiting);
    });

    test('the words', () {
      expect(StrategyState.values.map((s) => s.label), ['conditions met', 'forming', 'waiting']);
    });
  });

  testWidgets('the watchlist: what it is measured against, each row labelled, sample prices', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(summerDay, () async {
      await AppHarness.pump(tester, at: Routes.markets, seed: _seed());
      expect(find.bySemanticsLabel('measured against london breakout of the asian range'), findsOneWidget);
      final row = RegExp(
        r'^EUR/USD, (london|new york) session, sample price [\d.]+, strategy (conditions met|forming|waiting)$',
      );
      expect(find.bySemanticsLabel(row), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^XAU/USD, ')), findsOneWidget);
      expect(find.textContaining('sample prices · not a live feed'), findsOneWidget);
      // Not built (owner decision): ask doji and the strategy manager.
      expect(find.text('ask doji'), findsNothing);
      expect(find.textContaining('v3'), findsNothing);
    });
    handle.dispose();
  }, variant: ios);

  testWidgets('a row opens 1b full screen on a phone', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.markets, seed: _seed());
      await h.tap(find.bySemanticsLabel(RegExp(r'^EUR/USD, ')));
      expect(h.location, Routes.pairDetail('EURUSD'));
      expect(find.bySemanticsLabel('doji brief'), findsOneWidget);
    });
    handle.dispose();
  }, variant: ios);

  testWidgets('no strategy yet: the list says your rules', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(summerDay, () async {
      await AppHarness.pump(tester, at: Routes.markets, seed: _seed(strategy: null));
      expect(find.text('your rules · no strategy yet'), findsOneWidget);
    });
    handle.dispose();
  }, variant: ios);

  testWidgets('an empty watchlist offers search', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.markets,
        seed: _seed(instruments: const []),
      );
      expect(find.textContaining('your watchlist is empty.'), findsOneWidget);
      await h.tap(find.bySemanticsLabel('add a market').last);
      expect(h.location, Routes.marketSearch);
    });
    handle.dispose();
  }, variant: ios);

  testWidgets('search: the synthetics tab, adding saves the watchlist, the list shows it', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.markets, seed: _seed());
      await h.tap(find.bySemanticsLabel('add a market'));
      expect(h.location, Routes.marketSearch);
      for (final c in ['all', 'forex', 'metals', 'indices', 'crypto', 'synthetics']) {
        expect(find.text(c), findsOneWidget, reason: c);
      }
      await h.tapText('synthetics');
      expect(find.text('EUR/USD'), findsNothing);
      final add = find.bySemanticsLabel(RegExp(r'^add Volatility 75.* to watchlist$'));
      expect(add, findsOneWidget);
      await h.tap(add);
      expect(_watchlist(h), ['EURUSD', 'XAUUSD', 'R_75']);
      expect(find.bySemanticsLabel(RegExp(r'^remove Volatility 75.* from watchlist$')), findsOneWidget);
      await h.tap(find.bySemanticsLabel('done'));
      expect(h.location, Routes.markets);
      expect(find.bySemanticsLabel(RegExp(r'^Volatility 75.*, 24/7 session, ')), findsOneWidget);
    });
    handle.dispose();
  }, variant: ios);

  testWidgets('search by symbol or name; nothing matching says so', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.marketSearch, seed: _seed());
      await tester.enterText(find.byType(TextField), 'gbp');
      await h.wait();
      expect(find.text('GBP/USD'), findsOneWidget);
      expect(find.text('EUR/USD'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await h.wait();
      expect(find.textContaining('nothing matches "zzz".'), findsOneWidget);
    });
  }, variant: ios);

  testWidgets('search: removing the last market asks first', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.marketSearch,
        seed: _seed(instruments: const ['EURUSD']),
      );
      await h.tap(find.bySemanticsLabel('remove EUR/USD from watchlist'));
      expect(find.text('remove your last market?'), findsOneWidget);
      await h.tapText('cancel');
      expect(_watchlist(h), ['EURUSD']);
    });
    handle.dispose();
  }, variant: ios);

  group('wide', () {
    testWidgets(
      'Windows: the list and 1b side by side; nothing opens until a row is picked',
      (tester) async {
        final handle = tester.ensureSemantics();
        await withClock(summerDay, () async {
          final h = await AppHarness.pump(
            tester,
            at: Routes.markets,
            seed: _seed(),
            size: const Size(1440, 900),
          );
          expect(find.textContaining('pick a market to open its brief.'), findsOneWidget);
          // The free plan's one brief a day is not spent on the trader's behalf.
          expect(h.prefs.getString(BriefAllowanceRepository.key), isNull);
          await h.tap(find.bySemanticsLabel(RegExp(r'^EUR/USD, ')));
          expect(h.location, Routes.markets);
          expect(find.bySemanticsLabel('doji brief'), findsOneWidget);
          expect(find.bySemanticsLabel('back'), findsNothing);
          expect(h.prefs.getString(BriefAllowanceRepository.key), contains('EURUSD'));
          await h.tap(find.bySemanticsLabel(RegExp(r'^XAU/USD, ')));
          expect(find.bySemanticsLabel(RegExp(r'^XAU/USD [\d,.]+, ')), findsOneWidget);
        });
        handle.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'a narrow Windows window keeps one pane and pushes 1b',
      (tester) async {
        final handle = tester.ensureSemantics();
        await withClock(summerDay, () async {
          final h = await AppHarness.pump(
            tester,
            at: Routes.markets,
            seed: _seed(),
            size: const Size(700, 800),
          );
          expect(find.textContaining('pick a market to open its brief.'), findsNothing);
          await h.tap(find.bySemanticsLabel(RegExp(r'^EUR/USD, ')));
          expect(h.location, Routes.pairDetail('EURUSD'));
        });
        handle.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  });

  group('1b states', () {
    testWidgets('loading: a cursor on the chart and the brief', (tester) async {
      await withClock(summerDay, () async {
        await AppHarness.pump(
          tester,
          at: Routes.pairDetail('EURUSD'),
          seed: _seed(),
          market: _Feed(hang: true),
        );
        expect(find.textContaining('loading EUR/USD'), findsOneWidget);
        expect(
          find.textContaining('reading the market against london breakout of the asian range'),
          findsOneWidget,
        );
      });
    }, variant: ios);

    testWidgets('market closed: the chart is dimmed and says when it opens', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(_saturday, () async {
        await AppHarness.pump(tester, at: Routes.pairDetail('EURUSD'), seed: _seed());
        expect(find.textContaining('market closed · opens '), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp(r'^Candlestick chart for EUR/USD.*, market closed$')),
          findsOneWidget,
        );
      });
      handle.dispose();
    }, variant: ios);

    testWidgets('feed error: says so, and try again asks again', (tester) async {
      final handle = tester.ensureSemantics();
      final feed = _Feed(fail: true);
      await withClock(summerDay, () async {
        final h = await AppHarness.pump(tester, at: Routes.pairDetail('EURUSD'), seed: _seed(), market: feed);
        expect(find.textContaining('price feed not responding.'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'^EUR/USD, price feed not responding')), findsOneWidget);
        feed.fail = false;
        await h.tap(find.bySemanticsLabel('try again').first);
        expect(find.textContaining('price feed not responding.'), findsNothing);
        expect(find.bySemanticsLabel(RegExp(r'^EUR/USD [\d,.]+, ')), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);

    testWidgets('no strategy yet: the rules are measured, nothing is written', (tester) async {
      await withClock(summerDay, () async {
        await AppHarness.pump(tester, at: Routes.pairDetail('EURUSD'), seed: _seed(strategy: null));
        await tester.scrollUntilVisible(
          find.textContaining('no strategy yet.'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('no strategy yet.'), findsOneWidget);
        expect(find.text('01 · MARKET CONTEXT'), findsNothing);
        expect(find.text('02 · WHAT YOUR STRATEGY SAYS'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('03 · YOUR ENTRY CONDITIONS'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('03 · YOUR ENTRY CONDITIONS'), findsOneWidget);
      });
    }, variant: ios);
  });

  group('accessibility', () {
    testWidgets('200% text: the list and search scroll instead of overflowing', (tester) async {
      await withClock(summerDay, () async {
        final h = await AppHarness.pump(tester, at: Routes.markets, seed: _seed(), textScale: 2);
        expect(tester.takeException(), isNull);
        await h.tap(find.bySemanticsLabel('add a market'));
        await h.tapText('synthetics');
        expect(tester.takeException(), isNull);
      });
    }, variant: ios);

    testWidgets('android: 48dp targets', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(summerDay, () async {
        final h = await AppHarness.pump(
          tester,
          at: Routes.markets,
          seed: _seed(),
          size: const Size(412, 915),
        );
        expect(tester.getSize(find.bySemanticsLabel('add a market')).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(find.bySemanticsLabel(RegExp(r'^EUR/USD, '))).height, greaterThanOrEqualTo(72));
        await h.tap(find.bySemanticsLabel('add a market'));
        final toggle = find.bySemanticsLabel('remove EUR/USD from watchlist');
        expect(tester.getSize(toggle).shortestSide, greaterThanOrEqualTo(48));
      });
      handle.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('copy rules: no call, signal or promise', () {
    void check(WidgetTester tester) {
      final seen = tester.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText());
      final text = ' ${[...seen, ...StrategyState.values.map((s) => s.label)].join(' ').toLowerCase()} ';
      for (final banned in [
        ' buy ',
        ' sell ',
        'signal',
        'guarantee',
        'profit',
        'win rate',
        'go long',
        'go short',
      ]) {
        expect(text, isNot(contains(banned)), reason: banned);
      }
    }

    testWidgets('the list', (tester) async {
      await withClock(summerDay, () async {
        await AppHarness.pump(tester, at: Routes.markets, seed: _seed());
        check(tester);
      });
    }, variant: ios);

    testWidgets('search', (tester) async {
      await withClock(summerDay, () async {
        await AppHarness.pump(tester, at: Routes.marketSearch, seed: _seed());
        check(tester);
      });
    }, variant: ios);

    testWidgets('1b, market closed and no strategy', (tester) async {
      await withClock(_saturday, () async {
        await AppHarness.pump(tester, at: Routes.pairDetail('EURUSD'), seed: _seed(strategy: null));
        check(tester);
      });
    }, variant: ios);

    testWidgets('1b, feed error', (tester) async {
      await withClock(summerDay, () async {
        await AppHarness.pump(
          tester,
          at: Routes.pairDetail('EURUSD'),
          seed: _seed(),
          market: _Feed(fail: true),
        );
        check(tester);
      });
    }, variant: ios);
  });
}
