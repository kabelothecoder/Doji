import 'dart:math';

import 'package:doji_app/features/backtest/domain/fills.dart';
import 'package:doji_app/features/chart/domain/drawing.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/market_data.dart';
import 'package:doji_app/features/replay/domain/replay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 7, 15, 7);
  Candle bar(int i, double o, double h, double l, double c) => Candle(
    at: t0.add(Duration(minutes: 15 * i)),
    open: o,
    high: h,
    low: l,
    close: c,
  );
  final history = [for (var i = 0; i < 200; i++) bar(i, 100, 101, 99, 100)];

  group('ReplayBarSource never reveals a bar past the cursor', () {
    test('for any cursor and any "now", even one in the future', () async {
      final rnd = Random(7);
      for (var k = 0; k < 300; k++) {
        final cursor = rnd.nextInt(history.length + 5);
        final src = ReplayBarSource(history, cursor: cursor, source: const FeedSource.sample());
        final limit = cursor == 0 ? null : history[min(cursor, history.length) - 1].at;
        final now = t0.add(Duration(days: rnd.nextInt(30)));
        final bars = await src.bars(Timeframe.m15, now: now, count: 1000);
        expect(src.visible.length, min(cursor, history.length));
        expect(bars.length, lessThanOrEqualTo(src.visible.length));
        if (limit != null) expect(bars.every((b) => !b.at.isAfter(limit)), isTrue);
        expect(bars.every((b) => !b.at.isAfter(now)), isTrue);
      }
    });
  });

  Drawing box({double entry = 100, double stop = 99, double target = 102, int at = 5}) => Drawing(
    id: 'p',
    kind: DrawingKind.position,
    a: ChartPoint(history[at].at, entry),
    b: ChartPoint(history[at + 4].at, entry),
    stop: stop,
    target: target,
  );

  group('position boxes fill only on bars revealed after they are placed', () {
    test('a box placed after the bars that touched its stop does not fill on them', () {
      // Bars 0–5 shown; bar 3 went to 98. The box is placed at bar 5.
      final t = PositionTrack(id: 'p', placedAfter: history[5].at);
      expect(t.reveal(bar(3, 100, 100.5, 98, 99), box()), same(t));
    });

    test('entry when a revealed bar trades through the entry, then the target', () {
      var t = PositionTrack(id: 'p', placedAfter: history[5].at);
      t = t.reveal(bar(6, 100.5, 101, 100.2, 100.8), box())!;
      expect(t.entered, isFalse, reason: '100 not traded');
      t = t.reveal(bar(7, 100.5, 100.6, 99.8, 100.2), box())!;
      expect(t.entered, isTrue);
      expect(t.closed, isFalse);
      t = t.reveal(bar(8, 100.2, 102.5, 100, 102), box())!;
      expect(t.reason, ExitReason.target);
      expect(t.toTrade('EURUSD')!.r, closeTo(2, 1e-9));
    });

    test('stop and target in the same revealed bar: the stop', () {
      var t = PositionTrack(id: 'p', placedAfter: history[5].at);
      t = t.reveal(bar(6, 100, 100.2, 99.9, 100), box())!;
      t = t.reveal(bar(7, 100, 103, 98, 100), box())!;
      expect(t.reason, ExitReason.stop);
      expect(t.toTrade('EURUSD')!.r, closeTo(-1, 1e-9));
    });

    test('moving the stop after entry is recorded', () {
      var t = PositionTrack(id: 'p', placedAfter: history[5].at);
      t = t.reveal(bar(6, 100, 100.2, 99.9, 100), box())!;
      t = t.reveal(bar(7, 100, 100.5, 99.5, 100), box(stop: 98))!;
      expect(t.stopMoved, isTrue);
    });

    test('a box removed before entry is dropped; after entry it closes at the next open', () {
      final t = PositionTrack(id: 'p', placedAfter: history[5].at);
      expect(t.reveal(bar(6, 100.5, 101, 100.2, 100.8), null), isNull);
      var e = t.reveal(bar(6, 100, 100.2, 99.9, 100), box())!;
      e = e.reveal(bar(7, 100.4, 100.6, 100.1, 100.5), null)!;
      expect(e.reason, ExitReason.closedByYou);
      expect(e.exit, 100.4);
    });

    test('revealBar starts following a new box from the bar shown before', () {
      final tracks = revealBar(const {}, [box()], bar(6, 100, 100.2, 99.9, 100), lastShown: history[5].at);
      expect(tracks['p']!.entered, isTrue);
    });
  });
}
