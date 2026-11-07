import '../../../core/ai/ai_functions.dart';
import '../../../core/copy_rules.dart';
import '../domain/coach.dart';
import 'fake_coach.dart';

/// The coach on Gemini, through the `ai-coach` edge function (prompt, crisis
/// check and copy guard live there). When the call fails, or a reply still
/// breaks the copy rules here, [fallback] answers: the session never stalls.
class SupabaseCoach implements Coach {
  const SupabaseCoach(this._ai, {this.fallback = const FakeCoach(latency: Duration.zero)});

  final AiFunctions _ai;
  final Coach fallback;

  /// What the function is told: only the facts doji measured.
  static Map<String, Object?> contextJson(CoachContext c) => {
    'name': c.name,
    'setup': c.setup,
    'entry': c.entry,
    'riskPerTradePct': c.riskPerTradePct,
    'maxTradesPerDay': c.maxTradesPerDay,
    'dailyLossLimitPct': c.dailyLossLimitPct,
    'struggles': c.struggles,
    'tradesToday': c.tradesToday,
    'lossStreak': c.lossStreak,
    'lossTodayPct': c.lossTodayPct,
  };

  @override
  Future<String> opener(CoachContext context) =>
      _ask(context, const [], null, () => fallback.opener(context));

  @override
  Future<String> reply(CoachContext context, List<CoachTurn> history, String message) =>
      _ask(context, history, message, () => fallback.reply(context, history, message));

  Future<String> _ask(
    CoachContext context,
    List<CoachTurn> history,
    String? message,
    Future<String> Function() orElse,
  ) async {
    try {
      final res = await _ai.call('ai-coach', {
        'context': contextJson(context),
        'history': [
          for (final t in history.length > 20 ? history.sublist(history.length - 20) : history)
            {'speaker': t.speaker.name, 'text': t.text.length > 600 ? t.text.substring(0, 600) : t.text},
        ],
        'message': message,
      });
      final reply = res['reply'];
      if (reply is String && reply.trim().isNotEmpty && !breaksCopyRules(reply)) return reply.trim();
    } on AiFailure {
      // fall through to the on-device coach
    }
    return orElse();
  }
}
