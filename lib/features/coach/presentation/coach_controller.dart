import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/voice_orb.dart';
import '../../home/domain/home_models.dart';
import '../../home/presentation/home_controller.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/data/voice_input.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../plans/domain/plans.dart';
import '../../plans/presentation/plans_controller.dart';
import '../data/coach_session_repository.dart';
import '../data/voice_minutes_repository.dart';
import '../data/fake_coach.dart';
import '../domain/coach.dart';
import '../domain/coach_session.dart';
import '../domain/session_summary.dart';

/// How the trader talks to the coach in this session.
enum CoachInputMode { voice, text }

/// Why a session is text rather than voice.
enum TextReason {
  /// It is voice.
  none,

  /// No dictation on this device (Windows for now).
  device,

  /// The plan has no voice coach (free and basic).
  plan,

  /// The microphone or speech permission was refused.
  microphone,

  /// This month's voice minutes are used (pro trader).
  minutes,
}

/// One coach session, from opening the screen to closing it.
class CoachState {
  const CoachState({
    required this.id,
    required this.startedAt,
    required this.voice,
    required this.mode,
    this.textReason = TextReason.none,
    this.turns = const [],
    this.orb = VoiceOrbState.idle,
    this.heard = '',
    this.tapToSend = false,
    this.thinking = false,
    this.savedTurns = 0,
    this.missedWords = false,
    this.minutesLeft,
    this.distress = false,
  });

  final String id;
  final DateTime startedAt;
  final CoachVoice voice;
  final CoachInputMode mode;
  final TextReason textReason;

  /// Oldest first.
  final List<CoachTurn> turns;
  final VoiceOrbState orb;

  /// What the mic has heard so far while listening.
  final String heard;

  /// The mic was opened with a tap (or from the orb), so the next tap sends.
  final bool tapToSend;

  /// A line was sent and the coach's reply is not here yet.
  final bool thinking;

  /// [turns] length at the last save; 0 = never saved.
  final int savedTurns;

  /// The mic closed without catching any words.
  final bool missedWords;

  /// Voice minutes left this month; null when the plan does not count them.
  final int? minutesLeft;

  /// The trader said something heavy: SADAG first, a calm layout, the panic flow.
  final bool distress;

  /// Voice is possible here and text was the trader's choice.
  bool get canSwitchToVoice => mode == CoachInputMode.text && textReason == TextReason.none;

  bool get hasYou => turns.any((t) => t.speaker == CoachSpeaker.you);
  bool get saved => savedTurns > 0 && savedTurns == turns.length;

  /// Something the trader said that is not saved yet: closing asks first.
  bool get unsaved => hasYou && !saved;

  CoachTurn? get lastYou => turns.lastWhereOrNull((t) => t.speaker == CoachSpeaker.you);
  CoachTurn? get lastCoach => turns.lastWhereOrNull((t) => t.speaker == CoachSpeaker.coach);

  CoachState copyWith({
    CoachVoice? voice,
    CoachInputMode? mode,
    TextReason? textReason,
    List<CoachTurn>? turns,
    VoiceOrbState? orb,
    String? heard,
    bool? tapToSend,
    bool? thinking,
    int? savedTurns,
    bool? missedWords,
    int? minutesLeft,
    bool? distress,
  }) => CoachState(
    id: id,
    startedAt: startedAt,
    voice: voice ?? this.voice,
    mode: mode ?? this.mode,
    textReason: textReason ?? this.textReason,
    turns: turns ?? this.turns,
    orb: orb ?? this.orb,
    heard: heard ?? this.heard,
    tapToSend: tapToSend ?? this.tapToSend,
    thinking: thinking ?? this.thinking,
    savedTurns: savedTurns ?? this.savedTurns,
    missedWords: missedWords ?? this.missedWords,
    minutesLeft: minutesLeft ?? this.minutesLeft,
    distress: distress ?? this.distress,
  );
}

extension<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
}

