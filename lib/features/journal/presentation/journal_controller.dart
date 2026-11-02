import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../markets/domain/currency.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../data/journal_repository.dart';
import '../domain/journal_stats.dart';
import '../domain/trade.dart';
import '../domain/trade_filter.dart';

/// The stored profile, read fresh: sign-in, sign-out and delete rewrite it.
final journalProfileProvider = Provider.autoDispose<ProfileDoji>(
  (ref) => ref.watch(onboardingRepositoryProvider).loadProfile() ?? const ProfileDoji(),
);

/// The account currency (USD, ZAR, EUR, GBP) results are shown in.
final accountCurrencyProvider = Provider.autoDispose<AccountCurrency>(
  (ref) =>
      AccountCurrency.fromCode(ref.watch(journalProfileProvider).accountCurrency) ?? AccountCurrency.fallback,
);

List<Trade> _newestFirst(Iterable<Trade> trades) =>
    trades.toList()..sort((a, b) => b.closedAt.compareTo(a.closedAt));

/// Every saved trade, newest first. Saved on this device after each change.
class JournalController extends Notifier<List<Trade>> {
  @override
  List<Trade> build() => _newestFirst(ref.watch(journalRepositoryProvider).load());

  static String newId() => const Uuid().v4();

  Future<void> add(Trade trade) => _set([...state, trade]);

  /// Saves the review on trade [id]; the grade follows from it.
  Future<void> review(String id, TradeReview review) =>
      _set([for (final t in state) t.id == id ? t.withReview(review, clock.now().toUtc()) : t]);

  Future<void> remove(String id) => _set([
    for (final t in state)
      if (t.id != id) t,
  ]);

  Future<void> _set(List<Trade> trades) {
    state = _newestFirst(trades);
    return ref.read(journalRepositoryProvider).save(state);
  }
}

final journalControllerProvider = NotifierProvider<JournalController, List<Trade>>(JournalController.new);

/// What the journal screens are showing: period, unit, filters and the
/// calendar day picked. In memory; the journal opens on this month, in R.
class JournalViewState {
  const JournalViewState({
    this.period = JournalPeriod.month,
    this.unit = ResultUnit.r,
    this.filter = const TradeFilter(),
    this.selectedDay,
  });

  final JournalPeriod period;
  final ResultUnit unit;
  final TradeFilter filter;

  /// Day of the current month picked on the calendar.
  final int? selectedDay;

  JournalViewState copyWith({
    JournalPeriod? period,
    ResultUnit? unit,
    TradeFilter? filter,
    Object? selectedDay = _keep,
  }) => JournalViewState(
    period: period ?? this.period,
    unit: unit ?? this.unit,
    filter: filter ?? this.filter,
    selectedDay: identical(selectedDay, _keep) ? this.selectedDay : selectedDay as int?,
  );
}

const Object _keep = Object();

/// The trades taken on the active account (Home, the brief, the coach, the rail).
final activeAccountTradesProvider = Provider.autoDispose<List<Trade>>((ref) {
  final id = ref.watch(journalProfileProvider.select((p) => p.activeAccount?.id));
  return [
    for (final t in ref.watch(journalControllerProvider))
      if (t.accountId == id) t,
  ];
});

class JournalView extends Notifier<JournalViewState> {
  /// Opens on the active account; clearing the filters shows all accounts.
  @override
  JournalViewState build() {
    final id = ref.read(journalProfileProvider).activeAccount?.id;
    return JournalViewState(
      filter: TradeFilter({
        if (id != null) FilterGroup.account: {id},
      }),
    );
  }

  void setPeriod(JournalPeriod p) => state = state.copyWith(period: p, selectedDay: null);
  void setUnit(ResultUnit u) => state = state.copyWith(unit: u);
  void toggleFilter(FilterGroup g, String value) =>
      state = state.copyWith(filter: state.filter.toggled(g, value));
  void clearFilter() => state = state.copyWith(filter: const TradeFilter());
  void selectDay(int? day) => state = state.copyWith(selectedDay: state.selectedDay == day ? null : day);
}

final journalViewProvider = NotifierProvider<JournalView, JournalViewState>(JournalView.new);

/// Trades inside the chosen period, newest first.
final periodTradesProvider = Provider.autoDispose<List<Trade>>((ref) {
  final account = ref.watch(journalViewProvider.select((v) => v.filter.accountOnly));
  final trades = account.apply(ref.watch(journalControllerProvider));
  final period = ref.watch(journalViewProvider.select((v) => v.period));
  final now = clock.now();
  return [
    for (final t in trades)
      if (period.contains(t.closedAt, now)) t,
  ];
});

/// Stats and curves for the chosen period and unit.
final journalStatsProvider = Provider.autoDispose<JournalStats>((ref) {
  final unit = ref.watch(journalViewProvider.select((v) => v.unit));
  return JournalStats.of(ref.watch(periodTradesProvider), unit);
});
