import '../data/fake_coach.dart';
import 'coach.dart';

/// Words that mean the trader is in distress, not only tilted: the crisis
/// words plus "i've lost everything"-type lines. The session then shows the
/// SADAG line first, a calm layout and the panic flow.
final RegExp _distress = RegExp(
  r'\b(kill myself|suicid\w*|want to die|wanna die|end my life|hurt myself|self[- ]?harm\w*|'
  r"don'?t want to (live|be here)|no reason to live|can'?t (do|take) (this|it) any ?more|"
  r"lost everything|blew (my|the) (whole )?account|hopeless|i give up|ruined my life|i'?m done with (it|life))\b",
);

bool isDistress(String message) => _distress.hasMatch(message.toLowerCase());

/// After "end": what the session was about (the trader's own lines, up to
/// three) and one focus for the next trade, picked from what they raised.
class SessionSummary {
  const SessionSummary({required this.minutes, required this.topics, required this.focus});

  final int minutes;
  final List<String> topics;
  final String focus;

  /// Focus lines, by what the trader raised first (in [CoachIntent] order).
  static const Map<CoachIntent, String> focusFor = {
    CoachIntent.crisis: 'talk to someone you trust today. the trading can wait.',
    CoachIntent.call: 'before your next entry, read your own rules out loud.',
    CoachIntent.done: 'close your day on home and write one line about it.',
    CoachIntent.revenge: 'after a loss, wait one full candle before you look at the next entry.',
    CoachIntent.sizing: 'keep the next trade at your planned risk.',
    CoachIntent.stop: 'set the stop before the entry, then leave it where it is.',
    CoachIntent.hesitation: 'before your next entry, check your conditions one by one.',
    CoachIntent.urge: 'wait for your entry rule, not the move.',
    CoachIntent.feeling: 'give the feeling a number from 1 to 10 before you decide anything.',
    CoachIntent.another: 'count your trades against your max before the next one.',
    CoachIntent.other: 'before your next entry, read your rules out loud.',
  };

  factory SessionSummary.of(List<CoachTurn> turns, {required DateTime startedAt, required DateTime endedAt}) {
    final yours = [
      for (final t in turns)
        if (t.speaker == CoachSpeaker.you) t.text.trim(),
    ];
    final intents = yours.map(FakeCoach.intentOf).toSet();
    final first = CoachIntent.values.firstWhere(intents.contains, orElse: () => CoachIntent.other);
    final secs = endedAt.difference(startedAt).inSeconds;
    return SessionSummary(
      minutes: secs <= 0 ? 1 : (secs / 60).ceil(),
      topics: [for (final y in yours.take(3)) y.length > 90 ? '${y.substring(0, 89)}…' : y],
      focus: focusFor[first]!,
    );
  }
}
