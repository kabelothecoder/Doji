import 'package:doji_app/features/history/history.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/market_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A bar every hour; records each window asked for.
class _Feed implements MarketData {
  final asked = <(DateTime, DateTime)>[];
  bool down = false;

  @override
  FeedSource sourceOf(String symbol) => const FeedSource.live('test');

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
  }) async {
    if (down) throw const FeedUnavailable('down');
    asked.add((from, to));
    final out = <Candle>[];
    for (var t = tf.bucketOf(from); !t.isAfter(to); t = t.add(tf.duration)) {
      if (t.isBefore(from)) continue;
      out.add(Candle(at: t, open: 1, high: 2, low: 0.5, close: 1.5));
    }
    return out;
  }
}

void main() {
  final d0 = DateTime.utc(2026, 7, 1), d1 = DateTime.utc(2026, 7, 3), d2 = DateTime.utc(2026, 7, 5);

  Future<(HistoryService, _Feed, PrefsHistoryRepository)> make() async {
    SharedPreferences.setMockInitialValues({});
    final repo = PrefsHistoryRepository(await SharedPreferences.getInstance());
    final feed = _Feed();
    return (HistoryService(feed, repo), feed, repo);
  }

  test('fetches the range once, caches it with the dates it covers', () async {
    final (s, feed, repo) = await make();
    final r = await s.ensure('eurusd', Timeframe.h1, from: d0, to: d1);
    expect(r.symbol, 'EURUSD');
    expect(r.from, d0);
    expect(r.to, d1);
    expect(r.candles.length, 49);
    expect(repo.load('EURUSD', Timeframe.h1)!.candles.length, 49);
    feed.asked.clear();
    await s.ensure('EURUSD', Timeframe.h1, from: d0, to: d1);
    expect(feed.asked, isEmpty, reason: 'covered: nothing fetched');
  });

  test('only the missing edge is fetched, and bars are not duplicated', () async {
    final (s, feed, _) = await make();
    await s.ensure('EURUSD', Timeframe.h1, from: d0, to: d1);
    feed.asked.clear();
    final r = await s.ensure('EURUSD', Timeframe.h1, from: d0, to: d2);
    expect(feed.asked.first.$1, d1);
    expect(r.to, d2);
    final times = r.candles.map((c) => c.at).toList();
    expect(times.toSet().length, times.length);
    expect(times, orderedEquals([...times]..sort()));
    expect(r.candles.length, 97);
  });

  test('a feed that does not answer keeps what was cached', () async {
    final (s, feed, repo) = await make();
    await s.ensure('EURUSD', Timeframe.h1, from: d0, to: d1);
    feed.down = true;
    expect(() => s.ensure('EURUSD', Timeframe.h1, from: d0, to: d2), throwsA(isA<FeedUnavailable>()));
    expect(repo.load('EURUSD', Timeframe.h1)!.to, d1);
  });

  test('a stored bar that fails to parse is skipped', () {
    final r = HistoryRange.fromJson('X', Timeframe.h1, {
      'from': d0.toIso8601String(),
      'to': d1.toIso8601String(),
      'bars': [
        [d0.millisecondsSinceEpoch, 1, 2, 0.5, 1.5],
        ['bad'],
      ],
    });
    expect(r!.candles, hasLength(1));
  });

  test('clear removes every cached range', () async {
    final (s, _, repo) = await make();
    await s.ensure('EURUSD', Timeframe.h1, from: d0, to: d1);
    await repo.clear();
    expect(repo.load('EURUSD', Timeframe.h1), isNull);
  });
}
