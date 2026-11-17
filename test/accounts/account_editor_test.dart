// The accounts list and the editor through the real router: reached from
// settings and from MEASURED AGAINST, switch, add, edit, delete (asks first).
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/accounts/data/strategy_reader.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:doji_app/features/onboarding/domain/strategy_parser.dart';
import 'package:doji_app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../helpers/sample_profile.dart';

const _deriv = TradingAccount(id: 'deriv', name: 'deriv synthetics', kind: AccountKind.derivSynthetic);

Map<String, Object> _seed({bool two = false}) => seedProfile(
  profile: profileWith(
    name: 'sam',
    instruments: const ['XAUUSD'],
    strategy: const StrategyProfile(parsed: ParsedStrategy(setup: 'london breakout of the asian range')),
    rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
    pledgedAt: DateTime.utc(2026, 7, 1),
    completedAt: DateTime.utc(2026, 7, 1),
  ).let((p) => two ? p.upsertAccount(_deriv) : p),
);

ProfileDoji _stored(AppHarness h) => ProfileDoji.fromJson(
  jsonDecode(h.prefs.getString(PrefsOnboardingRepository.profileKey)!) as Map<String, dynamic>,
);

extension<T> on T {
  R let<R>(R Function(T it) f) => f(this);
}

void main() {
  testWidgets('settings → accounts: the active one is marked, another can be made active', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.settings, seed: _seed(two: true));
      await h.tapText('accounts and strategies');
      expect(find.text('accounts'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      await h.tap(find.bySemanticsLabel('make deriv synthetics active'));
      expect(_stored(h).activeAccount!.id, 'deriv');
    });
  }, variant: ios);

  testWidgets('add an account, rename it, save: the list and profile.doji have it', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.accounts, seed: _seed());
      await h.tapText('add an account');
      expect(find.text('edit account'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'personal mt5');
      await h.wait(50);
      await h.tapText('save');
      expect(find.text('personal mt5'), findsOneWidget);
      expect(_stored(h).accounts.map((a) => a.name), contains('personal mt5'));
      // Adding does not switch: the trader picks the active one.
      expect(_stored(h).activeAccount!.id, kFirstAccountId);
    });
  }, variant: ios);

  testWidgets('limits and a rule of your own are saved; the rule reads "check on your chart"', (
    tester,
  ) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.accountEditor(kFirstAccountId), seed: _seed());
      await h.tap(find.bySemanticsLabel(RegExp('increase max trades a day', caseSensitive: false)).first);
      await tester.ensureVisible(find.byType(TextField).last);
      await tester.enterText(find.byType(TextField).last, 'price above the 50 ema on H1');
      await h.wait(50);
      await h.tap(find.bySemanticsLabel('add rule'));
      expect(find.text('price above the 50 ema on H1 · check on your chart'), findsOneWidget);
      await h.tapText('save');
      final a = _stored(h).activeAccount!;
      expect(a.rules!.maxTradesPerDay, 4);
      expect(
        a.strategy!.conditions.last,
        const StrategyCondition(kind: ConditionKind.manual, text: 'price above the 50 ema on H1'),
      );
    });
  }, variant: ios);

  testWidgets('delete asks first: cancel keeps it, delete removes it', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.accountEditor('deriv'), seed: _seed(two: true));
      await h.tapText('delete this account');
      expect(find.text('delete deriv synthetics?'), findsOneWidget);
      await h.tapText('cancel');
      expect(_stored(h).accounts, hasLength(2));
      await h.tapText('delete this account');
      await h.tapText('delete');
      expect(_stored(h).accounts.map((a) => a.id), [kFirstAccountId]);
    });
  }, variant: ios);

  testWidgets('the last account has no delete', (tester) async {
    await withClock(summerDay, () async {
      await AppHarness.pump(tester, at: Routes.accountEditor(kFirstAccountId), seed: _seed());
      expect(find.text('delete this account'), findsNothing);
    });
  }, variant: ios);

  testWidgets('MEASURED AGAINST opens the active account at its strategy', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.markets, seed: _seed());
      await h.tapText('MEASURED AGAINST');
      expect(find.text('edit account').hitTestable(), findsNothing); // scrolled past the title
      expect(find.text('in your own words. say it or type it.').hitTestable(), findsOneWidget);
      expect(h.location, '/settings/accounts/:id'.replaceFirst(':id', kFirstAccountId));
    });
  }, variant: ios);

  Finder strategyField() => find.byWidgetPredicate((w) => w is TextField && w.minLines == 3);
  Finder sizeField() => find.byWidgetPredicate((w) => w is TextField && w.keyboardType.decimal == true).first;
  DojiButton saveButton(WidgetTester tester) =>
      tester.widget<DojiButton>(find.widgetWithText(DojiButton, 'save'));

  testWidgets('system back with an unsaved name asks first', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.accounts, seed: _seed());
      await h.tap(find.bySemanticsLabel('edit personal').first);
      await tester.enterText(find.byType(TextField).first, 'renamed');
      await h.wait(50);
      await tester.binding.handlePopRoute();
      await h.wait();
      expect(find.text('leave without saving?'), findsOneWidget);
      await h.tapText('cancel');
      expect(h.location, Routes.accountEditor(kFirstAccountId));
      expect(_stored(h).activeAccount!.name, isNot('renamed'));
    });
  }, variant: ios);

  testWidgets('a blank account saves the limits its steppers show: 1% · 3 · 2%', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.accounts, seed: _seed());
      await h.tapText('add an account');
      await h.tapText('save');
      final added = _stored(h).accounts.last;
      expect(added.rules, const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2));
    });
  }, variant: ios);

  testWidgets('new strategy words are read again: MEASURED AGAINST follows, conditions stay', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.markets, seed: _seed());
      final before = _stored(h).activeAccount!.strategy!.conditions;
      await h.tapText('MEASURED AGAINST');
      await tester.enterText(strategyField(), 'i trade the new york breakout on M5');
      await h.wait(50);
      await h.tapText('save');
      expect(find.text('new york breakout'), findsOneWidget);
      final s = _stored(h).activeAccount!.strategy!;
      expect(s.parsed!.setup, 'new york breakout');
      expect(s.conditions, before);
    });
  }, variant: ios);

  testWidgets('prop rules round trip: entered, saved, shown again', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.accountEditor(kFirstAccountId), seed: _seed());
      await h.tapText('this account has prop rules');
      await tester.enterText(find.widgetWithText(TextField, 'daily loss limit, %'), '4');
      await tester.enterText(find.widgetWithText(TextField, 'max drawdown, %'), '10');
      await h.wait(50);
      await h.tapText('trailing');
      await h.tapText('balance');
      await h.tapText('save');
      const want = PropRules(
        dailyLossLimitPct: 4,
        maxDrawdownPct: 10,
        drawdownType: DrawdownType.trailing,
        trailingBasis: TrailingBasis.balance,
      );
      expect(_stored(h).activeAccount!.prop, want);
      h.router.go(Routes.accountEditor(kFirstAccountId));
      await h.wait();
      expect(find.text('4'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });
  }, variant: ios);

  testWidgets('starting size: a number saves; zero or junk shows an error and save is off', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.accountEditor(kFirstAccountId), seed: _seed());
      await tester.enterText(sizeField(), '0');
      await h.wait(50);
      expect(find.text('enter a size above zero, or leave it empty.'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
      await tester.enterText(sizeField(), '1.2.3');
      await h.wait(50);
      expect(saveButton(tester).onPressed, isNull);
      await tester.enterText(sizeField(), '25000');
      await h.wait(50);
      expect(find.text('enter a size above zero, or leave it empty.'), findsNothing);
      await h.tapText('save');
      expect(_stored(h).activeAccount!.startingSize, 25000);
    });
  }, variant: ios);

  testWidgets('conditions reorder with labelled up / down buttons', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.accountEditor(kFirstAccountId), seed: _seed());
      final first = _stored(h).activeAccount!.strategy!.conditions;
      await h.tap(find.bySemanticsLabel('move trades today under your max up'));
      await h.tapText('save');
      final now = _stored(h).activeAccount!.strategy!.conditions;
      expect(now.first, first[1]);
      expect(now[1], first.first);
    });
  }, variant: ios);

  testWidgets('read my words: keep mine drops the proposal, use these replaces the list on save', (
    tester,
  ) async {
    await withClock(summerDay, () async {
      const words = 'london breakout of the asian range on m15, wait for a close back';
      final h = await AppHarness.pump(
        tester,
        at: Routes.accountEditor(kFirstAccountId, strategy: true),
        seed: _seed(),
      );
      await tester.enterText(strategyField(), words);
      await h.wait(50);
      await h.tapText('read my words');
      await h.wait(50);
      expect(find.text('DOJI READ YOUR WORDS AS'), findsOneWidget);
      await h.tapText('keep mine');
      expect(find.text('DOJI READ YOUR WORDS AS'), findsNothing);

      await h.tapText('read my words');
      await h.wait(50);
      await h.tapText('use these');
      expect(find.text('DOJI READ YOUR WORDS AS'), findsNothing);
      await h.tapText('save');
      final proposed = (await const FakeStrategyReader().propose(words)).conditions;
      expect(_stored(h).activeAccount!.strategy!.conditions, proposed);
    });
  }, variant: ios);

  testWidgets('the parser fails: the words are saved, parsed is cleared, and it says so', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.accountEditor(kFirstAccountId, strategy: true),
        seed: _seed(),
        parser: _FailingParser(),
      );
      await tester.enterText(strategyField(), 'my own way of reading the open');
      await h.wait(50);
      await h.tapText('save');
      expect(
        find.textContaining("couldn't read your strategy, saved your words.", findRichText: true),
        findsOneWidget,
      );
      expect(h.location, Routes.accountEditor(kFirstAccountId));
      final s = _stored(h).activeAccount!.strategy!;
      expect(s.rawText, 'my own way of reading the open');
      expect(s.parsed, isNull);
      expect(s.conditions, isNotEmpty);
    });
  }, variant: ios);

  group('from settings back to Home (Home and markets paused under settings)', () {
    const deriv = TradingAccount(
      id: 'deriv',
      name: 'deriv synthetics',
      kind: AccountKind.derivSynthetic,
      instruments: ['R_75'],
      rules: TradingRules(riskPerTrade: 0.5, maxTradesPerDay: 5, dailyLossLimit: 3),
    );

    Future<AppHarness> toAccounts(WidgetTester tester) async {
      final seed = seedProfile(
        profile: profileWith(
          name: 'sam',
          instruments: const ['XAUUSD'],
          rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
          pledgedAt: DateTime.utc(2026, 7, 1),
          completedAt: DateTime.utc(2026, 7, 1),
        ).upsertAccount(deriv),
      );
      final h = await AppHarness.pump(tester, at: Routes.home, seed: seed);
      await tester.scrollUntilVisible(find.text('RULES TODAY'), 300);
      expect(find.bySemanticsLabel(RegExp(r'daily loss, .*/ 2%')), findsOneWidget);
      await h.tapText('me');
      await h.tap(find.bySemanticsLabel('settings').first);
      await h.tapText('accounts and strategies');
      return h;
    }

    Future<void> backToHome(AppHarness h) async {
      while (h.location != Routes.me) {
        await h.tap(find.bySemanticsLabel('Back').last);
      }
      await h.tapText('home');
      await h.tester.scrollUntilVisible(find.text('RULES TODAY'), 300);
    }

    testWidgets('make another account active, back out: Home reads its limits', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(summerDay, () async {
        final h = await toAccounts(tester);
        await h.tap(find.bySemanticsLabel('make deriv synthetics active'));
        await backToHome(h);
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel(RegExp(r'daily loss, .*/ 3%')), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);

    testWidgets('save in the editor, back out: Home reads the new limit', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(summerDay, () async {
        final h = await toAccounts(tester);
        await h.tap(find.bySemanticsLabel('edit personal').first);
        await h.tap(find.bySemanticsLabel(RegExp('increase daily loss limit', caseSensitive: false)).first);
        await h.tapText('save');
        await backToHome(h);
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel(RegExp(r'daily loss, .*/ 2\.5%')), findsOneWidget);
      });
      handle.dispose();
    }, variant: ios);
  });
}

class _FailingParser implements StrategyParser {
  @override
  Future<ParsedStrategy> parse(String description) async => throw Exception('parser down');
}
