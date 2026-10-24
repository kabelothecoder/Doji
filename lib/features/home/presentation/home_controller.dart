import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../journal/presentation/journal_controller.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../domain/home_models.dart';

/// Auto-disposed: sign-in, sign-out and delete rewrite the stored profile.
final homeProfileProvider = Provider.autoDispose<ProfileDoji>(
  (ref) => ref.watch(onboardingRepositoryProvider).loadProfile() ?? const ProfileDoji(),
);

/// Before or after a trade (post-trade emotion check).
enum EmotionWhen { before, after }

class HomeState {
  const HomeState({
    this.doneTasks = const {},
    this.mood,
    this.openDoneAt,
    this.dayClosed = false,
    this.lastEmotion,
  });

  final Set<SetupTask> doneTasks;

  /// Mood picked on The Open; saved with today's trades.
  final String? mood;
  final DateTime? openDoneAt;
  final bool dayClosed;

  /// "before · 6/10" after the post-trade sheet, shown on the rail.
  final String? lastEmotion;

  bool get openDone => openDoneAt != null;
  bool get setupComplete => doneTasks.length == SetupTask.values.length;

  HomeState copyWith({
    Set<SetupTask>? doneTasks,
    Object? mood = _keep,
    DateTime? openDoneAt,
    bool? dayClosed,
    String? lastEmotion,
  }) => HomeState(
    doneTasks: doneTasks ?? this.doneTasks,
    mood: identical(mood, _keep) ? this.mood : mood as String?,
    openDoneAt: openDoneAt ?? this.openDoneAt,
    dayClosed: dayClosed ?? this.dayClosed,
    lastEmotion: lastEmotion ?? this.lastEmotion,
  );
}

const Object _keep = Object();

/// In-memory for now. TODO(next-slice): persist the open, mood, close-day
/// reflection and mindset score (shared_preferences, then Supabase), and
/// reset the day at local midnight.
class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeState();

  void toggleTask(SetupTask task) {
    final next = {...state.doneTasks};
    if (!next.add(task)) next.remove(task);
    state = state.copyWith(doneTasks: next);
  }

  /// Ticks [task] when the trader did it elsewhere (a first coach reply).
  void completeTask(SetupTask task) {
    if (!state.doneTasks.contains(task)) state = state.copyWith(doneTasks: {...state.doneTasks, task});
  }

  void pickMood(String mood) => state = state.copyWith(mood: mood);

  void startOpen() => state = state.copyWith(mood: null);

  void completeOpen() => state = state.copyWith(openDoneAt: clock.now());

  /// TODO(next-slice): save [wentToPlan], [doDifferently] and [mindset].
  void closeDay({String wentToPlan = '', String doDifferently = '', int mindset = 7}) =>
      state = state.copyWith(dayClosed: true);

  /// TODO(next-slice): save against the latest trade in the journal (the review
  /// sheet already stores the emotion before and after for a reviewed trade).
  void logEmotion(EmotionWhen when, int intensity) =>
      state = state.copyWith(lastEmotion: '${when.name} the trade · $intensity/10');
}

final homeControllerProvider = NotifierProvider<HomeController, HomeState>(HomeController.new);

/// The day as the screens read it: trades taken, loss, tilt and the prop
/// drawdown come from the journal.
final homeSnapshotProvider = Provider.autoDispose<HomeSnapshot>((ref) {
  final profile = ref.watch(homeProfileProvider);
  final trades = ref.watch(journalControllerProvider);
  return HomeSnapshot.fromJournal(profile, trades: trades, now: clock.now().toUtc());
});

/// True on the day the setup was finished: the checklist day.
bool isDayZero(ProfileDoji p) {
  final done = p.completedAt?.toLocal();
  if (done == null) return false;
  final now = clock.now();
  return done.year == now.year && done.month == now.month && done.day == now.day;
}

bool isEvening() => clock.now().hour >= eveningFromHour;
