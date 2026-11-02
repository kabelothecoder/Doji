// The accounts list and the editor through the real router: reached from
// settings and from MEASURED AGAINST, switch, add, edit, delete (asks first).
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
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
}
