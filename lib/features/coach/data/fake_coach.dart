import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/coach.dart';

/// What the trader's message is about, as far as the fake coach can tell.
/// Checked in declaration order: the first match wins.
enum CoachIntent {
  /// Self-harm or wanting to die: the helpline, before anything about trading.
  crisis,

  /// Asking what the market will do or which way to trade.
  call,

  /// Stopping for the day.
  done,

  /// Wanting the losses back.
  revenge,

  /// Bigger size than the plan.
  sizing,

  /// Moving or removing the stop.
  stop,

  /// Hesitating on a setup.
  hesitation,

  /// The urge to get in now (fomo, chasing a move).
  urge,

  /// A feeling, named.
  feeling,

  /// Another trade.
  another,

  other,
}

/// Keyword-matching stand-in for the real coach. Offline and deterministic,
/// good enough to demo the session and keep it local-first. Every reply
/// points the trader back to their own plan and rules, using only what
/// [CoachContext] knows; it never says what the market will do.
///
/// TODO(next-slice): `SupabaseCoach`, which streams the reply from a `coach`
/// Edge Function (the LLM, with profile.doji and today's journal as context,
/// the same no-calls rule, the same crisis handling), then speaks it in the
/// chosen voice. Keep this class as the offline fallback.
class FakeCoach implements Coach {
  const FakeCoach({this.latency = const Duration(milliseconds: 700)});

  /// Simulated model latency, so the "thinking" state is real.
  final Duration latency;

  static final _patterns = <CoachIntent, RegExp>{
    CoachIntent.crisis: RegExp(
      r'\b(kill myself|suicid\w*|want to die|wanna die|end my life|hurt myself|self[- ]?harm\w*|'
      r"don'?t want to (live|be here)|no reason to live)\b",
    ),
    CoachIntent.call: RegExp(
      r'\b(should i (go )?(long|short|enter)|long or short|which way|going (up|down)|'
      r'will it (go|break|drop|rise|fall|bounce)|where (is it|will it) go\w*|what do you think it)\b',
    ),
    CoachIntent.done: RegExp(
      r"\b(done for (the|to)day|stop(ping)? for (the|to)day|close (my|the) day|i'?m done|call it a day|"
      r'finished for (the|to)day)\b',
    ),
    CoachIntent.revenge: RegExp(
      r'\b(win it back|make it back|get it back|earn it back|revenge|recover\w*|back to (even|breakeven)|'
      r'break ?even)\b',
    ),
    CoachIntent.sizing: RegExp(
      r'\b(double (up|down|my|the)|size up|sizing up|bigger (size|lot|position)|more lots?|all in|go big|'
      r'max size|increase (my |the )?(size|lot|risk))\b',
    ),
    CoachIntent.stop: RegExp(r'\b(move (my |the )?(stop|sl)|widen|stop ?loss|remove (my |the )?(stop|sl))\b'),
    CoachIntent.hesitation: RegExp(
      r"\b(hesitat\w*|can'?t pull the trigger|scared to (enter|take)|frozen|second.guess\w*)\b",
    ),
    CoachIntent.urge: RegExp(
      r"\b(get in|want in|jump in|chas(e|ing)|miss(ing)? (it|out|the move)|fomo|it'?s running|runs|"
      r'run away|the break|enter now|before it)\b',
    ),
    CoachIntent.feeling: RegExp(
      r'\b(angry|furious|frustrated|anxious|scared|nervous|stressed|tilt(ed)?|upset|bored|panic\w*|'
      r'afraid|annoyed)\b',
    ),
    CoachIntent.another: RegExp(r'\b(another (trade|one|entry)|one more|next trade|trade again|go again)\b'),
  };

  static CoachIntent intentOf(String message) {
    final t = message.toLowerCase();
    for (final intent in CoachIntent.values) {
      if (_patterns[intent]?.hasMatch(t) ?? false) return intent;
    }
    return CoachIntent.other;
  }

