// Markets 1b, pair detail (design/handoff/Doji Hero Screens.dc.html › 1b) in
// the real app: price and chips, the chart, the five-part brief, the
// watchlist bookmark, "remind me", the free plan's one brief a day, the ask
// sheet, and the accessibility floor. Sample prices on a pinned summer day.
import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/core/platform/reminders.dart';
import 'package:doji_app/features/markets/data/brief_allowance_repository.dart';
import 'package:doji_app/features/markets/domain/brief_allowance.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/plans/data/billing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../helpers/fakes.dart';

/// The handoff's trader, in Johannesburg (UTC+2): on [summerDay] (Wednesday
/// 12:00 UTC) London and New York are open and the sample USD release is at
/// 12:30 UTC = 14:30 on their clock.
Map<String, Object> _seed({
  List<String> instruments = const ['XAUUSD', 'NAS100'],
  String? plan,
  String? briefUsedOn,
}) => {
  ...seedProfile(
    profile: ProfileDoji(
      name: 'sam',
      instruments: instruments,
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
  FakeBillingRepository.planKey: ?plan,
  if (briefUsedOn != null)
    BriefAllowanceRepository.key: jsonEncode(
      BriefAllowance(day: BriefAllowance.dayKey(summerDay.now()), symbol: briefUsedOn).toJson(),
    ),
};

Future<AppHarness> _open(
  WidgetTester tester, {
  String symbol = 'EURUSD',
  Map<String, Object>? seed,
  FakeReminders? reminders,
  FakeVoiceInput? voice,
  double textScale = 1,
  Size size = const Size(390, 844),
}) => AppHarness.pump(
  tester,
  at: Routes.pairDetail(symbol),
  seed: seed ?? _seed(),
  reminders: reminders,
  voice: voice,
  textScale: textScale,
  size: size,
);

List<String> _watchlist(AppHarness h) => List<String>.from(
  (jsonDecode(h.prefs.getString(PrefsOnboardingRepository.profileKey)!) as Map)['instruments'] as List,
);

Future<void> _scrollTo(WidgetTester tester, Finder f) =>
    tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);

void main() {
  testWidgets('price, chips, chart and the five sections, all labelled sample', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(summerDay, () async {
      await _open(tester);
      expect(find.text('EUR/USD'), findsOneWidget);
      expect(find.text('sample prices · not a live feed'), findsOneWidget);
      expect(find.text('NEW YORK · CLOSES 23:00'), findsOneWidget);
      expect(find.text('NEWS 14:30'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^([+-]\d+\.\d\d|0\.00)% today$')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Candlestick chart for EUR/USD, M15, sample prices, with your asian range levels and the next news window',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('doji brief'), findsOneWidget);
      expect(find.text('UPDATED 14:00'), findsOneWidget);
      for (final label in [
        '01 · MARKET CONTEXT',
        '02 · WHAT YOUR STRATEGY SAYS',
        '03 · YOUR ENTRY CONDITIONS',
        '04 · RISK NOTE',
        '05 · CHECK AGAIN',
      ]) {
        await _scrollTo(tester, find.text(label));
        expect(find.text(label), findsOneWidget);
        // The list is lazy: check each section's content while it is on screen.
        if (label.startsWith('02')) expect(find.text('london breakout of the asian range'), findsOneWidget);
        if (label.startsWith('03')) {
          await _scrollTo(tester, find.bySemanticsLabel('No high-impact news within 30 min, not met'));
          expect(find.bySemanticsLabel('No high-impact news within 30 min, not met'), findsOneWidget);
        }
      }
      await _scrollTo(tester, find.text('Measured against your strategy. Not financial advice.'));
      expect(find.text('Measured against your strategy. Not financial advice.'), findsOneWidget);
      expect(find.text('explain the risk note'), findsOneWidget);
      expect(find.bySemanticsLabel('ask about this brief'), findsOneWidget);
    });
    handle.dispose();
  }, variant: ios);

  testWidgets('timeframes switch the chart', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(summerDay, () async {
      final h = await _open(tester);
      await h.tap(find.bySemanticsLabel('1 hour chart'));
      expect(find.bySemanticsLabel(RegExp(r'^Candlestick chart for EUR/USD, H1, ')), findsOneWidget);
      await h.tap(find.bySemanticsLabel('1 day chart'));
      expect(find.bySemanticsLabel(RegExp(r'^Candlestick chart for EUR/USD, D1, ')), findsOneWidget);
    });
    handle.dispose();
  }, variant: ios);

  testWidgets('the bookmark adds to the watchlist (profile.doji) and removes again', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(summerDay, () async {
      final h = await _open(tester);
      await h.tap(find.bySemanticsLabel('add to watchlist'));
      expect(_watchlist(h), ['XAUUSD', 'NAS100', 'EURUSD']);
      expect(find.bySemanticsLabel('remove from watchlist'), findsOneWidget);
      await h.tap(find.bySemanticsLabel('remove from watchlist'));
      expect(_watchlist(h), ['XAUUSD', 'NAS100']);
      expect(h.haptics.events, contains('light'));
    });
    handle.dispose();
  }, variant: ios);

  testWidgets('removing the last market asks first', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(summerDay, () async {
      final h = await _open(tester, seed: _seed(instruments: const ['EURUSD']));
      await h.tap(find.bySemanticsLabel('remove from watchlist'));
      expect(find.text('remove your last market?'), findsOneWidget);
      await h.tapText('cancel');
      expect(_watchlist(h), ['EURUSD']);
      await h.tap(find.bySemanticsLabel('remove from watchlist'));
      await h.tapText('remove');
      expect(_watchlist(h), isEmpty);
    });
    handle.dispose();
  }, variant: ios);

  testWidgets('remind me schedules the check-again time; the button says it is set', (tester) async {
    await withClock(summerDay, () async {
      final h = await _open(tester);
      await _scrollTo(tester, find.text('remind me'));
      expect(find.text('after the news window closes'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      await h.tapText('remind me');
      final r = h.reminders.scheduled.single;
      expect(r.at, DateTime.utc(2026, 7, 15, 13));
      expect(r.title, 'check EUR/USD again');
      expect(find.text('reminder set'), findsOneWidget);
      expect(find.textContaining('doji will remind you at 15:00.'), findsOneWidget);
    });
  }, variant: ios);

  testWidgets('remind me with notifications off says how to turn them on', (tester) async {
    await withClock(summerDay, () async {
      final h = await _open(tester, reminders: FakeReminders(ReminderResult.denied));
      await _scrollTo(tester, find.text('remind me'));
      await h.tapText('remind me');
      expect(find.textContaining('notifications are off for doji'), findsOneWidget);
      expect(find.text('remind me'), findsOneWidget);
    });
  }, variant: ios);

  group('free plan: one ai brief a day', () {
    testWidgets("opening a pair uses today's brief", (tester) async {
      await withClock(summerDay, () async {
        final h = await _open(tester);
        final saved = BriefAllowance.fromJson(jsonDecode(h.prefs.getString(BriefAllowanceRepository.key)!));
        expect(saved.symbol, 'EURUSD');
        expect(find.text('01 · MARKET CONTEXT'), findsOneWidget);
      });
    }, variant: ios);

    testWidgets('another pair: the written brief is locked, conditions still show, ask opens the upsell', (
      tester,
    ) async {
      await withClock(summerDay, () async {
        final h = await _open(tester, seed: _seed(briefUsedOn: 'XAUUSD'));
        await _scrollTo(tester, find.text('AI BRIEF · 1/1 USED TODAY'));
        expect(find.textContaining("you've used today's ai brief on XAU/USD."), findsOneWidget);
        expect(find.text('01 · MARKET CONTEXT'), findsNothing);
        expect(find.text('04 · RISK NOTE'), findsNothing);
        await _scrollTo(tester, find.text('03 · YOUR ENTRY CONDITIONS'));
        expect(find.text('03 · YOUR ENTRY CONDITIONS'), findsOneWidget);
        await h.tap(find.bySemanticsLabel('ask about this brief'));
        expect(find.text("you've used today's ai brief."), findsOneWidget);
        expect(find.text('see basic'), findsWidgets);
      });
    }, variant: ios);

    testWidgets('paid plans see every brief', (tester) async {
      await withClock(summerDay, () async {
        await _open(
          tester,
          seed: _seed(plan: 'basic', briefUsedOn: 'XAUUSD'),
        );
        expect(find.text('01 · MARKET CONTEXT'), findsOneWidget);
        expect(find.text('AI BRIEF · 1/1 USED TODAY'), findsNothing);
      });
    }, variant: ios);
  });

  group('ask about this brief', () {
    testWidgets('a suggested question opens the sheet and gets an answer from the brief', (tester) async {
      await withClock(summerDay, () async {
        final h = await _open(tester);
        await _scrollTo(tester, find.text('explain the risk note'));
        await h.tapText('explain the risk note');
        expect(find.text('scoped to your EUR/USD brief · updated 14:00'), findsOneWidget);
        expect(find.textContaining('min either side of 14:30'), findsOneWidget);
        await h.tester.enterText(find.byType(TextField), 'should I go long?');
        await h.wait(50);
        await h.tap(find.bySemanticsLabel('send'));
        expect(find.textContaining("i don't call the market"), findsOneWidget);
        await h.tap(find.bySemanticsLabel('close'));
        expect(find.text('scoped to your EUR/USD brief · updated 14:00'), findsNothing);
      });
    }, variant: ios);

    testWidgets('by voice on the free plan: typed, and it says why', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(summerDay, () async {
        final h = await _open(tester, voice: FakeVoiceInput());
        await h.tap(find.bySemanticsLabel('ask by voice'));
        expect(find.text('voice questions come with pro trader. type yours below.'), findsOneWidget);
        expect(find.text('see pro trader'), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);

    testWidgets('by voice on pro: the mic opens, and what it heard is sent', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(summerDay, () async {
        final mic = FakeVoiceInput();
        final h = await _open(
          tester,
          seed: _seed(plan: 'pro'),
          voice: mic,
        );
        await h.tap(find.bySemanticsLabel('ask by voice').first);
        expect(mic.listening, isTrue);
        expect(find.text('LISTENING…'), findsOneWidget);
        mic.say('what counts as a retest?');
        await h.wait(50);
        await h.tap(find.bySemanticsLabel('send what you said'));
        expect(mic.listening, isFalse);
        expect(find.textContaining('by your plan, the entry is: retest of the broken level'), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);
  });

  testWidgets("Home's brief card opens 1b for its instrument", (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.home, seed: _seed());
      await tester.scrollUntilVisible(find.text('open the brief'), 300);
      await h.tapText('open the brief');
      expect(h.location, Routes.pairDetail('XAUUSD'));
      expect(find.text('XAU/USD'), findsOneWidget);
    });
  }, variant: ios);

  testWidgets('Windows: Esc goes back', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.home, seed: _seed(), size: const Size(1280, 800));
      unawaited(h.router.push(Routes.pairDetail('EURUSD')));
      await h.wait();
      expect(h.location, Routes.pairDetail('EURUSD'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await h.wait();
      expect(h.location, Routes.home);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  group('accessibility', () {
    Future<void> floor(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    testWidgets('44pt labelled targets and contrast, top and bottom', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(summerDay, () async {
        final h = await _open(tester);
        await floor(tester);
        // The end of the list, at a whole-pixel offset: a fractional scroll
        // blurs 12px text in the screenshot the contrast check samples.
        final list = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
        for (var i = 0; i < 3; i++) {
          list.jumpTo(list.maxScrollExtent.floorToDouble());
          await h.wait(50);
        }
        expect(find.text('explain the risk note'), findsOneWidget);
        await floor(tester);
      });
      handle.dispose();
    }, variant: ios);

    testWidgets('android: 48dp targets', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(summerDay, () async {
        await _open(tester, size: const Size(412, 915));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });
      handle.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('200% text scrolls instead of overflowing, and the sheet too', (tester) async {
      await withClock(summerDay, () async {
        final h = await _open(tester, textScale: 2, size: const Size(375, 667));
        expect(tester.takeException(), isNull);
        await _scrollTo(tester, find.text('explain the risk note'));
        expect(tester.takeException(), isNull);
        await h.tapText('explain the risk note');
        expect(tester.takeException(), isNull);
      });
    }, variant: ios);
  });
}
