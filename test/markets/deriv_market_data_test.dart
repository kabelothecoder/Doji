import 'dart:async';
import 'dart:convert';

import 'package:doji_app/features/markets/data/deriv_market_data.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/market_data.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Deriv socket in memory: answers `ticks_history` like the real API
/// (developers.deriv.com › ticks_history) unless told to stay silent.
class _FakeSocket implements DerivSocket {
  _FakeSocket({this.answer = true});

  final bool answer;
  final _out = StreamController<String>();
  final sent = <Map<String, dynamic>>[];

  @override
  Stream<String> get messages => _out.stream;

  @override
  void send(String frame) {
    final req = jsonDecode(frame) as Map<String, dynamic>;
    sent.add(req);
    if (!answer || req.containsKey('ping')) return;
    final id = req['req_id'];
    if (req['ticks_history'] == 'R_10') {
      _out.add(
        jsonEncode({
          'req_id': id,
          'error': {'code': 'InvalidSymbol', 'message': 'unknown'},
        }),
      );
    } else if (req['style'] == 'ticks') {
      _out.add(
        jsonEncode({
          'req_id': id,
          'pip_size': 4,
          'history': {
            'prices': [41850.1234],
            'times': [1784200000],
          },
        }),
      );
    } else {
      final g = req['granularity'] as int;
      _out.add(
        jsonEncode({
          'req_id': id,
          'candles': [
            for (var i = 0; i < 3; i++)
              {
                'epoch': 1784196000 + i * g,
                'open': 41800 + i,
                'high': 41900 + i,
                'low': 41700 + i,
                'close': 41850 + i,
              },
          ],
        }),
      );
    }
  }

  void drop() => _out.close();

  @override
  Future<void> close() => _out.close();
}

void main() {
  final now = DateTime.utc(2026, 7, 15, 10);

  test('quote and candles come from ticks_history, labelled deriv', () async {
    final socket = _FakeSocket();
    final feed = DerivMarketData(connect: () async => socket);
    final q = (await feed.quote('R_75', now: now))!;
    expect(q.price, 41850.1234);
    expect(q.dayOpen, 41802); // the last daily candle's open
    expect(q.decimals, 4);
    expect(q.at, DateTime.fromMillisecondsSinceEpoch(1784200000 * 1000, isUtc: true));
    expect(q.marketOpen, isTrue);

    final bars = await feed.candles('R_75', Timeframe.m15, now: now, count: 3);
    expect(bars, hasLength(3));
    expect(bars.first.at, DateTime.fromMillisecondsSinceEpoch(1784196000 * 1000, isUtc: true));
    final req = socket.sent.last;
    expect(req['style'], 'candles');
    expect(req['granularity'], 900);
    expect(req['count'], 3);

    expect(feed.sourceOf('R_75').live, isTrue);
    expect(feed.sourceOf('R_75').label, 'live prices · deriv');
    expect(await feed.quote('MYPAIR', now: now), isNull);
    await feed.dispose();
  });

  test('an API error is a feed error, not a crash', () async {
    final feed = DerivMarketData(connect: () async => _FakeSocket());
    await expectLater(feed.candles('R_10', Timeframe.m5, now: now), throwsA(isA<FeedUnavailable>()));
    expect((await feed.candles('R_75', Timeframe.m5, now: now)), hasLength(3)); // the socket stays up
    await feed.dispose();
  });

  test('backoff doubles from 1s and stops at 30s', () {
    expect(DerivMarketData.backoff(1), const Duration(seconds: 1));
    expect(DerivMarketData.backoff(2), const Duration(seconds: 2));
    expect(DerivMarketData.backoff(5), const Duration(seconds: 16));
    expect(DerivMarketData.backoff(6), const Duration(seconds: 30));
    expect(DerivMarketData.backoff(40), const Duration(seconds: 30));
  });

  test('a dropped socket fails pending requests, waits, then reconnects on its own', () {
    fakeAsync((async) {
      final sockets = <_FakeSocket>[];
      var connects = 0;
      final feed = DerivMarketData(
        connect: () async {
          connects++;
          // The first socket never answers, so a request is pending when it drops.
          final s = _FakeSocket(answer: connects > 1);
          sockets.add(s);
          return s;
        },
      );

      Object? pendingError;
      feed.candles('R_75', Timeframe.m5, now: now).catchError((Object e) {
        pendingError = e;
        return const <Candle>[];
      });
      async.flushMicrotasks();
      expect(connects, 1);

      sockets.first.drop();
      async.flushMicrotasks();
      expect(pendingError, isA<FeedUnavailable>());
      expect(feed.reconnecting, isTrue);

      // Inside the backoff window: fail at once, no new connection.
      Object? earlyError;
      feed.candles('R_75', Timeframe.m5, now: now).catchError((Object e) {
        earlyError = e;
        return const <Candle>[];
      });
      async.flushMicrotasks();
      expect(earlyError, isA<FeedUnavailable>());
      expect(connects, 1);

      // After 1s doji reconnects by itself and the feed answers again.
      async.elapse(const Duration(seconds: 1));
      expect(connects, 2);
      List<Candle>? bars;
      feed.candles('R_75', Timeframe.m5, now: now).then((b) => bars = b);
      async.flushMicrotasks();
      expect(bars, hasLength(3));
      expect(feed.reconnecting, isFalse);
      feed.dispose();
      async.flushMicrotasks();
    });
  });

  test('a failed connect backs off longer each time', () {
    fakeAsync((async) {
      var connects = 0;
      final feed = DerivMarketData(
        connect: () async {
          connects++;
          throw StateError('offline');
        },
      );
      void ask() => feed.candles('R_75', Timeframe.m5, now: now).catchError((Object _) => const <Candle>[]);
      ask();
      async.flushMicrotasks();
      expect(connects, 1);
      async.elapse(const Duration(seconds: 1)); // retry 1 fails
      expect(connects, 2);
      async.elapse(const Duration(seconds: 1)); // waiting 2s now
      expect(connects, 2);
      async.elapse(const Duration(seconds: 1));
      expect(connects, 3);
      feed.dispose();
      async.flushMicrotasks();
    });
  });

  test('the public endpoint carries app_id only when one is set', () {
    expect(derivPublicUri().toString(), 'wss://api.derivws.com/trading/v1/options/ws/public');
    expect(derivPublicUri(appId: '1234').queryParameters['app_id'], '1234');
  });
}
