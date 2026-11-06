import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/presentation/accounts_controller.dart';
import '../../../core/platform/reminders.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../plans/domain/plans.dart';
import '../../plans/presentation/plans_controller.dart';
import '../data/brief_allowance_repository.dart';
import '../data/fake_brief.dart';
import '../data/fake_market_data.dart';
import '../domain/brief_allowance.dart';
import '../domain/candle.dart';
import '../domain/market_data.dart';
import '../domain/market_format.dart';
import '../domain/pair_brief.dart';
import '../domain/strategy_reading.dart';

/// Auto-disposed and invalidated after a watchlist edit: profile.doji is read
/// synchronously from storage, not watched.
final marketsProfileProvider = Provider.autoDispose<ProfileDoji>(
  (ref) => ref.watch(onboardingRepositoryProvider).loadProfile() ?? const ProfileDoji(),
);

/// The latest (sample) price of [symbol]; null when doji has no feed for it.
final pairQuoteProvider = FutureProvider.autoDispose.family<Quote?, String>(
  (ref, symbol) => ref.watch(marketDataProvider).quote(symbol, now: clock.now()),
);

/// The chart's bars for one instrument and timeframe.
final pairCandlesProvider = FutureProvider.autoDispose.family<List<Candle>, (String, Timeframe)>(
  (ref, key) => ref.watch(marketDataProvider).candles(key.$1, key.$2, now: clock.now()),
);

/// What a brief for [symbol] is measured against, now.
BriefRequest briefRequest(Ref ref, String symbol) => BriefRequest(
  symbol: symbol,
  profile: ref.watch(marketsProfileProvider),
  trades: ref.watch(activeAccountTradesProvider),
  now: clock.now(),
);

/// 1b's brief (and Home's conditions). Rebuilt when the journal or the
/// profile changes.
final pairBriefProvider = FutureProvider.autoDispose.family<PairBrief, String>(
  (ref, symbol) => ref.watch(briefSourceProvider).brief(briefRequest(ref, symbol)),
);

/// The chart's timeframe: the strategy's own to start with (M15 by default).
class PairTimeframe extends Notifier<Timeframe> {
  PairTimeframe(this.symbol);

  final String symbol;

  @override
  Timeframe build() => StrategyReading.of(ref.read(marketsProfileProvider).strategy?.parsed).timeframe;

  void set(Timeframe tf) => state = tf;
}

final pairTimeframeProvider = NotifierProvider.autoDispose.family<PairTimeframe, Timeframe, String>(
  PairTimeframe.new,
);

/// Whether this instrument's AI brief shows for the plan the person has.
class BriefAccess {
  const BriefAccess({required this.unlocked, required this.plan, this.usedOn});

  final bool unlocked;
  final PlanId plan;

  /// Free plan: the instrument today's brief went to.
  final String? usedOn;
}

/// The free plan's one brief a day ([BriefAllowance]).
class BriefAccessController extends Notifier<BriefAccess> {
  BriefAccessController(this.symbol);

  final String symbol;

  @override
  BriefAccess build() {
    final plan = ref.watch(entitlementProvider).plan;
    final allowance = ref.read(briefAllowanceRepositoryProvider).load();
    final now = clock.now();
    return BriefAccess(
      unlocked: allowance.allows(plan, symbol, now),
      plan: plan,
      usedOn: allowance.usedOn(now) ? allowance.symbol : null,
    );
  }

  /// The brief was opened: on the free plan this uses today's one, if unused.
  Future<void> open() async {
    if (state.plan != PlanId.free || !state.unlocked) return;
    final repo = ref.read(briefAllowanceRepositoryProvider);
    final now = clock.now();
    final before = repo.load();
    final after = before.use(symbol, now);
    if (identical(before, after)) return;
    await repo.save(after);
    if (!ref.mounted) return;
    state = BriefAccess(unlocked: true, plan: state.plan, usedOn: symbol);
  }
}

final briefAccessProvider = NotifierProvider.autoDispose.family<BriefAccessController, BriefAccess, String>(
  BriefAccessController.new,
);

/// The watchlist is profile.doji › instruments (what onboarding's markets step
/// picked). Adding or removing one saves the profile straight away.
class Watchlist extends Notifier<List<String>> {
  @override
  List<String> build() => ref.watch(marketsProfileProvider).instruments;

  bool contains(String symbol) => state.any((s) => s.toUpperCase() == symbol.toUpperCase());

  Future<void> toggle(String symbol) async {
    final repo = ref.read(onboardingRepositoryProvider);
    final profile = repo.loadProfile() ?? const ProfileDoji();
    final has = profile.instruments.any((s) => s.toUpperCase() == symbol.toUpperCase());
    final next = has
        ? profile.instruments.where((s) => s.toUpperCase() != symbol.toUpperCase()).toList()
        : [...profile.instruments, symbol];
    await repo.saveProfile(profile.withActive((a) => a.copyWith(instruments: next)));
    // Everything that read the old profile reads it again.
    invalidateAccountReaders(ref.container);
  }
}

final watchlistProvider = NotifierProvider.autoDispose<Watchlist, List<String>>(Watchlist.new);

/// Check-again reminders set this run, by instrument (UTC time). The OS
/// keeps the notification itself.
class BriefReminders extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => const {};

  Future<ReminderResult> remind(String symbol, CheckAgain check) async {
    final name = displaySymbol(symbol);
    final result = await ref
        .read(remindersProvider)
        .schedule(
          id: symbol.toUpperCase().hashCode & 0x7fffffff,
          at: check.at,
          title: 'check $name again',
          body: '${check.why}. your brief is measured against your strategy.',
        );
    if (result == ReminderResult.scheduled) state = {...state, symbol: check.at};
    return result;
  }
}

final briefRemindersProvider = NotifierProvider<BriefReminders, Map<String, DateTime>>(BriefReminders.new);
