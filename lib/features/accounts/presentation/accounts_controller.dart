import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:uuid/uuid.dart';

import '../../analyst/presentation/analyst_controller.dart';
import '../../chart/presentation/chart_controller.dart';
import '../../home/presentation/home_controller.dart';
import '../data/broker_link_repository.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../domain/condition_eval.dart';
import '../domain/trading_account.dart';

/// Marks every provider that reads account data (the profile, the active
/// account's trades, and what is built from them) for recompute, now.
///
/// Not just the sources: screens under the current route (Home and markets
/// under settings, other shell tabs) have paused subscriptions, and resume
/// them while a frame builds. A provider left only "may have changed" is
/// then rebuilt by its dependent's flush, notifies it, and riverpod 3.3
/// schedules a refresh mid-build, which throws (fixed in riverpod 3.4.1,
/// which needs Dart 3.12). Marked here, those notifications return early.
/// A new provider that reads account data belongs in this list.
void invalidateAccountReaders(ProviderContainer c) {
  for (final p in <ProviderOrFamily>[
    homeProfileProvider,
    homeSnapshotProvider,
    marketsProfileProvider,
    watchlistProvider,
    pairBriefProvider,
    journalProfileProvider,
    accountCurrencyProvider,
    activeAccountTradesProvider,
    journalViewProvider,
    periodTradesProvider,
    journalStatsProvider,
    brokerReadingProvider,
    chartControllerProvider,
    analystFactsProvider,
    latestReviewProvider,
    focusRuleProvider,
  ]) {
    c.invalidate(p);
  }
}

/// The trader's accounts and which one is active, from profile.doji. Every
/// change saves at once and makes Home, the journal and markets read again.
class AccountsController extends Notifier<ProfileDoji> {
  @override
  ProfileDoji build() => ref.watch(onboardingRepositoryProvider).loadProfile() ?? const ProfileDoji();

  static String newId() => 'account_${const Uuid().v4()}';

  /// A blank account of [kind], with the default conditions.
  static TradingAccount blank(AccountKind kind) => TradingAccount(
    id: newId(),
    name: kind.label,
    kind: kind,
    strategy: StrategyProfile(conditions: defaultConditions(null)),
  );

  Future<void> save(TradingAccount account) => _set(state.upsertAccount(account));

  Future<void> switchTo(String id) => _set(state.switchAccount(id));

  /// The last account cannot be deleted (a trader always has one).
  Future<void> delete(String id) => _set(state.removeAccount(id));

  /// How often the trader can look at the charts (profile-wide, saved at once).
  Future<void> setAvailability(String value) =>
      _set(state.copyWith(availability: value, availabilityCheckedAt: clock.now().toUtc()));

  /// "still fits": the 90-day re-check answered without a change.
  Future<void> confirmFit() => _set(state.copyWith(availabilityCheckedAt: clock.now().toUtc()));

  Future<void> _set(ProfileDoji next) async {
    state = next;
    await ref.read(onboardingRepositoryProvider).saveProfile(next);
    invalidateAccountReaders(ref.container);
  }
}

final accountsControllerProvider = NotifierProvider.autoDispose<AccountsController, ProfileDoji>(
  AccountsController.new,
);
