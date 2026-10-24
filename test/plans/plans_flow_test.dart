import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/plans/data/billing_repository.dart';
import 'package:doji_app/features/plans/domain/plans.dart';
import 'package:doji_app/features/plans/presentation/plans_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('recommended plan is selected and the trial starts through the store', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.plans,
      seed: seedProfile(),
      size: const Size(390, 1800),
    );
    expect(find.text('your doji is configured.'), findsOneWidget);
    expect(find.text('RECOMMENDED'), findsOneWidget);
    expect(find.text('start 3-day free trial'), findsOneWidget);

    await h.tapText('annual');
    expect(find.textContaining(r'$240/yr'), findsWidgets);
    expect(find.textContaining('renews every year'), findsOneWidget);

    await h.tapText('start 3-day free trial');
    expect(h.location, Routes.planSuccess);
    expect(find.textContaining('unlocked.'), findsOneWidget);
    expect(h.haptics.events, contains('success'));
    final owned = h.container.read(entitlementProvider);
    expect(owned.plan, PlanId.basic);
    expect(owned.period, BillingPeriod.annual);
    expect(owned.isTrial, isTrue);

    await h.tapText('go home');
    expect(h.location, Routes.home);
  }, variant: ios);

  testWidgets('choosing free needs no store and says so', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.plans,
      seed: seedProfile(),
      size: const Size(390, 1800),
    );
    await h.tapText('free');
    expect(find.text('continue with free'), findsOneWidget);
    expect(find.text('free stays free. no card, no trial.'), findsOneWidget);
    await h.tapText('continue with free');
    expect(h.location, Routes.home);
    expect(h.container.read(entitlementProvider).plan, PlanId.free);
  }, variant: ios);

  testWidgets('a cancelled store sheet charges nothing and offers try again', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.plans,
      seed: seedProfile(),
      size: const Size(390, 1800),
    );
    (h.container.read(billingRepositoryProvider) as FakeBillingRepository).next = PurchaseOutcome.cancelled;
    await h.tapText('start 3-day free trial');
    expect(h.location, Routes.planFailed);
    expect(find.text('no charge was made.'), findsOneWidget);
    expect(h.container.read(entitlementProvider).plan, PlanId.free);

    await h.tapText('try again');
    expect(h.location, Routes.plans);
    await h.tapText('continue free');
    expect(h.location, Routes.home);
  }, variant: ios);

  testWidgets('compare: tapping a column selects it and the call to action follows', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.plans,
      seed: seedProfile(),
      size: const Size(390, 1800),
    );
    await h.tapText('compare all plans');
    expect(h.location, Routes.planCompare);
    expect(find.text('try basic free for 3 days'), findsOneWidget);
    await h.tapText('elite prop');
    expect(find.text('try elite prop free for 3 days'), findsOneWidget);
    await h.tapText('plans');
    expect(h.location, Routes.plans);
    expect(find.text('start 3-day free trial'), findsOneWidget);
  }, variant: ios);

  testWidgets('an upsell link preselects its plan', (tester) async {
    await AppHarness.pump(
      tester,
      at: '${Routes.plans}?plan=pro',
      seed: seedProfile(),
      size: const Size(390, 1800),
    );
    expect(find.textContaining('pro trader'), findsWidgets);
    expect(find.textContaining('trial ends, \$24/mo starts'), findsOneWidget);
  }, variant: ios);

  testWidgets('manage subscription shows the plan and opens the store to cancel', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.plans,
      seed: seedProfile(),
      size: const Size(390, 1800),
    );
    await h.tapText('start 3-day free trial');
    h.router.go(Routes.subscription);
    await h.wait(300);
    expect(find.text('subscription'), findsOneWidget);
    expect(find.text('basic'), findsOneWidget);
    await h.tapText('cancel subscription');
    expect((h.container.read(billingRepositoryProvider) as FakeBillingRepository).storeOpened, 1);
  }, variant: ios);

  testWidgets('200% text scales without overflow on plans and compare', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.plans,
      seed: seedProfile(),
      size: const Size(390, 1800),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('compare all plans'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await h.tapText('compare all plans');
    expect(tester.takeException(), isNull);
  }, variant: ios);

  testWidgets(
    'wide windows show all four plans in one modal, esc closes',
    (tester) async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.plans,
        seed: seedProfile(),
        size: const Size(1440, 900),
      );
      expect(find.text('unlock the engine.'), findsOneWidget);
      for (final n in ['free', 'basic', 'pro trader', 'elite prop']) {
        expect(find.text(n), findsWidgets, reason: n);
      }
      expect(find.text('continue to checkout'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await h.wait(300);
      expect(h.location, Routes.home);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
