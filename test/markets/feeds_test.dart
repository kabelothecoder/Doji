import 'package:clock/clock.dart';
import 'package:doji_app/features/markets/data/fake_market_data.dart';
import 'package:doji_app/features/markets/data/live_rate_source.dart';
import 'package:doji_app/features/markets/data/mt5_api.dart';
import 'package:doji_app/features/markets/data/mt5_market_data.dart';
import 'package:doji_app/features/markets/data/routed_market_data.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/instrument_catalog.dart';
import 'package:doji_app/features/markets/domain/market_data.dart';
import 'package:doji_app/features/markets/domain/risk_sizing.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `mt5` edge function in memory. Records every call; answers like
/// supabase/functions/mt5/index.ts.
class _FakeMt5 implements Mt5Api {
  final calls = <(String, String, Map<String, Object?>)>[];
  Object? fail;
  Map<String, Map<String, num>> rates = {
    'USDZAR': {'bid': 18.0, 'ask': 18.2},
  };

  @override
  Future<Map<String, dynamic>> call(
    String action,
    String accountRef, [
    Map<String, Object?> body = const {},
  ]) async {
    calls.add((action, accountRef, body));
    if (fail != null) throw fail!;
    return switch (action) {
      'quote' => {
        'symbol': body['symbol'],
        'bid': 1.08412,
        'ask': 1.08419,
        'at': 1784200000000,
        'dayOpen': 1.08,
      },
      'bars' => {
        'bars': [
          for (var i = 0; i < 50; i++)
            {'t': 1784100000 + i * 900, 'o': 1.08, 'h': 1.09, 'l': 1.07, 'c': 1.085},
        ],
      },
      'rates' => {
        'rates': {
          for (final p in (body['pairs'] as List).cast<String>())
            if (rates.containsKey(p)) p: rates[p],
        },
      },
      _ => const {},
    };
  }
}

/// A feed that only says where it is from.
class _Tagged implements MarketData {
  const _Tagged(this.name);

  final String name;

  @override
  FeedSource sourceOf(String symbol) => FeedSource.live(name);

  @override
  Future<Quote?> quote(String symbol, {required DateTime now}) async => null;

  @override
  Future<List<Candle>> candles(String symbol, Timeframe tf, {required DateTime now, int count = 36}) async =>
      [];

  @override
  Future<List<Candle>> candlesBetween(
    String symbol,
    Timeframe tf, {
    required DateTime from,
    required DateTime to,
  }) async => [];
}

