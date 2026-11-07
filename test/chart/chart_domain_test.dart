import 'package:doji_app/features/chart/domain/chart_note.dart';
import 'package:doji_app/features/chart/domain/chart_viewport.dart';
import 'package:doji_app/features/chart/domain/copilot.dart';
import 'package:doji_app/features/chart/domain/drawing.dart';
import 'package:doji_app/features/chart/domain/drawing_drafts.dart';
import 'package:doji_app/features/chart/domain/drawing_editor.dart';
import 'package:doji_app/features/chart/domain/hit_test.dart';
import 'package:doji_app/features/chart/domain/position_math.dart';
import 'package:doji_app/features/markets/data/placeholder_rate_source.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/instrument_catalog.dart';
import 'package:doji_app/features/markets/domain/rate_source.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime.utc(2026, 7, 15, 8);
const step = Duration(minutes: 15);

/// 100 M15 bars from 1.0800 rising by 0.0001 a bar.
final bars = [
  for (var i = 0; i < 100; i++)
    Candle(
      at: t0.add(step * i),
      open: 1.08 + i * 1e-4,
      high: 1.0802 + i * 1e-4,
      low: 1.0798 + i * 1e-4,
      close: 1.0801 + i * 1e-4,
    ),
];

ChartGeometry geo([ChartViewport v = const ChartViewport(start: 40, count: 50)]) =>
    ChartGeometry.of(viewport: v, bars: bars, timeframe: Timeframe.m15, size: const Size(556, 400));

class _StaleRates implements RateSource {
  @override
  double? rate(String from, String to) => from == to ? 1 : null;

  @override
  Future<void> prepare(String from, String to) async {}
}

