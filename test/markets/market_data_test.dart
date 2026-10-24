// Markets 1b's data layer: the sample feed, the sample news calendar, market
// status and session hours (daylight saving pinned to fixed days), the free
// plan's brief allowance and the formatting helpers.
import 'package:doji_app/features/markets/data/fake_market_data.dart';
import 'package:doji_app/features/markets/data/sample_news_calendar.dart';
import 'package:doji_app/features/markets/domain/brief_allowance.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/instrument_catalog.dart';
import 'package:doji_app/features/markets/domain/market_format.dart';
import 'package:doji_app/features/markets/domain/market_status.dart';
import 'package:doji_app/features/markets/domain/news.dart';
import 'package:doji_app/features/markets/domain/time_zones.dart';
import 'package:doji_app/features/onboarding/domain/sessions.dart';
import 'package:doji_app/features/plans/domain/plans.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wednesday 15 July 2026, 12:00 UTC (London BST, New York EDT).
final wed = DateTime.utc(2026, 7, 15, 12);
final sat = DateTime.utc(2026, 7, 18, 12);

void main() {
  const feed = FakeMarketData(latency: Duration.zero);

  group('FakeMarketData (sample prices)', () {
    test('the same candles every time, the last one forming at now', () async {
      final a = await feed.candles('EURUSD', Timeframe.m15, now: wed.add(const Duration(minutes: 7)));
      final b = await feed.candles('EURUSD', Timeframe.m15, now: wed.add(const Duration(minutes: 7)));
      expect(a, hasLength(36));
      expect([for (final c in a) c.close], [for (final c in b) c.close]);
      expect(a.last.at, wed);
      for (final c in a) {
        expect(c.high, greaterThanOrEqualTo(c.open > c.close ? c.open : c.close));
        expect(c.low, lessThanOrEqualTo(c.open < c.close ? c.open : c.close));
      }
    });

    test('timeframes agree: an H1 bar opens and closes where its M15 bars do', () async {
      final h1 = await feed.candlesBetween(
        'XAUUSD',
        Timeframe.h1,
        from: DateTime.utc(2026, 7, 15, 9),
        to: wed,
      );
      final m15 = await feed.candlesBetween(
        'XAUUSD',
        Timeframe.m15,
        from: DateTime.utc(2026, 7, 15, 9),
        to: wed,
      );
      expect(h1.first.open, m15.first.open);
      expect(h1.first.close, closeTo(m15[3].close, 1e-9));
    });

    test('no forex bars on a Saturday; synthetics run every day', () async {
      final day = DateTime.utc(2026, 7, 18);
      expect(await feed.candlesBetween('EURUSD', Timeframe.h1, from: day, to: sat), isEmpty);
      expect(await feed.candlesBetween('R_75', Timeframe.h1, from: day, to: sat), hasLength(12));
    });

    test('quote: closed on Saturday at the Friday close; null for custom symbols', () async {
      final q = (await feed.quote('EURUSD', now: sat))!;
      expect(q.marketOpen, isFalse);
      // The FX week closes Friday 17:00 New York = 21:00 UTC.
      expect(q.at, DateTime.utc(2026, 7, 17, 21));
      expect(q.decimals, 5);
      expect(await feed.quote('MYPAIR', now: wed), isNull);
      expect(await feed.candles('MYPAIR', Timeframe.m15, now: wed), isEmpty);
      expect(feed.isSample, isTrue);
    });
  });

  group('sessions and market status', () {
    test('session hours follow their city', () {
      expect(TradingSession.london.closeInstant(wed), DateTime.utc(2026, 7, 15, 16));
      expect(TradingSession.london.isOpenAt(wed), isTrue);
      expect(TradingSession.tokyo.isOpenAt(wed), isFalse);
      expect(TradingSession.london.isOpenAt(sat), isFalse);
      expect(TradingSession.london.nextOpenAfter(sat), DateTime.utc(2026, 7, 20, 7));
      expect(TradingSession.aroundJob.isOpenAt(wed), isFalse);
    });

    test('status: in the session that opened last, closed with the next open, or always open', () {
      final eur = instrumentBySymbol('EURUSD');
      final at = MarketStatus.of(eur, wed);
      expect(at, isA<InSession>());
      expect((at as InSession).session, TradingSession.newYork);
      expect(at.closesAt, DateTime.utc(2026, 7, 15, 21));

      final closed = MarketStatus.of(eur, sat);
      expect(closed, isA<MarketClosed>());
      expect((closed as MarketClosed).opensAt, DateTime.utc(2026, 7, 19, 21));

      expect(MarketStatus.of(instrumentBySymbol('BTCUSD'), sat), isA<AlwaysOpen>());
      expect(MarketStatus.of(null, sat).isOpen, isTrue, reason: 'custom symbols are never called closed');
    });
  });

  group('sample news calendar', () {
    test("a pair's currencies, in their own zones", () async {
      final usd = await const SampleNewsCalendar().highImpact(
        currencies: {'USD'},
        from: wed,
        to: wed.add(const Duration(hours: 24)),
      );
      // 08:30 and 14:00 New York on a Wednesday.
      expect(usd.map((e) => e.at), [DateTime.utc(2026, 7, 15, 12, 30), DateTime.utc(2026, 7, 15, 18)]);
      expect(usd.first.covers(DateTime.utc(2026, 7, 15, 12, 20)), isTrue);
      expect(usd.first.covers(DateTime.utc(2026, 7, 15, 12, 45)), isFalse);
    });

    test('what moves what', () {
      expect(newsCurrencies(instrumentBySymbol('EURUSD')), {'EUR', 'USD'});
      expect(newsCurrencies(instrumentBySymbol('XAUUSD')), {'USD'});
      expect(newsCurrencies(instrumentBySymbol('GER40')), {'EUR'});
      expect(newsCurrencies(instrumentBySymbol('R_75')), isEmpty);
      expect(newsCurrencies(null), isEmpty);
    });
  });

  group('free plan: one ai brief a day', () {
    test('the first instrument opened gets it; others wait for tomorrow; paid plans are open', () {
      const fresh = BriefAllowance();
      expect(fresh.allows(PlanId.free, 'EURUSD', wed), isTrue);
      final used = fresh.use('EURUSD', wed);
      expect(used.symbol, 'EURUSD');
      expect(used.allows(PlanId.free, 'EURUSD', wed), isTrue, reason: 'reopening is free');
      expect(used.allows(PlanId.free, 'XAUUSD', wed), isFalse);
      expect(used.allows(PlanId.basic, 'XAUUSD', wed), isTrue);
      expect(identical(used.use('XAUUSD', wed), used), isTrue, reason: "today's is already used");
      final tomorrow = wed.add(const Duration(days: 1));
      expect(used.allows(PlanId.free, 'XAUUSD', tomorrow), isTrue);
      expect(BriefAllowance.fromJson(used.toJson()).symbol, 'EURUSD');
      expect(BriefAllowance.fromJson('junk').day, isNull);
    });
  });

  group('formatting', () {
    test('symbols, prices, change and distances', () {
      expect(displaySymbol('EURUSD'), 'EUR/USD');
      expect(displaySymbol('XAUUSD'), 'XAU/USD');
      expect(displaySymbol('R_75'), 'Volatility 75');
      expect(displaySymbol('NAS100'), 'NAS100');
      expect(formatPrice(20512.4, 2), '20,512.40');
      expect(formatPrice(1.0842, 5), '1.08420');
      expect(formatChange(0.1234), '+0.12%');
      expect(formatChange(-0.08), '-0.08%');
      expect(formatChange(0.001), '0.00%');
      expect(distanceLabel(instrumentBySymbol('EURUSD'), 0.0032, decimals: 5), '32-pip');
      expect(distanceLabel(instrumentBySymbol('USDJPY'), 0.45, decimals: 3), '45-pip');
      expect(distanceLabel(instrumentBySymbol('XAUUSD'), 12.4, decimals: 2), '12.40-point');
    });

    test("times on the trader's clock", () {
      final jhb = UserZone.from(id: 'Africa/Johannesburg', offsetMinutes: 120);
      expect(clockTime(jhb, wed), '14:00');
      expect(clockDayTime(jhb, DateTime.utc(2026, 7, 16, 7), now: wed), 'tomorrow 09:00');
      expect(clockDayTime(jhb, DateTime.utc(2026, 7, 19, 21), now: sat), 'tomorrow 23:00');
      expect(
        clockDayTime(jhb, DateTime.utc(2026, 7, 19, 21), now: DateTime.utc(2026, 7, 17, 12)),
        'sun 23:00',
      );
    });

    test('timeframes parse from the strategy', () {
      expect(Timeframe.parse('M15'), Timeframe.m15);
      expect(Timeframe.parse('15m chart'), Timeframe.m15);
      expect(Timeframe.parse('1H'), Timeframe.h1);
      expect(Timeframe.parse('daily'), Timeframe.d1);
      expect(Timeframe.parse('tick'), isNull);
    });
  });
}