/// Runs a session: push-to-talk through [VoiceInput], typed lines, the
/// [Coach]'s replies, the voice choice and saving. Auto-disposed with the
/// screen, which also closes the mic.
class CoachController extends Notifier<CoachState> {
  /// Bumped whenever listening starts or stops, so a late speech callback
  /// never acts on a newer press.
  int _listen = 0;
  bool _prepared = false;

  /// When the mic opened, for the voice minutes.
  DateTime? _listenFrom;
  late CoachContext _context;

  @override
  CoachState build() {
    final voiceIn = ref.read(voiceInputProvider);
    ref.onDispose(voiceIn.stop);
    final profile = ref.read(onboardingRepositoryProvider).loadProfile() ?? const ProfileDoji();
    _context = CoachContext.from(profile, trades: ref.read(activeAccountTradesProvider), now: clock.now());
    final plan = ref.read(entitlementProvider).plan;
    final left = voiceMinutesLeft(plan, ref.read(voiceMinutesRepositoryProvider).usedSeconds(clock.now()));
    final reason = !voiceIn.mightBeAvailable
        ? TextReason.device
        : !includesVoiceCoach(plan)
        ? TextReason.plan
        : left == 0
        ? TextReason.minutes
        : TextReason.none;
    return CoachState(
      id: const Uuid().v4(),
      startedAt: clock.now(),
      voice: CoachVoice.of(profile.coach?.voice),
      mode: reason == TextReason.none ? CoachInputMode.voice : CoachInputMode.text,
      textReason: reason,
      minutesLeft: left,
    );
  }

  /// Opens the session. [listen]: opened by a long-press on the coach orb,
  /// so the mic opens straight away (tap to send) instead of the opener.
  Future<void> start({bool listen = false}) async {
    if (listen && state.mode == CoachInputMode.voice) return press(tap: true);
    state = state.copyWith(thinking: true);
    final line = await ref.read(coachProvider).opener(_context);
    if (!ref.mounted) return;
    _addCoach(line);
  }

  /// Push-to-talk went down. Opens the mic, interrupting the coach if it is
  /// speaking; a second press after a tap sends. [tap]: opened by a screen
  /// reader, the keyboard or the orb, so the mic stays open until the next one.
  Future<void> press({bool tap = false}) async {
    if (state.mode != CoachInputMode.voice || state.thinking) return;
    if (state.orb == VoiceOrbState.listening) {
      if (state.tapToSend) await _finishListening();
      return;
    }
    final gen = ++_listen;
    state = state.copyWith(orb: VoiceOrbState.listening, heard: '', tapToSend: tap, missedWords: false);
    final voice = ref.read(voiceInputProvider);
    if (!_prepared) {
      final availability = await voice.prepare();
      if (!ref.mounted) return;
      if (availability != VoiceAvailability.available) {
        _listen++;
        state = state.copyWith(
          orb: VoiceOrbState.idle,
          mode: CoachInputMode.text,
          textReason: availability == VoiceAvailability.permissionDenied
              ? TextReason.microphone
              : TextReason.device,
        );
        return;
      }
      _prepared = true;
    }
    // Released (or closed) while the permission prompt was up.
    if (gen != _listen || state.orb != VoiceOrbState.listening) return;
    _listenFrom = clock.now();
    await voice.start(
      onResult: (words, _) {
        if (ref.mounted && gen == _listen) state = state.copyWith(heard: words);
      },
      onStopped: () {
        if (ref.mounted && gen == _listen && state.orb == VoiceOrbState.listening) _finishListening();
      },
    );
  }

  /// Push-to-talk came up. [held]: down long enough to be a hold, so this
  /// sends; a quick tap leaves the mic open until the next tap.
  Future<void> release({required bool held}) async {
    if (state.orb != VoiceOrbState.listening) return;
    if (held) return _finishListening();
    state = state.copyWith(tapToSend: true);
  }

  Future<void> _finishListening() async {
    _listen++;
    final words = state.heard.trim();
    state = state.copyWith(orb: VoiceOrbState.idle, tapToSend: false, heard: '');
    await ref.read(voiceInputProvider).stop();
    await _countVoice();
    if (!ref.mounted) return;
    if (words.isEmpty) {
      state = state.copyWith(missedWords: true);
      return;
    }
    await send(words);
  }

