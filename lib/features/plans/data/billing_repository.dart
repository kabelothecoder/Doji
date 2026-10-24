import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/data/onboarding_repository.dart';
import '../domain/plans.dart';

/// How a purchase ended. Cancelling the store sheet is not an error and
/// nothing is charged.
enum PurchaseOutcome { purchased, cancelled, failed }

/// What the person owns right now.
class Entitlement {
  const Entitlement({this.plan = PlanId.free, this.period = BillingPeriod.monthly, this.trialEndsAt});

  final PlanId plan;
  final BillingPeriod period;
  final DateTime? trialEndsAt;

  bool get isTrial => plan != PlanId.free && trialEndsAt != null;
}

/// The store boundary. The UI only sees this; the real implementations are
/// StoreKit (iOS), Play Billing (Android) and the Microsoft Store or doji
/// checkout (Windows).
abstract interface class BillingRepository {
  Entitlement get entitlement;

  /// Opens the OS purchase sheet for [plan].
  Future<PurchaseOutcome> purchase(PlanId plan, BillingPeriod period);

  /// Re-reads the store's receipts and returns what was found.
  Future<Entitlement> restore();

  /// Opens the store's own subscription page (cancel, change, refunds).
  Future<void> openStoreSubscriptions();

  /// Sign out and delete wipe local data.
  Future<void> clear();
}

/// FAKE store: every purchase succeeds with a 3-day trial unless [next] says
/// otherwise. Keeps the entitlement on this device.
class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository(this._prefs, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  static const planKey = 'doji.plan.v1';
  static const periodKey = 'doji.plan.period.v1';
  static const trialKey = 'doji.plan.trial.v1';

  /// Outcome of the next [purchase] (tests and previews).
  PurchaseOutcome next = PurchaseOutcome.purchased;

  /// Times the store subscription page was opened.
  int storeOpened = 0;

  @override
  Entitlement get entitlement {
    final plan = PlanId.values.asNameMap()[_prefs.getString(planKey)] ?? PlanId.free;
    final period = BillingPeriod.values.asNameMap()[_prefs.getString(periodKey)] ?? BillingPeriod.monthly;
    final trial = DateTime.tryParse(_prefs.getString(trialKey) ?? '');
    return Entitlement(plan: plan, period: period, trialEndsAt: plan == PlanId.free ? null : trial);
  }

  @override
  Future<PurchaseOutcome> purchase(PlanId plan, BillingPeriod period) async {
    if (next != PurchaseOutcome.purchased) return next;
    await _prefs.setString(planKey, plan.name);
    await _prefs.setString(periodKey, period.name);
    await _prefs.setString(trialKey, _now().add(const Duration(days: trialDays)).toIso8601String());
    return PurchaseOutcome.purchased;
  }

  @override
  Future<Entitlement> restore() async => entitlement;

  @override
  Future<void> openStoreSubscriptions() async => storeOpened++;

  @override
  Future<void> clear() async {
    await _prefs.remove(planKey);
    await _prefs.remove(periodKey);
    await _prefs.remove(trialKey);
  }
}

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => FakeBillingRepository(ref.watch(sharedPreferencesProvider)),
);