  @override
  Future<String> opener(CoachContext context) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency ~/ 2);
    return openerFor(context);
  }

  @override
  Future<String> reply(CoachContext context, List<CoachTurn> history, String message) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final replies = history.where((t) => t.speaker == CoachSpeaker.coach).length;
    return replyFor(intentOf(message), context, turn: replies);
  }

  static String openerFor(CoachContext c) {
    final max = c.maxTradesPerDay;
    if (c.lossStreak >= 2) {
      return '${c.lossStreak} losses in a row today. before anything else, talk it through. what is pulling at you?';
    }
    if (max != null && c.tradesToday >= max) {
      return "that's ${c.tradesToday} of $max trades today, so the plan is done for today. what's on your mind?";
    }
    final who = c.name == null ? '' : '${c.name!.toLowerCase()}, ';
    return "${who}what's on your mind before the next trade?";
  }

  /// [turn] is how many times the coach has already replied this session; it
  /// only rotates the open questions so the coach doesn't repeat itself.
  static String replyFor(CoachIntent intent, CoachContext c, {int turn = 0}) {
    final risk = c.riskPerTradePct;
    final max = c.maxTradesPerDay;
    final limit = c.dailyLossLimitPct;
    switch (intent) {
      case CoachIntent.crisis:
        return "that matters more than any trade. i'm a trading coach, not a counsellor, so please talk to "
            'someone now: SADAG on 0800 567 567, any hour. you can come back to this after.';
      case CoachIntent.call:
        return "i don't call the market, and no one honest can. what does your plan say about this one?";
      case CoachIntent.done:
        return 'good call. stopping on your terms is the plan working. close your day on home and write one '
            'line about it.';
      case CoachIntent.revenge:
        final streak = switch (c.lossStreak) {
          0 => '',
          1 => 'one loss today. ',
          final n => '$n losses in a row today. ',
        };
        final room = limit == null
            ? ''
            : c.lossTodayPct > 0
            ? " your limit is ${_n(limit)}% today and you're at ${_n(c.lossTodayPct)}%."
            : ' your limit is ${_n(limit)}% today.';
        return '${streak}wanting it back is the loss talking, not your plan.$room what does the plan say right now?';
      case CoachIntent.sizing:
        return risk == null
            ? 'size is the one thing you fully control. sizing up to make something happen is how one trade '
                  'becomes the whole day. what size does your plan say?'
            : 'your risk is ${_n(risk)}% a trade. sizing up to make something happen is how one trade becomes '
                  'the whole day. what changes if you keep it at ${_n(risk)}%?';
      case CoachIntent.stop:
        return 'your stop is where the idea is wrong. moving it changes your trade, not the market. would you '
            'take this trade fresh with the new stop?';
      case CoachIntent.hesitation:
        return 'hesitating is information. check it against your plan: which of your conditions is missing, '
            'if any?';
      case CoachIntent.urge:
        return c.entry == null
            ? "a fast move isn't a setup. what does your entry rule need to see first? what would you tell "
                  'yourself on a calm day?'
            : "the move isn't your rule. your plan waits for ${c.entry}. what would you tell yourself on a "
                  'calm day?';
      case CoachIntent.another:
        if (max == null) return 'is the next one in your plan, or in your mood?';
        if (c.tradesToday >= max) {
          return "you've taken ${c.tradesToday} of $max today. your rule says that's the day. what would "
              'keeping it look like?';
        }
        return 'that would be trade ${c.tradesToday + 1} of $max today. is it in your plan, or in your mood?';
      case CoachIntent.feeling:
        final heavy = c.lossStreak >= 2 ? '${c.lossStreak} losses in a row is a lot to sit with. ' : '';
        return '${heavy}noticing it is the skill. give it a number from 1 to 10, then wait one candle before '
            "you decide anything. what's the number?";
      case CoachIntent.other:
        const open = [
          "say more. what's the trade, and what does your plan say about it?",
          'what would you tell yourself on a calm day?',
          'which of your rules is this about?',
        ];
        return open[turn % open.length];
    }
  }

  /// 1.5 → "1.5", 2.0 → "2", 0.30000000000000004 → "0.3".
  static String _n(double v) {
    final r = double.parse(v.toStringAsFixed(2));
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }
}

/// The coach the session screen talks to. Tests override it with a
/// zero-latency [FakeCoach].
final coachProvider = Provider<Coach>((ref) => const FakeCoach());
