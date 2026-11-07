// Goldens for doji's chart (no design file; design/SOURCE.md › Missing):
// one per drawing tool on iPhone 390 × 844, and Windows with all four, a
// selection and the drawings list beside the chart.
//
//   flutter test test/goldens --update-goldens   # after an intended change
//
// Sample prices on a pinned summer Wednesday (12:00 UTC).
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/chart/domain/drawing.dart';
import 'package:doji_app/features/markets/data/fake_market_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chart/chart_fixtures.dart';
import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';

Future<void> _match(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('chart_$name.png'));

final _now = summerDay.now();
const _m15 = Duration(minutes: 15);

/// Drawings placed around the sample EURUSD price at the pinned time.
Drawing _drawing(DrawingKind kind, double price) => switch (kind) {
  DrawingKind.level => Drawing(id: 'level', kind: kind, a: ChartPoint(_now, price + 0.0006)),
  DrawingKind.zone => Drawing(
    id: 'zone',
    kind: kind,
    a: ChartPoint(_now.subtract(_m15 * 30), price - 0.0004),
    b: ChartPoint(_now.subtract(_m15 * 18), price - 0.0009),
  ),
  DrawingKind.trendLine => Drawing(
    id: 'trend',
    kind: kind,
    a: ChartPoint(_now.subtract(_m15 * 40), price - 0.0012),
    b: ChartPoint(_now.subtract(_m15 * 4), price + 0.0002),
  ),
  DrawingKind.position => Drawing(
    id: 'position',
    kind: kind,
    a: ChartPoint(_now.subtract(_m15 * 2), price),
    b: ChartPoint(_now.add(_m15 * 6), price),
    stop: price - 0.0006,
    target: price + 0.0012,
  ),
};

/// The sample price at the pinned time, so the drawings sit on it.
Future<double> _price() async =>
    (await const FakeMarketData(latency: Duration.zero).quote('EURUSD', now: _now))!.price;

void main() {
  for (final kind in DrawingKind.values) {
    testWidgets('chart · ${kind.label}', (tester) async {
      await withClock(summerDay, () async {
        final price = await _price();
        final h = await AppHarness.pump(
          tester,
          at: Routes.chart('EURUSD'),
          seed: chartSeed(
            extra: seedNotes([noteFor(_drawing(kind, price), reason: 'order block on the 15m')]),
          ),
        );
        final tool = kind == DrawingKind.trendLine ? 'trend line' : kind.label;
        await h.tap(find.bySemanticsLabel(tool));
        await _match('${kind.name}_phone');
      });
    }, variant: ios);
  }

  testWidgets(
    'chart · windows, all tools, one selected, the list',
    (tester) async {
      await withClock(summerDay, () async {
        final price = await _price();
        final h = await AppHarness.pump(
          tester,
          at: Routes.chart('EURUSD'),
          size: const Size(1440, 900),
          seed: chartSeed(
            extra: seedNotes([
              for (final k in DrawingKind.values)
                noteFor(
                  _drawing(k, price),
                  reason: k == DrawingKind.zone ? 'order block on the 15m' : null,
                  reply: k == DrawingKind.zone ? 'was there a london sweep first?' : null,
                ),
            ]),
          ),
        );
        await h.tap(find.bySemanticsLabel('select position'));
        await _match('windows');
      });
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