void main() {
  final now = DateTime.utc(2026, 7, 15, 10);

  group('routing per instrument', () {
    const fake = FakeMarketData(latency: Duration.zero);

    test('synthetics to deriv, forex / metals / indices / oil to the broker, the rest sample', () {
      final routed = RoutedMarketData(
        sample: fake,
        deriv: const _Tagged('deriv'),
        broker: () => const _Tagged('Broker-Server'),
      );
      for (final s in ['R_75', 'R_10', 'BOOM1000', 'CRASH500']) {
        expect(routed.sourceOf(s).label, 'live prices · deriv', reason: s);
      }
      for (final s in ['EURUSD', 'XAUUSD', 'NAS100', 'USOIL']) {
        expect(routed.sourceOf(s).label, 'live prices · Broker-Server', reason: s);
      }
      for (final s in ['BTCUSD', 'MYPAIR']) {
        expect(routed.sourceOf(s), const FeedSource.sample(), reason: s);
      }
    });

    test('without a broker link everything but synthetics stays sample, labelled so', () {
      final routed = RoutedMarketData(sample: fake, deriv: const _Tagged('deriv'), broker: () => null);
      expect(routed.sourceOf('EURUSD').label, 'sample prices · not a live feed');
      expect(routed.sourceOf('R_75').live, isTrue);
      const local = RoutedMarketData(sample: fake);
      expect(local.sourceOf('R_75').live, isFalse);
    });

    test('the broker is asked per call, so switching accounts switches feeds', () {
      MarketData? link;
      final routed = RoutedMarketData(sample: fake, broker: () => link);
      expect(routed.sourceOf('XAUUSD').live, isFalse);
      link = const _Tagged('Other-Server');
      expect(routed.sourceOf('XAUUSD').label, 'live prices · Other-Server');
    });
  });

  group('mt5 feed', () {
    test('quote and bars through the edge function, for this account only', () async {
      final api = _FakeMt5();
      final feed = Mt5MarketData(api: api, accountRef: 'acc_1', server: 'Broker-Server');
      final q = (await feed.quote('EURUSD', now: now))!;
      expect(q.price, 1.08412);
      expect(q.dayOpen, 1.08);
      expect(q.decimals, 5);
      expect(api.calls.single.$2, 'acc_1');

      final bars = await feed.candles('EURUSD', Timeframe.m15, now: now, count: 36);
      expect(bars, hasLength(36)); // the newest 36 of what the broker sent
      expect(api.calls.last.$3['tf'], 'm15');
      expect(feed.sourceOf('EURUSD').label, 'live prices · Broker-Server');
    });

    test('a refusal or an outage is a feed error (1b: "price feed not responding.")', () async {
      final api = _FakeMt5()..fail = const Mt5Failure('not linked', code: 'NOT_LINKED');
      final feed = Mt5MarketData(api: api, accountRef: 'acc_1', server: 'S');
      await expectLater(feed.quote('EURUSD', now: now), throwsA(isA<FeedUnavailable>()));
      api.fail = const FeedUnavailable('down');
      await expectLater(feed.candles('EURUSD', Timeframe.h1, now: now), throwsA(isA<FeedUnavailable>()));
    });
  });

  group('live rates', () {
    final gold = instrumentBySymbol('XAUUSD')!;

    double? size(LiveRateSource rates) => RiskSizing.contractsForRisk(
      instrument: gold,
      accountBalance: 100000,
      accountCurrency: 'ZAR',
      riskPercent: 1,
      stopDistance: 5,
      rates: rates,
    );

    test('fetched once, cached with a time, and refused once stale', () async {
      final api = _FakeMt5();
      var at = now;
      await withClock(Clock(() => at), () async {
        final rates = LiveRateSource(api: api, accountRef: () => 'acc_1');
        expect(rates.rate('USD', 'ZAR'), isNull); // nothing fetched: no size
        expect(size(rates), isNull);

        await rates.prepare('USD', 'ZAR');
        expect(rates.rate('USD', 'ZAR'), closeTo(18.1, 1e-9)); // the mid
        expect(rates.rate('ZAR', 'USD'), closeTo(1 / 18.1, 1e-9));
        expect(size(rates), isNotNull);
        expect(api.calls.where((c) => c.$1 == 'rates'), hasLength(1));

        await rates.prepare('USD', 'ZAR'); // fresh: no second call
        expect(api.calls.where((c) => c.$1 == 'rates'), hasLength(1));

        at = now.add(const Duration(minutes: 6));
        expect(rates.rate('USD', 'ZAR'), isNull);
        expect(size(rates), isNull, reason: 'RiskSizing refuses a stale rate');
        expect(rates.cached('USD', 'ZAR')!.fetchedAt, now);
      });
    });

    test('crosses through USD; same currency is 1; no link means no rate', () async {
      final api = _FakeMt5()
        ..rates = {
          'EURUSD': {'bid': 1.1, 'ask': 1.1},
          'USDZAR': {'bid': 18, 'ask': 18},
        };
      await withClock(Clock.fixed(now), () async {
        final rates = LiveRateSource(api: api, accountRef: () => 'acc_1');
        await rates.prepare('EUR', 'ZAR');
        expect(rates.rate('EUR', 'ZAR'), closeTo(19.8, 1e-9));
        expect(rates.rate('usd', 'USD'), 1);

        final unlinked = LiveRateSource(api: api, accountRef: () => null);
        await unlinked.prepare('USD', 'ZAR');
        expect(unlinked.rate('USD', 'ZAR'), isNull);
        final local = LiveRateSource(api: null, accountRef: () => 'acc_1');
        await local.prepare('USD', 'ZAR');
        expect(local.rate('USD', 'ZAR'), isNull);
      });
    });

    test('an unreachable broker leaves the pair unknown', () async {
      final api = _FakeMt5()..fail = const FeedUnavailable('down');
      final rates = LiveRateSource(api: api, accountRef: () => 'acc_1');
      await rates.prepare('USD', 'ZAR');
      expect(rates.rate('USD', 'ZAR'), isNull);
    });
  });
}
