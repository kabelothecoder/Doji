// Journal insights (rules on fixtures, the store, the feed flow) and the imported trade banner.
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/auth/presentation/auth_controller.dart';
import 'package:doji_app/features/journal/data/insights_repository.dart';
import 'package:doji_app/features/journal/data/trade_import.dart';
import 'package:doji_app/features/journal/domain/insights.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import 'insights_fixtures.dart';
import 'journal_fixtures.dart';

class _Import implements TradeImport {
  _Import(this.trades);

  final List<Trade> trades;

  @override
  Future<List<Trade>> closedTrades(TradingAccount account) async => trades;
}

void main() {
  final now = DateTime(2026, 7, 15, 12);

  test('insights on fixtures: leaks and edges in R, each with its sample', () {
    final found = {for (final i in findInsights(insightTrades(now))) i.id: i};
    expect(found.keys.toSet(), {'time', 'tag:revenge', 'lucky', 'setup:london breakout', 'rule'});

    final time = found['time']!;
    expect(time.kind, InsightKind.leak);
    expect(time.n, 6);
    expect(time.totalR, -6);
    expect(time.headline, 'your trades opened from 15:00 total −6R');
    expect(time.note, 'only 6 trades · small sample');
    expect(time.how.first, 'found in 6 of your 20 trades (opened from 15:00).');

    final setup = found['setup:london breakout']!;
    expect(setup.kind, InsightKind.edge);
    expect(setup.headline, 'london breakout: +10R over 10 trades, your strongest setup so far');
    expect(setup.smallSample, isFalse);

    expect(found['rule']!.headline, 'graded A–B: +1R a trade. graded D–F: −0.4R a trade');
    expect(found['lucky']!.headline, '4 winning trades had no setup from your strategy');
    expect(found['tag:revenge']!.rule, 'after a loss, wait 15 min before the next entry');

    final list = findInsights(insightTrades(now));
    expect(list.takeWhile((i) => i.kind == InsightKind.leak).length, 3, reason: 'leaks first');
  });

  test('a pattern needs 3 trades with an R; trades without a risk are left out', () {
    final few = insightTrades(now).take(12).toList();
    expect(findInsights(few).where((i) => i.id == 'time'), isEmpty, reason: 'only 2 late trades');
    final noRisk = [
      for (var d = 0; d < 5; d++)
        Trade(
          id: 'x$d',
          symbol: 'R_75',
          direction: TradeDirection.long,
          openedAt: DateTime(2026, 7, 15 - d, 16).toUtc(),
          closedAt: DateTime(2026, 7, 15 - d, 16, 30).toUtc(),
          entry: 1,
          exit: 0.9,
          size: 1,
          pnl: -10,
        ),
    ];
    expect(findInsights(noRisk), isEmpty);
    expect(rText(-0.25), '−0.3R');
    expect(rText(2), '+2R');
  });

  test('insight prefs round-trip and skip junk', () {
    const p = InsightPrefs(watching: {'time'}, hidden: {'lucky'}, ruled: {'rule'}, later: {'mt5-1'});
    final back = InsightPrefs.fromJson(jsonDecode(jsonEncode(p.toJson())));
    expect(
      [back.watching, back.hidden, back.ruled, back.later],
      [
        {'time'},
        {'lucky'},
        {'rule'},
        {'mt5-1'},
      ],
    );
    expect(InsightPrefs.fromJson({'watching': 'nope'}).watching, isEmpty);
  });

  testWidgets('imported trade: banner, later; insights: watch, hide + undo, add as rule; sign out clears', (
    tester,
  ) async {
    await withClock(summerDay, () async {
      final local = summerDay.now().toLocal();
      final h = await AppHarness.pump(
        tester,
        at: Routes.journal,
        seed: {...seedProfile(), ...seedSession(), ...seedJournal(insightTrades(local))},
        overrides: [
          tradeImportProvider.overrideWithValue(_Import([importedTrade(local)])),
        ],
      );
      await h.wait(1500);
      expect(find.textContaining('new trade imported · EURUSD long · −1R'), findsOneWidget);
      await h.tapText('later');
      expect(find.textContaining('new trade imported'), findsNothing);
      expect(h.prefs.getString(InsightsRepository.key), contains('mt5-1'));

      await tester.scrollUntilVisible(
        find.text('all insights'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await h.tapText('all insights');
      expect(h.location, Routes.insights);

      await h.tap(find.bySemanticsLabel('watch this').first);
      await h.tap(find.bySemanticsLabel('show watching'));
      expect(find.bySemanticsLabel('stop watching'), findsOneWidget);
      await h.tap(find.bySemanticsLabel('show all'));

      await h.tap(find.bySemanticsLabel('not useful').first);
      expect(find.textContaining('> hidden.'), findsOneWidget);
      await h.tapText('undo');
      expect(find.textContaining('> hidden.'), findsNothing);

      await h.tap(find.bySemanticsLabel(RegExp(r'^leak: your trades opened from 15:00')));
      expect(h.location, Routes.insight('time'));
      await tester.scrollUntilVisible(
        find.textContaining('add as rule ·'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await h.tap(find.textContaining('add as rule ·'));
      expect(find.textContaining('rule added ·'), findsOneWidget);
      final profile = h.container.read(onboardingRepositoryProvider).loadProfile()!;
      expect(profile.activeAccount!.strategy!.stayOutWhen, contains('no new entries from 15:00'));

      await h.container.read(accountActionsProvider).signOut();
      expect(h.prefs.getString(InsightsRepository.key), isNull);
      expect(h.container.read(insightPrefsProvider).watching, isEmpty);
      expect(clock.now(), summerDay.now());
    });
  }, variant: ios);

  testWidgets('imported trade: "review · 20 sec" opens the review sheet', (tester) async {
    await withClock(summerDay, () async {
      final local = summerDay.now().toLocal();
      final h = await AppHarness.pump(
        tester,
        at: Routes.journal,
        seed: {...seedProfile(), ...seedSession()},
        overrides: [
          tradeImportProvider.overrideWithValue(_Import([importedTrade(local)])),
        ],
      );
      await h.wait(1500);
      await h.tapText('review · 20 sec');
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  }, variant: ios);
}
