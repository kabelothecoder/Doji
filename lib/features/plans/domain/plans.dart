import '../../onboarding/domain/profile_doji.dart';

/// Source: design/handoff `Doji Plans.dc.html` (and `Doji Plans Phone.dc.html`).
enum PlanId { free, basic, pro, elite }

enum BillingPeriod { monthly, annual }

/// Days of free access on every paid plan.
const int trialDays = 3;

/// Annual is priced at 10x monthly.
const String annualNote = '2 months free';

/// One plan. Prices are placeholders until the store sheets provide the real
/// ones (StoreKit, Play Billing, Microsoft Store); the store always charges
/// its own amount, not this one.
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.usdMonthly,
    required this.zarMonthly,
    required this.includes,
  });

  final PlanId id;
  final String name;
  final int usdMonthly;
  final int zarMonthly;
  final List<String> includes;

  bool get isFree => id == PlanId.free;

  String usd(BillingPeriod period) => isFree
      ? r'$0'
      : period == BillingPeriod.annual
      ? '\$${usdMonthly * 10}/yr'
      : '\$$usdMonthly/mo';

  String zar(BillingPeriod period) => isFree
      ? 'R0'
      : period == BillingPeriod.annual
      ? 'R${_thousands(zarMonthly * 10)}/yr'
      : 'R${_thousands(zarMonthly)}/mo';

  static String _thousands(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

const List<Plan> plans = [
  Plan(
    id: PlanId.free,
    name: 'free',
    usdMonthly: 0,
    zarMonthly: 0,
    includes: ['mood check-in', 'journal', 'doji grid', '1 ai brief a day'],
  ),
  Plan(
    id: PlanId.basic,
    name: 'basic',
    usdMonthly: 9,
    zarMonthly: 149,
    includes: ['unlimited ai chat', 'setup memory', 'everything in free'],
  ),
  Plan(
    id: PlanId.pro,
    name: 'pro trader',
    usdMonthly: 24,
    zarMonthly: 399,
    includes: [
      'full journal + toolkit',
      'strategy analyzer',
      'monthly bias report',
      'guard',
      '60 voice-coach min a month',
      'everything in basic',
    ],
  ),
  Plan(
    id: PlanId.elite,
    name: 'elite prop',
    usdMonthly: 99,
    zarMonthly: 1499,
    includes: [
      'voice coach (fair use)',
      'multiple prop accounts',
      'pdf reports',
      'multi-seat',
      'api access',
      'everything in pro',
    ],
  ),
];

Plan planOf(PlanId id) => plans.firstWhere((p) => p.id == id);

/// Voice coaching comes with pro trader (60 min a month) and elite prop (fair
/// use); on the other plans the coach is text. TODO(next-slice): count pro's
/// minutes and show `UpsellKind.voice` when they run out.
bool includesVoiceCoach(PlanId id) => id == PlanId.pro || id == PlanId.elite;

/// A row of the compare table. A cell is `true` (included), `false` (not
/// included) or a short string.
class FeatureRow {
  const FeatureRow(this.feature, this.cells);

  final String feature;

  /// In [PlanId] order: free, basic, pro, elite.
  final List<Object> cells;
}

const List<FeatureRow> featureRows = [
  FeatureRow('mood check-in', [true, true, true, true]),
  FeatureRow('journal', ['basic', 'basic', 'full', 'full']),
  FeatureRow('doji grid', [true, true, true, true]),
  FeatureRow('ai brief + chat', ['1/day', 'unlim.', 'unlim.', 'unlim.']),
  FeatureRow('setup memory', [false, true, true, true]),
  FeatureRow('toolkit', [false, false, true, true]),
  FeatureRow('strategy analyzer', [false, false, true, true]),
  FeatureRow('monthly bias report', [false, false, true, true]),
  FeatureRow('guard', [false, false, true, true]),
  FeatureRow('voice coach', [false, false, '60 min', 'fair use']),
  FeatureRow('prop accounts', [false, false, '1', 'multiple']),
  FeatureRow('pdf reports', [false, false, false, true]),
  FeatureRow('multi-seat', [false, false, false, true]),
  FeatureRow('api access', [false, false, false, true]),
];

/// The one plan marked "recommended", picked from onboarding: a prop
/// challenge → elite prop; revenge trading, overtrading or fomo → pro trader;
/// anything else (learning properly, under 6 months) → basic.
PlanId recommendPlan(ProfileDoji p) {
  if (p.goal == 'prop_challenge') return PlanId.elite;
  if (p.struggles.any(const {'revenge', 'overtrading', 'fomo'}.contains)) return PlanId.pro;
  // Aggressive risk, or a large personal account, gets the guard and the coach.
  if (p.riskAppetite == 'aggressive' || p.usualDeposit == '25k_plus') return PlanId.pro;
  return PlanId.basic;
}

/// The "why" line under the recommended plan. Neutral: no performance claims.
String recommendationReason(PlanId id) => switch (id) {
  PlanId.elite => 'every prop account tracked against its own rules.',
  PlanId.pro => 'guard + coach for tilt moments.',
  PlanId.basic => 'unlimited questions while you learn properly.',
  PlanId.free => '',
};

/// Plans in display order: the recommended one first, then the rest, free last.
List<PlanId> planOrder(PlanId recommended) => [
  recommended,
  ...const [PlanId.basic, PlanId.pro, PlanId.elite].where((i) => i != recommended),
  PlanId.free,
];

/// The renewal and cancellation line, always shown beside the call to action.
String termsLine(PlanId id, BillingPeriod period, {required String storeName}) {
  if (id == PlanId.free) return 'free stays free. no card, no trial.';
  final plan = planOf(id);
  final every = period == BillingPeriod.annual ? 'every year' : 'every month';
  return '$trialDays days free, then ${plan.usd(period)} (${plan.zar(period)}). '
      'renews $every until you cancel in $storeName settings, at least 24 hours before renewal.';
}
