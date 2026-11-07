import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/chart/data/chart_note_repository.dart';
import 'package:doji_app/features/chart/domain/chart_note.dart';
import 'package:doji_app/features/chart/domain/drawing.dart';
import 'package:doji_app/features/chart/presentation/widgets/doji_chart.dart';
import 'package:doji_app/features/journal/presentation/journal_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';
import 'chart_fixtures.dart';

List<ChartNote> storedNotes(AppHarness h) {
  final raw = h.prefs.getString(PrefsChartNoteRepository.key);
  if (raw == null) return const [];
  return [for (final n in (jsonDecode(raw) as Map)['notes'] as List) ChartNote.fromJson(n)!];
}

Future<void> addByPrice(AppHarness h, WidgetTester tester, String kind, List<String> prices) async {
  await h.tap(find.text(kind).last);
  final fields = find.byType(TextField);
  final n = fields.evaluate().length;
  for (var i = 0; i < prices.length; i++) {
    await tester.enterText(fields.at(n - prices.length + i), prices[i]);
  }
  await h.wait(50);
  await h.tap(find.text('add $kind'));
}

void main() {
  testWidgets('phone: add a level by price, say why, the co-pilot holds it to the rules', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.chart('EURUSD'), seed: chartSeed());
      expect(find.byType(DojiChart), findsOneWidget);
      await h.tapText('drawings (0)');
      expect(find.text('ADD BY PRICE'), findsOneWidget);
      await addByPrice(h, tester, 'level', ['1.0850']);

      expect(find.text('what is this?'), findsWidgets);
      await tester.enterText(find.byType(TextField).last, 'order block on the 15m');
      await h.wait(50);
      await h.tapText('save my reason');
      expect(find.textContaining('i take order blocks only after a london sweep'), findsOneWidget);

      final note = storedNotes(h).single;
      expect(note.drawing.kind, DrawingKind.level);
      expect(note.drawing.a.price, 1.085);
      expect(note.reason, 'order block on the 15m');
      expect(note.copilot.map((t) => t.fromYou), [true, false]);
      expect(note.accountId, 'account_1');
      expect(note.timeframe.label, 'M15');

      await h.tapText('done');
      expect(find.text('drawings (1)'), findsOneWidget);
    });
  }, variant: ios);

  testWidgets('skip keeps the drawing with no reason and asks nothing', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.chart('EURUSD'), seed: chartSeed());
      await h.tapText('drawings (0)');
      await addByPrice(h, tester, 'zone', ['1.0860', '1.0840']);
      await h.tapText('skip');
      final note = storedNotes(h).single;
      expect(note.reason, isNull);
      expect(note.copilot, isEmpty);
      expect(note.drawing.prices.map((p) => p.$2), [1.086, 1.084]);
    });
  }, variant: ios);

  testWidgets('a position opens the pre-trade check; a limit says so and offers the coach, never blocks', (
    tester,
  ) async {
    await withClock(summerDay, () async {
      final now = summerDay.now();
      final h = await AppHarness.pump(
        tester,
        at: Routes.chart('EURUSD'),
        seed: chartSeed(
          extra: seedJournal([
            for (var i = 0; i < 3; i++) sampleTrade(id: 't$i', pnl: 10, now: now, minutesAgo: 30 + i * 40),
          ]),
        ),
      );
      await h.tapText('drawings (0)');
      await addByPrice(h, tester, 'position', ['1.0850', '1.0830', '1.0890']);

      expect(find.text('before this trade'), findsOneWidget);
      expect(find.text("you've taken 3 of 3 trades today. your rules say the day is done."), findsOneWidget);
      expect(find.text('talk to the coach'), findsOneWidget);
      expect(find.text('trades today 3 of 3'), findsOneWidget);
      expect(find.text('LIMIT REACHED'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('continue'), 200, scrollable: find.byType(Scrollable).last);
      await h.tapText('continue');

      expect(find.text('what is this?'), findsWidgets);
      await h.tapText('skip');
      final note = storedNotes(h).single;
      expect(note.drawing.stopSide, 'stop below entry');
      expect(
        note.checklist!.where((c) => c.status == 'limitHit').map((c) => c.label),
        contains('trades today 3 of 3'),
      );
    });
  }, variant: ios);

  testWidgets(
    'windows: H then a click draws a level; Ctrl+Z takes it off; the list has it',
    (tester) async {
      await withClock(summerDay, () async {
        final h = await AppHarness.pump(
          tester,
          at: Routes.chart('EURUSD'),
          seed: chartSeed(),
          size: const Size(1440, 900),
        );
        expect(find.text('DRAWINGS (0)'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
        await h.wait(50);
        expect(find.bySemanticsLabel('level, selected'), findsOneWidget);
        await tester.tapAt(tester.getCenter(find.byType(DojiChart)));
        await h.wait();
        expect(find.text('what is this?'), findsWidgets);
        await h.tapText('skip');
        expect(find.text('DRAWINGS (1)'), findsOneWidget);
        expect(find.text('level · selected'), findsOneWidget);

        // Arrow up nudges the selected level by a tick.
        final before = storedNotes(h).single.drawing.a.price;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await h.wait(50);
        expect(storedNotes(h).single.drawing.a.price, closeTo(before + 0.00001, 1e-9));

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await h.wait(50);
        expect(find.text('DRAWINGS (0)'), findsOneWidget);
        expect(storedNotes(h).single.deleted, isTrue, reason: 'kept for undo and redo');

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await h.wait(50);
        expect(find.text('DRAWINGS (1)'), findsOneWidget);
        expect(storedNotes(h).single.deleted, isFalse);

        // Undo clears the selection: pick it from the list, then Delete.
        await h.tap(find.bySemanticsLabel('select level'));
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await h.wait(50);
        expect(find.text('DRAWINGS (0)'), findsOneWidget);
      });
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('1b: tapping the chart opens the full chart', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.pairDetail('EURUSD'), seed: chartSeed());
      await h.tap(find.bySemanticsLabel('open the full chart to draw'));
      expect(h.location, Routes.chart('EURUSD'));
    });
  }, variant: ios);

  testWidgets('a trade logged after a note links it; trade detail shows how you got here', (tester) async {
    await withClock(summerDay, () async {
      final now = summerDay.now();
      final level = Drawing(id: 'n1', kind: DrawingKind.level, a: ChartPoint(now, 1.085));
      final h = await AppHarness.pump(
        tester,
        at: Routes.markets,
        seed: chartSeed(
          extra: seedNotes([
            noteFor(
              level,
              at: now.subtract(const Duration(hours: 2)),
              reason: 'order block on the 15m',
              reply: 'was there a london sweep first?',
            ),
          ]),
        ),
      );
      final trade = sampleTrade(id: 'tr', pnl: 20, now: clock.now(), minutesAgo: 10, symbol: 'EURUSD');
      await h.container.read(journalControllerProvider.notifier).add(trade);
      expect(storedNotes(h).single.tradeId, 'tr');

      h.router.go(Routes.tradeDetail('tr'));
      await h.wait();
      await tester.scrollUntilVisible(find.text('HOW YOU GOT HERE'), 300);
      expect(find.text('you: order block on the 15m'), findsOneWidget);
      expect(find.text('doji: was there a london sweep first?'), findsOneWidget);
    });
  }, variant: ios);
}