void main() {
  group('viewport', () {
    test('index, time and pixel round-trip', () {
      final g = geo();
      for (final i in [0.0, 41.6, 99.0, 104.0, -3.0]) {
        expect(g.indexOfX(g.xOfIndex(i)), closeTo(i, 1e-9));
        expect(g.indexOfTime(g.timeOfIndex(i)), closeTo(i, 1e-6));
      }
      expect(g.priceOf(g.yOf(1.085)), closeTo(1.085, 1e-12));
      expect(g.plot.width, 500);
    });

    test('a gap in the bars takes no room', () {
      final gapped = [
        ...bars.take(10),
        ...bars
            .skip(10)
            .map(
              (c) => Candle(
                at: c.at.add(const Duration(days: 2)),
                open: c.open,
                high: c.high,
                low: c.low,
                close: c.close,
              ),
            ),
      ];
      final g = ChartGeometry.of(
        viewport: const ChartViewport(start: 0, count: 50),
        bars: gapped,
        timeframe: Timeframe.m15,
        size: const Size(556, 400),
      );
      expect(g.indexOfTime(gapped[10].at), 10);
      expect(
        g.indexOfTime(gapped[9].at.add(const Duration(hours: 5))),
        10,
        reason: 'inside the gap clamps to the next bar',
      );
    });

    test('pan clamps so five bars stay on screen', () {
      const v = ChartViewport(start: 40, count: 50);
      expect(v.pan(1000, 100).start, 95);
      expect(v.pan(-1000, 100).start, -45);
    });

    test('zoom keeps the anchor bar under the pointer and clamps the count', () {
      const v = ChartViewport(start: 40, count: 50);
      final z = v.zoom(2, 0.5, 100);
      expect(z.count, 25);
      expect(z.start + 0.5 * z.count, v.start + 0.5 * v.count);
      expect(v.zoom(100, 0, 100).count, ChartViewport.minBars);
      expect(v.zoom(0.001, 0, 1000).count, ChartViewport.maxBars);
    });
  });

  group('hit test', () {
    final g = geo();
    final level = Drawing(id: 'lvl', kind: DrawingKind.level, a: ChartPoint(t0.add(step * 60), 1.0850));
    final zone = Drawing(
      id: 'zone',
      kind: DrawingKind.zone,
      a: ChartPoint(t0.add(step * 50), 1.0860),
      b: ChartPoint(t0.add(step * 60), 1.0840),
    );
    final trend = Drawing(
      id: 'trend',
      kind: DrawingKind.trendLine,
      a: ChartPoint(t0.add(step * 70), 1.0850),
      b: ChartPoint(t0.add(step * 80), 1.0870),
    );
    final pos = Drawing(
      id: 'pos',
      kind: DrawingKind.position,
      a: ChartPoint(t0.add(step * 82), 1.0880),
      b: ChartPoint(t0.add(step * 88), 1.0880),
      stop: 1.0870,
      target: 1.0900,
    );
    final all = [level, zone, trend, pos];

    test('handles first, then bodies', () {
      expect(hitTest(all, g, g.offsetOf(trend.a)), const Hit('trend', DrawingHandle.a));
      expect(hitTest(all, g, g.offsetOf(trend.b!)), const Hit('trend', DrawingHandle.b));
      final mid = (g.offsetOf(trend.a) + g.offsetOf(trend.b!)) / 2;
      expect(hitTest(all, g, mid + const Offset(0, 6)), const Hit('trend'));
      expect(hitTest(all, g, Offset(g.xOf(pos.a.at), g.yOf(1.0870))), const Hit('pos', DrawingHandle.stop));
      expect(hitTest(all, g, Offset(g.xOf(pos.a.at), g.yOf(1.0900))), const Hit('pos', DrawingHandle.target));
      expect(hitTest(all, g, Offset(g.xOf(t0.add(step * 85)), g.yOf(1.0890))), const Hit('pos'));
    });

    test('a level is hit along its whole width within the tolerance', () {
      expect(hitTest([level], g, Offset(10, g.yOf(1.0850) + 11)), const Hit('lvl'));
      expect(hitTest([level], g, Offset(10, g.yOf(1.0850) + 14)), isNull);
    });

    test('overlapping drawings: the later one is on top', () {
      final under = zone.copyWith();
      final over = Drawing(id: 'over', kind: DrawingKind.zone, a: zone.a, b: zone.b);
      final p = Offset(g.xOf(t0.add(step * 55)), g.yOf(1.0850));
      expect(hitTest([under, over], g, p)?.drawingId, 'over');
    });

    test('the selected drawing\'s handle wins over a body on top of it', () {
      final under = level;
      final over = Drawing(
        id: 'cover',
        kind: DrawingKind.zone,
        a: ChartPoint(t0.add(step * 40), 1.09),
        b: ChartPoint(t0.add(step * 90), 1.08),
      );
      final h = handlesOf(under, g)[DrawingHandle.a]!;
      expect(hitTest([under, over], g, h)?.drawingId, 'cover');
      expect(hitTest([under, over], g, h, selectedId: 'lvl'), const Hit('lvl', DrawingHandle.a));
    });

    test('empty space hits nothing', () {
      expect(hitTest(all, g, const Offset(5, 5)), isNull);
    });
  });

  group('editor', () {
    final a = Drawing(id: 'a', kind: DrawingKind.level, a: ChartPoint(t0, 1.08));
    final b = Drawing(
      id: 'b',
      kind: DrawingKind.trendLine,
      a: ChartPoint(t0, 1.08),
      b: ChartPoint(t0.add(step * 4), 1.09),
    );

    test('add, move, resize, delete, undo and redo', () {
      var e = const DrawingEditor().add(a).add(b);
      e = e.move('a', step, 0.001);
      expect(e.byId('a')!.a, ChartPoint(t0.add(step), 1.081));
      e = e.moveHandle('b', DrawingHandle.b, ChartPoint(t0.add(step * 8), 1.1));
      expect(e.byId('b')!.b, ChartPoint(t0.add(step * 8), 1.1));
      expect(e.byId('b')!.a, b.a);
      e = e.delete('a');
      expect(e.byId('a'), isNull);
      e = e.undo();
      expect(e.byId('a'), isNotNull);
      e = e.undo().undo();
      expect(e.byId('a')!.a, a.a);
      e = e.redo();
      expect(e.byId('a')!.a.price, 1.081);
      expect(e.canRedo, isTrue);
      e = e.add(a.copyWith(a: ChartPoint(t0, 2)));
      expect(e.canRedo, isFalse, reason: 'a new edit drops the redo stack');
    });

    test('no-op edits leave no undo step', () {
      final e = const DrawingEditor().add(a);
      expect(identical(e.replace(a), e), isTrue);
      expect(identical(e.delete('missing'), e), isTrue);
      expect(identical(const DrawingEditor().undo().drawings, const DrawingEditor().drawings), isTrue);
    });

    test('undo keeps 50 steps', () {
      var e = const DrawingEditor().add(a);
      for (var i = 0; i < 80; i++) {
        e = e.move('a', Duration.zero, 0.0001);
      }
      expect(e.undoStack.length, DrawingEditor.maxUndo);
    });

    test('a position keeps its entry on both edges', () {
      final p = draftDrawing(DrawingKind.position, start: ChartPoint(t0, 1.08), barStep: step, span: 0.001);
      final moved = p.withHandle(DrawingHandle.a, ChartPoint(t0.add(step), 1.081));
      expect(moved.b!.price, 1.081);
      expect(moved.withHandle(DrawingHandle.b, ChartPoint(t0.add(step * 20), 5)).b!.price, 1.081);
      expect(moved.withHandle(DrawingHandle.stop, ChartPoint(t0, 1.07)).stop, 1.07);
    });
  });

  group('drafts', () {
    test('a tap gives a sized default; a drag follows the pointer', () {
      final zone = draftDrawing(DrawingKind.zone, start: ChartPoint(t0, 1.08), barStep: step, span: 0.001);
      expect(zone.a.price, closeTo(1.081, 1e-12));
      expect(zone.b!.at, t0.add(step * 10));
      final dragged = draftDrawing(
        DrawingKind.trendLine,
        start: ChartPoint(t0, 1.08),
        end: ChartPoint(t0.add(step * 3), 1.09),
        barStep: step,
        span: 0.001,
      );
      expect(dragged.b, ChartPoint(t0.add(step * 3), 1.09));
    });

    test('a position: the drag sets the stop, the target starts at 2R', () {
      final p = draftDrawing(
        DrawingKind.position,
        start: ChartPoint(t0, 1.08),
        end: ChartPoint(t0.add(step * 2), 1.079),
        barStep: step,
        span: 0.001,
      );
      expect(p.stop, 1.079);
      expect(p.target, closeTo(1.082, 1e-12));
      expect(p.b!.at, t0.add(step * 12), reason: 'a short drag gets a readable width');
      expect(p.stopSide, 'stop below entry');
    });
  });

  group('position figures', () {
    final p = Drawing(
      id: 'p',
      kind: DrawingKind.position,
      a: ChartPoint(t0, 1.0800),
      b: ChartPoint(t0.add(step * 10), 1.0800),
      stop: 1.0780,
      target: 1.0850,
    );

    test('R, money at risk and size for the active account', () {
      final f = PositionFigures.of(
        p,
        instrument: instrumentBySymbol('EURUSD'),
        startingSize: 10000,
        riskPct: 1,
        currency: 'USD',
        rates: const PlaceholderRateSource(),
      );
      expect(f.r, closeTo(2.5, 1e-9));
      expect(f.riskMoney, 100);
      expect(f.size, closeTo(0.5, 1e-6), reason: '20 pips at \$10 a pip a lot = \$200 a lot');
    });

    test('no size when the rate is unknown: never guessed', () {
      final f = PositionFigures.of(
        p,
        instrument: instrumentBySymbol('EURUSD'),
        startingSize: 10000,
        riskPct: 1,
        currency: 'ZAR',
        rates: _StaleRates(),
      );
      expect(f.riskMoney, 100);
      expect(f.size, isNull);
    });

    test('no account size: no money, no size', () {
      final f = PositionFigures.of(
        p,
        instrument: null,
        startingSize: null,
        riskPct: 1,
        currency: 'USD',
        rates: _StaleRates(),
      );
      expect(f.riskMoney, isNull);
      expect(f.size, isNull);
      expect(f.r, closeTo(2.5, 1e-9));
    });
  });

  group('chart notes', () {
    ChartNote note(
      String id, {
      DateTime? at,
      String account = 'acc',
      String symbol = 'EURUSD',
      String? trade,
      bool deleted = false,
    }) => ChartNote(
      id: id,
      accountId: account,
      symbol: symbol,
      timeframe: Timeframe.m15,
      createdAt: at ?? t0,
      updatedAt: at ?? t0,
      drawing: Drawing(id: id, kind: DrawingKind.level, a: ChartPoint(t0, 1.08)),
      tradeId: trade,
      deleted: deleted,
    );

    test('json round-trip, bad records give null', () {
      final n = note('n').copyWith(
        reason: () => 'order block on the 15m',
        copilot: [CopilotTurn(fromYou: true, text: 'order block on the 15m', at: t0)],
        checklist: () => const [
          ChecklistAnswer(label: 'London session is open', status: 'met', answer: CheckAnswer.yes),
        ],
      );
      final back = ChartNote.fromJson(n.toJson())!;
      expect(back.reason, n.reason);
      expect(back.copilot.single.text, 'order block on the 15m');
      expect(back.checklist!.single.answer, CheckAnswer.yes);
      expect(back.drawing, n.drawing);
      expect(ChartNote.fromJson({'id': 'x'}), isNull);
      expect(
        Drawing.fromJson({
          'id': 'x',
          'kind': 'position',
          'a': n.drawing.a.toJson(),
          'b': n.drawing.a.toJson(),
        }),
        isNull,
      );
    });

    test('notes leading to a trade: same account and symbol, the day before, live, unlinked', () {
      final open = t0.add(const Duration(hours: 3));
      final notes = [
        note('yes', at: t0),
        note('later', at: open.add(const Duration(minutes: 1))),
        note('old', at: open.subtract(const Duration(hours: 25))),
        note('other account', account: 'b'),
        note('other symbol', symbol: 'GBPUSD'),
        note('linked', trade: 't0'),
        note('deleted', deleted: true),
      ];
      expect(notesLeadingTo(notes, accountId: 'acc', symbol: 'eurusd', openedAt: open).map((n) => n.id), [
        'yes',
      ]);
    });
  });

  test('odds words are caught', () {
    for (final s in [
      '70% of these work',
      '80% chance it holds',
      'a high-quality setup',
      'it will reach the target',
      'the odds favour it',
      'likely to hold',
    ]) {
      expect(ratesOdds(s), isTrue, reason: s);
    }
    for (final s in [
      'your rules take order blocks only after a london sweep. was there one?',
      'what in your plan does this zone mark?',
      "you're at your daily loss limit (2%).",
      'risk 1% on this one',
    ]) {
      expect(ratesOdds(s), isFalse, reason: s);
    }
  });
}
