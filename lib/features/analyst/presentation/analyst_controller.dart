import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../backtest/data/backtest_repository.dart';
import '../../chart/data/chart_note_repository.dart';
import '../../gym/data/gym_repository.dart';
import '../../home/presentation/home_controller.dart';
import '../../journal/domain/trade.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../journal/presentation/journal_screen.dart' show kInsightsFromTrades;
import '../../markets/domain/pair_brief.dart';
import '../../markets/presentation/brief_chat_controller.dart';
import '../../onboarding/domain/sessions.dart';
import '../data/analyst_repository.dart';
import '../data/fake_analyst.dart';
import '../domain/aggregates.dart';
import '../domain/analyst.dart';

/// TODO(backend): SupabaseAnalyst (`ai-analyst`) when Supabase started, with
/// [FakeAnalyst] as its fallback (design/analyst-plan.md).
final analystProvider = Provider<Analyst>((ref) => const FakeAnalyst());

/// Local Monday 00:00 of [t]'s week.
DateTime weekStartOf(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day - (l.weekday - 1));
}

/// The trader's notes and files about their strategy, all accounts.
class SourcesController extends Notifier<List<AccountSource>> {
  @override
  List<AccountSource> build() => ref.watch(analystRepositoryProvider).loadSources();

  Future<void> addNote(String accountId, String title, String text) => _set([
    ...state,
    AccountSource(
      id: const Uuid().v4(),
      accountId: accountId,
      title: title.trim().isEmpty ? 'note' : title.trim(),
      text: text.trim(),
      addedAt: clock.now().toUtc(),
    ),
  ]);

  Future<void> addFile(String accountId, String fileName) => _set([
    ...state,
    AccountSource(
      id: const Uuid().v4(),
      accountId: accountId,
      title: fileName,
      fileName: fileName,
      addedAt: clock.now().toUtc(),
    ),
  ]);

  Future<void> remove(String id) => _set([
    for (final s in state)
      if (s.id != id) s,
  ]);

  Future<void> _set(List<AccountSource> sources) {
    state = sources;
    return ref.read(analystRepositoryProvider).saveSources(state);
  }
}

final sourcesProvider = NotifierProvider<SourcesController, List<AccountSource>>(SourcesController.new);

/// The words of an account's strategy and its note sources, for matching
/// reasons (the analyst and the co-pilot). Files are not read on the device.
String strategyWordsWithSources(String? strategy, Iterable<AccountSource> sources) => [
  ?strategy,
  for (final s in sources)
    if (!s.isFile && s.text.isNotEmpty) s.text,
].join('\n');

/// The active account's facts, every figure counted on the device.
final analystFactsProvider = Provider.autoDispose<AnalystFacts>((ref) {
  final profile = ref.watch(journalProfileProvider);
  final id = profile.activeAccount?.id;
  return AnalystFacts.from(
    trades: ref.watch(activeAccountTradesProvider),
    notes: [
      for (final n in ref.watch(chartNotesProvider))
        if (n.accountId == id) n,
    ],
    backtests: [
      for (final s in ref.watch(backtestSessionsProvider))
        if (s.accountId == id) s,
    ],
    gym: [
      for (final e in ref.watch(gymProvider))
        if (e.accountId == id) e,
    ],
    sessions: [for (final k in profile.sessions) ?TradingSession.fromKey(k)],
    strategyWords: strategyWordsWithSources(profile.strategy?.rawText, [
      for (final s in ref.watch(sourcesProvider))
        if (s.accountId == id) s,
    ]),
    maxTrades: profile.rules?.maxTradesPerDay,
    streak: ref.watch(drillStreakProvider),
    payout: ref.watch(homeSnapshotProvider.select((s) => s.payout)),
    now: clock.now(),
  );
});

/// Weekly reviews, all accounts, on this device.
class ReviewsController extends Notifier<List<WeeklyReview>> {
  @override
  List<WeeklyReview> build() => ref.watch(analystRepositoryProvider).loadReviews();

  /// Writes last week's review for [accountId] once, when the account has
  /// [kInsightsFromTrades] trades and none is stored for that week.
  Future<void> ensureLastWeek(String accountId, List<Trade> trades) async {
    if (trades.length < kInsightsFromTrades) return;
    final start = weekStartOf(clock.now()).subtract(const Duration(days: 7));
    final start0 = DateTime(start.year, start.month, start.day);
    if (state.any((r) => r.accountId == accountId && r.weekStart == start0)) return;
    final end = DateTime(start0.year, start0.month, start0.day + 7);
    final week = [
      for (final t in trades)
        if (!t.closedAt.toLocal().isBefore(start0) && t.closedAt.toLocal().isBefore(end)) t,
    ];
    final profile = ref.read(journalProfileProvider);
    final facts = AnalystFacts.from(trades: week, maxTrades: profile.rules?.maxTradesPerDay, now: end);
    final review = await ref
        .read(analystProvider)
        .weeklyReview(accountId: accountId, weekStart: start0, week: facts);
    if (!ref.mounted || state.any((r) => r.accountId == accountId && r.weekStart == start0)) return;
    await _set([...state, review]);
  }

  Future<void> accept(WeeklyReview review) => _set([
    for (final r in state)
      r.accountId == review.accountId && r.weekStart == review.weekStart ? r.accept() : r,
  ]);

  Future<void> _set(List<WeeklyReview> reviews) {
    state = reviews;
    return ref.read(analystRepositoryProvider).saveReviews(state);
  }
}

final reviewsProvider = NotifierProvider<ReviewsController, List<WeeklyReview>>(ReviewsController.new);

/// The active account's latest review (newest week first), if any.
final latestReviewProvider = Provider.autoDispose<WeeklyReview?>((ref) {
  final id = ref.watch(journalProfileProvider.select((p) => p.activeAccount?.id));
  final mine = [
    for (final r in ref.watch(reviewsProvider))
      if (r.accountId == id) r,
  ]..sort((a, b) => b.weekStart.compareTo(a.weekStart));
  return mine.firstOrNull;
});

/// This week's focus rule: last week's review, accepted, on the active account.
final focusRuleProvider = Provider.autoDispose<String?>((ref) {
  final r = ref.watch(latestReviewProvider);
  if (r == null || !r.accepted) return null;
  final thisWeek = weekStartOf(clock.now());
  return DateTime(r.weekStart.year, r.weekStart.month, r.weekStart.day + 7) == thisWeek ? r.focusRule : null;
});

/// "ask the analyst": the brief chat's sheet over the trader's own numbers.
class AnalystChatController extends ChatController {
  @override
  Future<String> answer(List<BriefTurn> history, String words) =>
      ref.read(analystProvider).reply(ref.read(analystFactsProvider), history, words);
}

final analystChatControllerProvider = NotifierProvider.autoDispose<AnalystChatController, BriefChatState>(
  AnalystChatController.new,
);
