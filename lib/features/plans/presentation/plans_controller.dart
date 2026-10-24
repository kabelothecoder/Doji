import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_info.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../data/billing_repository.dart';
import '../domain/plans.dart';

/// "app store", "google play" or "microsoft store": whoever bills.
String get storeName => PlatformInfo.isAndroid
    ? 'google play'
    : PlatformInfo.isDesktop
    ? 'microsoft store'
    : 'app store';

/// What the person owns. Replaced after a purchase or a restore.
class EntitlementController extends Notifier<Entitlement> {
  @override
  Entitlement build() => ref.watch(billingRepositoryProvider).entitlement;

  Future<void> restore() async {
    state = await ref.read(billingRepositoryProvider).restore();
  }

  void refresh() => state = ref.read(billingRepositoryProvider).entitlement;
}

final entitlementProvider = NotifierProvider<EntitlementController, Entitlement>(EntitlementController.new);

class PlansState {
  const PlansState({
    required this.recommended,
    required this.selected,
    required this.expanded,
    this.period = BillingPeriod.monthly,
    this.busy = false,
  });

  final PlanId recommended;
  final PlanId selected;

  /// The plan whose details are open; null when all are collapsed.
  final PlanId? expanded;
  final BillingPeriod period;

  /// The store sheet is up.
  final bool busy;

  bool get paid => selected != PlanId.free;

  PlansState copyWith({PlanId? selected, Object? expanded = _keep, BillingPeriod? period, bool? busy}) =>
      PlansState(
        recommended: recommended,
        selected: selected ?? this.selected,
        expanded: identical(expanded, _keep) ? this.expanded : expanded as PlanId?,
        period: period ?? this.period,
        busy: busy ?? this.busy,
      );
}

const Object _keep = Object();

/// The plans screen and the compare table share one selection and one billing
/// period: switching either updates every price, the timeline and the terms.
class PlansController extends Notifier<PlansState> {
  @override
  PlansState build() {
    final profile = ref.read(onboardingRepositoryProvider).loadProfile() ?? const ProfileDoji();
    final rec = recommendPlan(profile);
    return PlansState(recommended: rec, selected: rec, expanded: rec);
  }

  /// Preselects [id] and opens it (the upsell sheets' call to action).
  void preselect(PlanId id) => state = state.copyWith(selected: id, expanded: id);

  void setPeriod(BillingPeriod p) => state = state.copyWith(period: p);

  /// Tapping the selected plan again collapses it; selecting another opens it.
  void pick(PlanId id) {
    final collapse = state.selected == id && state.expanded == id;
    state = state.copyWith(selected: id, expanded: collapse ? null : id);
  }

  /// Selects a column of the compare table without touching what is open.
  void select(PlanId id) => state = state.copyWith(selected: id, expanded: id);

  /// Opens the store sheet. Free needs no purchase.
  Future<PurchaseOutcome?> purchase() async {
    if (!state.paid || state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      final outcome = await ref.read(billingRepositoryProvider).purchase(state.selected, state.period);
      if (outcome == PurchaseOutcome.purchased) ref.read(entitlementProvider.notifier).refresh();
      return outcome;
    } on Object {
      return PurchaseOutcome.failed;
    } finally {
      state = state.copyWith(busy: false);
    }
  }
}

final plansControllerProvider = NotifierProvider.autoDispose<PlansController, PlansState>(
  PlansController.new,
);
