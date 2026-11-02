// The markets step (grouped, searchable, futures and stocks hidden), the prop
// limits on the goal step, and Home reading the instruments.
import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/core/theme/doji_theme.dart';
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:doji_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:doji_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/sample_profile.dart';
import '../journal/journal_fixtures.dart';

Future<ProviderContainer> _pump(WidgetTester tester, String step, {double textScale = 1}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(resumeAt(step));
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: testOverrides(prefs));
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dojiDarkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const OnboardingScreen(),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('markets step', () {
    testWidgets('instruments sit under their group; futures and stocks are not offered', (tester) async {
      await _pump(tester, StepIds.markets);
      for (final heading in [
        'FOREX',
        'METALS',
        'INDICES',
        'OIL',
        'CRYPTO',
        'VOLATILITY INDICES',
        'BOOM AND CRASH',
      ]) {
        expect(find.text(heading, skipOffstage: false), findsOneWidget, reason: heading);
      }
      expect(find.text('FUTURES', skipOffstage: false), findsNothing);
      expect(find.text('STOCKS', skipOffstage: false), findsNothing);
      expect(find.text('AAPL', skipOffstage: false), findsNothing);
      expect(find.text('Volatility 75', skipOffstage: false), findsOneWidget);
      expect(find.text('Boom 1000', skipOffstage: false), findsOneWidget);
    });

    testWidgets('search finds by broker alias and picks the canonical symbol', (tester) async {
      final c = await _pump(tester, StepIds.markets);
      await tester.enterText(find.byType(TextField), 'v75');
      await _settle(tester);
      expect(find.text('Volatility 75'), findsOneWidget);
      expect(find.text('EURUSD'), findsNothing);
      expect(find.text('+ add V75'), findsNothing, reason: 'a known alias is not a new symbol');

      await tester.tap(find.text('Volatility 75'));
      await _settle(tester);
      await tester.tap(find.text('continue'));
      await _settle(tester);
      expect(c.read(onboardingControllerProvider).answers[StepIds.markets], ['R_75']);
    });

    testWidgets('an unknown symbol can still be added as custom', (tester) async {
      final c = await _pump(tester, StepIds.markets);
      await tester.enterText(find.byType(TextField), 'ZZZUSD');
      await _settle(tester);
      expect(find.text('+ add ZZZUSD'), findsOneWidget);
      await tester.tap(find.text('+ add ZZZUSD'));
      await _settle(tester);
      await tester.tap(find.text('continue'));
      await _settle(tester);
      expect(c.read(onboardingControllerProvider).answers[StepIds.markets], ['ZZZUSD']);
    });

    testWidgets('searching "gold" finds XAUUSD', (tester) async {
      await _pump(tester, StepIds.markets);
      await tester.enterText(find.byType(TextField), 'gold');
      await _settle(tester);
      expect(find.text('XAUUSD'), findsOneWidget);
      expect(find.text('XAGUSD'), findsNothing);
    });
  });

  group('prop limits on the goal step', () {
    testWidgets('daily loss, max drawdown and profit target are saved with the goal', (tester) async {
      final c = await _pump(tester, StepIds.goal);
      await tester.tap(find.text('pass a prop challenge'));
      await _settle(tester);

      // firm, daily loss, max drawdown, profit target
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4));
      // One action per frame, like a person typing.
      await tester.enterText(fields.at(0), 'My Firm');
      await _settle(tester);
      await tester.tap(find.text('100k'));
      await _settle(tester);
      await tester.enterText(fields.at(1), '5');
      await _settle(tester);
      await tester.enterText(fields.at(2), '10');
      await _settle(tester);
      await tester.enterText(fields.at(3), '8,5');
      await _settle(tester);
      await tester.tap(find.text('continue'));
      await _settle(tester);

      final goal = c.read(onboardingControllerProvider).answers[StepIds.goal]! as Map;
      expect(goal['goal'], 'prop_challenge');
      expect(goal['propFirm'], 'My Firm');
      expect(goal['propSize'], 100000);
      expect(goal['propDailyLoss'], 5.0);
      expect(goal['propMaxDrawdown'], 10.0);
      expect(goal['propTarget'], 8.5);
    });

    testWidgets('nonsense is ignored: zero, over 100, text', (tester) async {
      final c = await _pump(tester, StepIds.goal);
      await tester.tap(find.text('pass a prop challenge'));
      await _settle(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '0');
      await tester.enterText(fields.at(2), '150');
      await tester.enterText(fields.at(3), 'abc');
      await _settle(tester);
      await tester.tap(find.text('continue'));
      await _settle(tester);
      final goal = c.read(onboardingControllerProvider).answers[StepIds.goal]! as Map;
      expect(goal.containsKey('propDailyLoss'), isFalse);
      expect(goal.containsKey('propMaxDrawdown'), isFalse);
      expect(goal.containsKey('propTarget'), isFalse);
    });

    testWidgets('drawdown type: static by default; trailing asks what it follows', (tester) async {
      final c = await _pump(tester, StepIds.goal);
      await tester.tap(find.text('pass a prop challenge'));
      await _settle(tester);
      expect(find.text('static drawdown'), findsOneWidget);
      expect(find.text('trailing drawdown'), findsOneWidget);
      expect(
        find.text('follows balance'),
        findsNothing,
        reason: 'only a trailing drawdown follows something',
      );

      await tester.tap(find.text('trailing drawdown'));
      await _settle(tester);
      expect(find.text('follows balance'), findsOneWidget);
      expect(find.text('follows equity'), findsOneWidget);
      await tester.tap(find.text('follows balance'));
      await _settle(tester);
      await tester.tap(find.text('continue'));
      await _settle(tester);

      final goal = c.read(onboardingControllerProvider).answers[StepIds.goal]! as Map;
      expect(goal['propDrawdownType'], 'trailing');
      expect(goal['propTrailingBasis'], 'balance');
      // A setting alone is not a limit, so there is no PropRules yet.
      expect(c.read(onboardingControllerProvider).profile.prop, isNull);
    });

    testWidgets('prop inputs fit at 200% text', (tester) async {
      await _pump(tester, StepIds.goal, textScale: 2);
      await tester.tap(find.text('pass a prop challenge'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('account currency on the risk step', () {
    testWidgets('four currencies, and the choice is saved', (tester) async {
      final c = await _pump(tester, StepIds.risk);
      for (final code in ['USD', 'ZAR', 'EUR', 'GBP']) {
        expect(find.text(code), findsOneWidget, reason: code);
      }
      await tester.tap(find.text('1%'));
      await _settle(tester);
      await tester.tap(find.text('ZAR'));
      await _settle(tester);
      await tester.tap(find.text('continue'));
      await _settle(tester);
      expect((c.read(onboardingControllerProvider).answers[StepIds.risk]! as Map)['currency'], 'ZAR');
      expect(c.read(onboardingControllerProvider).profile.accountCurrency, 'ZAR');
    });

    testWidgets('leaving it alone means USD', (tester) async {
      final c = await _pump(tester, StepIds.risk);
      await tester.tap(find.text('1%'));
      await _settle(tester);
      await tester.tap(find.text('continue'));
      await _settle(tester);
      expect(c.read(onboardingControllerProvider).profile.accountCurrency, 'USD');
    });

    testWidgets('fits at 200% text', (tester) async {
      await _pump(tester, StepIds.risk, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('Home with other markets', () {
    final saturday = Clock.fixed(DateTime.utc(2026, 10, 10, 12));
    final monday = Clock.fixed(DateTime.utc(2026, 10, 12, 10));

    Map<String, Object> seed(
      List<String> instruments, {
      PropRules? prop,
      TradingRules? rules,
      double? startingSize,
      List<Trade> trades = const [],
    }) => {
      ...seedProfile(
        profile: profileWith(
          name: 'sam',
          instruments: instruments,
          prop: prop,
          rules: rules,
          startingSize: startingSize,
          pledgedAt: DateTime.utc(2026, 10, 1),
          completedAt: DateTime.utc(2026, 10, 1),
        ),
      ),
      if (trades.isNotEmpty) ...seedJournal(trades),
    };

    // One account in the journal: up 3,000 and back down 1,600 on Friday,
    // then down 400 this morning. Balance 101,000; its high 103,000.
    final history = [
      sampleTrade(id: 'up', pnl: 3000, risk: 1000, daysAgo: 3, minutesAgo: 120, now: monday.now()),
      sampleTrade(id: 'down', pnl: -1600, risk: 1000, daysAgo: 3, minutesAgo: 60, now: monday.now()),
      sampleTrade(id: 'today', pnl: -400, risk: 400, minutesAgo: 30, now: monday.now()),
    ];

    testWidgets('gold on a Saturday: the market is closed', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(saturday, () async {
        await AppHarness.pump(tester, at: Routes.home, seed: seed(['XAUUSD', 'BTCUSD']));
        await tester.scrollUntilVisible(find.text('AI BRIEF'), 300);
        expect(find.bySemanticsLabel('The market is open, not met'), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);

    testWidgets('bitcoin on a Saturday: the market is open', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(saturday, () async {
        await AppHarness.pump(tester, at: Routes.home, seed: seed(['BTCUSD']));
        await tester.scrollUntilVisible(find.text('AI BRIEF'), 300);
        expect(find.bySemanticsLabel('The market is open, met'), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);

    testWidgets('a synthetic index reads as open on Monday and shows its label', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(monday, () async {
        await AppHarness.pump(tester, at: Routes.home, seed: seed(['R_75', 'BOOM1000']));
        await tester.scrollUntilVisible(find.text('AI BRIEF'), 300);
        expect(find.text('Volatility 75'), findsOneWidget);
        expect(find.text('Boom 1000'), findsOneWidget);
        expect(find.bySemanticsLabel('The market is open, met'), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);

    testWidgets('prop limits: the stricter daily loss wins, and drawdown gets its own meter', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(monday, () async {
        await AppHarness.pump(
          tester,
          at: Routes.home,
          seed: seed(
            ['EURUSD'],
            prop: const PropRules(dailyLossLimitPct: 1, maxDrawdownPct: 5),
            startingSize: 100000,
            rules: const TradingRules(dailyLossLimit: 2),
            trades: history,
          ),
        );
        await tester.scrollUntilVisible(find.text('RULES TODAY'), 300);
        // This morning's 400 of 100,000.
        expect(find.bySemanticsLabel('daily loss, 0.4% / 1%'), findsOneWidget);
        // Static by default: equity is above the starting balance, so nothing is used.
        expect(find.bySemanticsLabel('prop static drawdown, 0% / 5%'), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);

    testWidgets('trailing equity: the same account has used part of the limit', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(monday, () async {
        await AppHarness.pump(
          tester,
          at: Routes.home,
          seed: seed(
            ['EURUSD'],
            startingSize: 100000,
            prop: const PropRules(maxDrawdownPct: 5, drawdownType: DrawdownType.trailing),
            trades: history,
          ),
        );
        await tester.scrollUntilVisible(find.text('RULES TODAY'), 300);
        // 2,000 below the 103,000 high.
        expect(find.bySemanticsLabel('prop trailing equity drawdown, 2% / 5%'), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);

    // The journal holds closed trades only, so equity equals balance and both
    // bases read the same here; instrument_test covers where they differ.
    testWidgets('trailing balance: the meter names the basis the user chose', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(monday, () async {
        await AppHarness.pump(
          tester,
          at: Routes.home,
          seed: seed(
            ['EURUSD'],
            startingSize: 100000,
            prop: const PropRules(
              maxDrawdownPct: 5,
              drawdownType: DrawdownType.trailing,
              trailingBasis: TrailingBasis.balance,
            ),
            trades: history,
          ),
        );
        await tester.scrollUntilVisible(find.text('RULES TODAY'), 300);
        expect(find.bySemanticsLabel('prop trailing balance drawdown, 2% / 5%'), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);

    testWidgets('no prop: the usual two meters only', (tester) async {
      await withClock(monday, () async {
        await AppHarness.pump(tester, at: Routes.home, seed: seed(['EURUSD']));
        await tester.scrollUntilVisible(find.text('RULES TODAY'), 300);
        expect(find.textContaining('drawdown'), findsNothing);
      });
    }, variant: ios);
  });
}
