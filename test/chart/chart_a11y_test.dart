import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/chart/domain/drawing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import 'chart_fixtures.dart';

Map<String, Object> _seed() => chartSeed(
  extra: seedNotes([
    noteFor(
      Drawing(id: 'z', kind: DrawingKind.level, a: ChartPoint(summerDay.now(), 1.085)),
      reason: 'order block on the 15m',
      reply: 'was there a london sweep first?',
    ),
  ]),
);

void main() {
  testWidgets('chart: every tool is a labelled 44pt button, contrast holds', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.chart('EURUSD'), seed: _seed());
      for (final label in [
        'select, selected',
        'zone',
        'level',
        'trend line',
        'position',
        'undo',
        'redo',
        'delete drawing',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await h.tapText('drawings (1)');
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  }, variant: ios);

  testWidgets('chart: the drawings list reads each drawing, its prices and the reason', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.chart('EURUSD'), seed: _seed());
      await h.tapText('drawings (1)');
      expect(find.text('level'), findsWidgets);
      expect(find.text('price 1.08500'), findsOneWidget);
      expect(find.text('you: order block on the 15m'), findsOneWidget);
      expect(find.text('doji: was there a london sweep first?'), findsOneWidget);
      expect(find.bySemanticsLabel('delete level'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget, reason: 'add a level by typing its price');
    });
  }, variant: ios);

  testWidgets('chart renders at 200% text without overflow', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.chart('EURUSD'), seed: _seed(), textScale: 2);
      expect(tester.takeException(), isNull);
      await h.tapText('drawings (1)');
      expect(tester.takeException(), isNull);
    });
  }, variant: ios);
}
