import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../home/presentation/home_controller.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../domain/condition_eval.dart';
import '../domain/trading_account.dart';

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

  Future<void> _set(ProfileDoji next) async {
    state = next;
    await ref.read(onboardingRepositoryProvider).saveProfile(next);
    ref
      ..invalidate(marketsProfileProvider)
      ..invalidate(homeProfileProvider)
      ..invalidate(journalProfileProvider)
      ..invalidate(journalViewProvider);
  }
}

final accountsControllerProvider = NotifierProvider.autoDispose<AccountsController, ProfileDoji>(
  AccountsController.new,
);
