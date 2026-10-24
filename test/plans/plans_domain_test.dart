import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/plans/domain/plans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recommendPlan', () {
    test('a prop challenge → elite prop, even with tilt struggles', () {
      expect(recommendPlan(const ProfileDoji(goal: 'prop_challenge', struggles: ['revenge'])), PlanId.elite);
    });
    test('revenge, overtrading or fomo → pro trader', () {
      for (final s in ['revenge', 'overtrading', 'fomo']) {
        expect(
          recommendPlan(ProfileDoji(goal: 'consistent', struggles: [s])),
          PlanId.pro,
          reason: s,
        );
      }
    });
    test('learning → basic', () {
      expect(recommendPlan(const ProfileDoji(goal: 'learn', experience: 'lt_6m')), PlanId.basic);
      expect(recommendPlan(const ProfileDoji()), PlanId.basic);
    });
  });

  test('prices: annual is 10x monthly, zar has thousands separators', () {
    final pro = planOf(PlanId.pro);
    expect(pro.usd(BillingPeriod.monthly), r'$24/mo');
    expect(pro.usd(BillingPeriod.annual), r'$240/yr');
    expect(pro.zar(BillingPeriod.annual), 'R3,990/yr');
    expect(planOf(PlanId.elite).zar(BillingPeriod.annual), 'R14,990/yr');
    expect(planOf(PlanId.free).usd(BillingPeriod.annual), r'$0');
  });

  test('recommended plan is listed first and free last, once each', () {
    final order = planOrder(PlanId.elite);
    expect(order, [PlanId.elite, PlanId.basic, PlanId.pro, PlanId.free]);
    expect(planOrder(PlanId.basic), [PlanId.basic, PlanId.pro, PlanId.elite, PlanId.free]);
  });

  test('terms always state trial, price, renewal and where to cancel', () {
    final t = termsLine(PlanId.pro, BillingPeriod.annual, storeName: 'app store');
    expect(t, contains('3 days free'));
    expect(t, contains(r'$240/yr'));
    expect(t, contains('every year'));
    expect(t, contains('cancel in app store settings'));
    expect(
      termsLine(PlanId.free, BillingPeriod.monthly, storeName: 'app store'),
      'free stays free. no card, no trial.',
    );
  });

  test('compare table has a cell for every plan', () {
    for (final r in featureRows) {
      expect(r.cells, hasLength(plans.length), reason: r.feature);
    }
  });
}
