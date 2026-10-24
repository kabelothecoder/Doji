// Goldens for Markets 1b, pair detail (design/handoff/Doji Hero Screens.dc.html
// › 1b) on iPhone 390 × 844: the top (price, chart), the brief scrolled to its
// conditions, and the free plan's locked brief.
//
//   flutter test test/goldens --update-goldens   # after an intended change
//
// Sample prices on a pinned summer Wednesday (12:00 UTC, 14:00 in
// Johannesburg). Reduce motion is on, so the brief's cursor is solid.
@Tags(['golden'])
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/markets/data/brief_allowance_repository.dart';
import 'package:doji_app/features/markets/domain/brief_allowance.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';

Future<void> _match(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('markets_$name.png'));

Map<String, Object> _seed({String? briefUsedOn}) => {
  ...seedProfile(
    profile: ProfileDoji(
      name: 'sam',
      instruments: const ['EURUSD', 'XAUUSD'],
      sessions: const ['london'],
      timeZone: 'Africa/Johannesburg',
      utcOffsetMinutes: 120,
      strategy: const StrategyProfile(
        parsed: ParsedStrategy(
          setup: 'london breakout of the asian range',
          timeframe: 'M15',
          entry: 'retest of the broken level, candle closes beyond',
        ),
      ),
      rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
      pledgedAt: DateTime.utc(2026, 7, 1),
      completedAt: DateTime.utc(2026, 7, 1),
    ),
  ),
  if (briefUsedOn != null)
    BriefAllowanceRepository.key: jsonEncode(
      BriefAllowance(day: BriefAllowance.dayKey(summerDay.now()), symbol: briefUsedOn).toJson(),
    ),
};

void main() {
  testWidgets('1b pair detail · top', (tester) async {
    await withClock(summerDay, () async {
      await AppHarness.pump(tester, at: Routes.pairDetail('EURUSD'), seed: _seed());
      await _match('1b_phone');
    });
  }, variant: ios);

  testWidgets('1b pair detail · the brief', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.pairDetail('EURUSD'), seed: _seed());
      await tester.scrollUntilVisible(find.text('02 · WHAT YOUR STRATEGY SAYS'), 300);
      await h.wait(50);
      await _match('1b_brief_phone');
    });
  }, variant: ios);

  testWidgets('1b pair detail · locked on the free plan', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.pairDetail('GBPUSD'),
        seed: _seed(briefUsedOn: 'EURUSD'),
      );
      await tester.scrollUntilVisible(find.text('AI BRIEF · 1/1 USED TODAY'), 300);
      await h.wait(50);
      await _match('1b_locked_phone');
    });
  }, variant: ios);
}