  /// Sends [text] (typed, or what the mic heard) and waits for the reply.
  Future<void> send(String text) async {
    final words = text.trim();
    if (words.isEmpty || state.thinking) return;
    final history = state.turns;
    state = state.copyWith(
      turns: [
        ...history,
        CoachTurn(speaker: CoachSpeaker.you, text: words, at: clock.now()),
      ],
      orb: VoiceOrbState.idle,
      thinking: true,
      missedWords: false,
      distress: state.distress || isDistress(words),
    );
    final reply = await ref.read(coachProvider).reply(_context, history, words);
    if (!ref.mounted) return;
    _addCoach(reply);
    // "try the coach for 30 seconds" on Home's day-zero checklist.
    ref.read(homeControllerProvider.notifier).completeTask(SetupTask.coach);
  }

  void _addCoach(String line) => state = state.copyWith(
    turns: [
      ...state.turns,
      CoachTurn(speaker: CoachSpeaker.coach, text: line, at: clock.now()),
    ],
    thinking: false,
    orb: VoiceOrbState.speaking,
  );

  /// Counts the time the mic was open against this month's voice minutes;
  /// at 0 the session moves to text.
  Future<void> _countVoice() async {
    final from = _listenFrom;
    _listenFrom = null;
    if (from == null || state.minutesLeft == null) return;
    final now = clock.now();
    final used = await ref.read(voiceMinutesRepositoryProvider).add(now.difference(from), now);
    if (!ref.mounted) return;
    final left = voiceMinutesLeft(ref.read(entitlementProvider).plan, used);
    if (left == null) return;
    state = left == 0
        ? state.copyWith(minutesLeft: 0, mode: CoachInputMode.text, textReason: TextReason.minutes)
        : state.copyWith(minutesLeft: left);
  }

  /// Voice or text, when voice is possible (text mode is for public places).
  void toggleMode() {
    if (state.textReason != TextReason.none || state.orb == VoiceOrbState.listening) return;
    state = state.copyWith(
      mode: state.mode == CoachInputMode.voice ? CoachInputMode.text : CoachInputMode.voice,
    );
  }

  /// "keep talking" on the distress card.
  void keepTalking() => state = state.copyWith(distress: false);

  /// The coach finished its line (typing done; later, the audio).
  void doneSpeaking() {
    if (state.orb == VoiceOrbState.speaking) state = state.copyWith(orb: VoiceOrbState.idle);
  }

  /// The voice for this session and the next (profile.doji › coach.voice).
  Future<void> setVoice(CoachVoice voice) async {
    if (voice == state.voice) return;
    state = state.copyWith(voice: voice);
    final repo = ref.read(onboardingRepositoryProvider);
    final profile = repo.loadProfile();
    if (profile == null) return;
    await repo.saveProfile(
      profile.copyWith(coach: (profile.coach ?? const CoachProfile()).copyWith(voice: voice.value)),
    );
  }

  /// Keeps the transcript on this device. Saving again after more turns
  /// replaces the saved copy.
  Future<void> save() async {
    if (!state.hasYou) return;
    final turns = state.turns;
    await ref
        .read(coachSessionRepositoryProvider)
        .save(
          CoachSession(
            id: state.id,
            startedAt: state.startedAt,
            voice: state.voice,
            turns: turns,
            savedAt: clock.now(),
          ),
        );
    if (!ref.mounted) return;
    ref.invalidate(savedCoachSessionsProvider);
    state = state.copyWith(savedTurns: turns.length);
  }

  /// Closes the mic and quiets the coach before the screen goes.
  Future<void> end() async {
    _listen++;
    if (state.orb != VoiceOrbState.idle) {
      state = state.copyWith(orb: VoiceOrbState.idle, tapToSend: false, heard: '');
    }
    await ref.read(voiceInputProvider).stop();
    await _countVoice();
  }
}

final coachControllerProvider = NotifierProvider.autoDispose<CoachController, CoachState>(
  CoachController.new,
);
