import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../journal/presentation/journal_controller.dart';
import '../../onboarding/data/voice_input.dart';
import '../../plans/domain/plans.dart';
import '../../plans/presentation/plans_controller.dart';
import '../data/fake_brief_chat.dart';
import '../domain/pair_brief.dart';
import 'pair_detail_controller.dart';

/// Why the brief chat is typed rather than spoken.
enum ChatVoice {
  /// Voice is on.
  available,

  /// The plan has no voice coach (free and basic).
  plan,

  /// No dictation on this device (Windows for now).
  device,

  /// The microphone or speech permission was refused.
  microphone,
}

class BriefChatState {
  const BriefChatState({
    required this.voice,
    this.turns = const [],
    this.thinking = false,
    this.listening = false,
    this.heard = '',
    this.missedWords = false,
  });

  final ChatVoice voice;

  /// Oldest first.
  final List<BriefTurn> turns;

  /// A question was sent and the answer is not here yet.
  final bool thinking;
  final bool listening;

  /// What the mic has heard so far.
  final String heard;

  /// The mic closed without catching any words.
  final bool missedWords;

  BriefChatState copyWith({
    ChatVoice? voice,
    List<BriefTurn>? turns,
    bool? thinking,
    bool? listening,
    String? heard,
    bool? missedWords,
  }) => BriefChatState(
    voice: voice ?? this.voice,
    turns: turns ?? this.turns,
    thinking: thinking ?? this.thinking,
    listening: listening ?? this.listening,
    heard: heard ?? this.heard,
    missedWords: missedWords ?? this.missedWords,
  );
}

/// The chat sheet behind "ask about this brief", scoped to one instrument's
/// brief. Voice follows the coach's rule: with the voice coach (pro trader,
/// elite prop) and dictation on the device, the mic dictates the question;
/// otherwise it is typed. Auto-disposed with the sheet, which closes the mic.
class BriefChatController extends Notifier<BriefChatState> {
  BriefChatController(this.symbol);

  final String symbol;

  /// Bumped whenever listening starts or stops, so a late speech callback
  /// never acts on a newer one.
  int _listen = 0;
  bool _prepared = false;

  @override
  BriefChatState build() {
    final voiceIn = ref.read(voiceInputProvider);
    ref.onDispose(voiceIn.stop);
    final voice = !voiceIn.mightBeAvailable
        ? ChatVoice.device
        : includesVoiceCoach(ref.read(entitlementProvider).plan)
        ? ChatVoice.available
        : ChatVoice.plan;
    return BriefChatState(voice: voice);
  }

  /// Sends [text] and waits for the answer.
  Future<void> send(String text) async {
    final words = text.trim();
    final brief = ref.read(pairBriefProvider(symbol)).value;
    if (words.isEmpty || state.thinking || brief == null) return;
    final history = state.turns;
    state = state.copyWith(
      turns: [
        ...history,
        BriefTurn(fromYou: true, text: words),
      ],
      thinking: true,
      missedWords: false,
    );
    final request = BriefRequest(
      symbol: symbol,
      profile: ref.read(marketsProfileProvider),
      trades: ref.read(activeAccountTradesProvider),
      now: clock.now(),
    );
    final answer = await ref.read(briefChatProvider).reply(brief, request, history, words);
    if (!ref.mounted) return;
    state = state.copyWith(
      turns: [
        ...state.turns,
        BriefTurn(fromYou: false, text: answer),
      ],
      thinking: false,
    );
  }

  /// The mic button: opens the mic, or, while it is open, sends what it heard.
  Future<void> toggleMic() async {
    if (state.voice != ChatVoice.available || state.thinking) return;
    if (state.listening) return _finish();
    final gen = ++_listen;
    state = state.copyWith(listening: true, heard: '', missedWords: false);
    final voice = ref.read(voiceInputProvider);
    if (!_prepared) {
      final availability = await voice.prepare();
      if (!ref.mounted) return;
      if (availability != VoiceAvailability.available) {
        _listen++;
        state = state.copyWith(
          listening: false,
          voice: availability == VoiceAvailability.permissionDenied ? ChatVoice.microphone : ChatVoice.device,
        );
        return;
      }
      _prepared = true;
    }
    if (gen != _listen || !state.listening) return;
    await voice.start(
      onResult: (words, _) {
        if (ref.mounted && gen == _listen) state = state.copyWith(heard: words);
      },
      // A pause in speech sends, as on the coach.
      onStopped: () {
        if (ref.mounted && gen == _listen && state.listening) _finish();
      },
    );
  }

  Future<void> _finish() async {
    _listen++;
    final words = state.heard.trim();
    state = state.copyWith(listening: false, heard: '');
    await ref.read(voiceInputProvider).stop();
    if (!ref.mounted) return;
    if (words.isEmpty) {
      state = state.copyWith(missedWords: true);
      return;
    }
    await send(words);
  }

  /// Closes the mic before the sheet goes.
  Future<void> end() async {
    _listen++;
    if (state.listening) state = state.copyWith(listening: false, heard: '');
    await ref.read(voiceInputProvider).stop();
  }
}

final briefChatControllerProvider = NotifierProvider.autoDispose
    .family<BriefChatController, BriefChatState, String>(BriefChatController.new);
