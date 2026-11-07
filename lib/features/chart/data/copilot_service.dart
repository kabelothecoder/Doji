import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_functions.dart';
import '../../../core/copy_rules.dart';
import '../../coach/data/fake_coach.dart';
import '../../coach/data/supabase_coach.dart';
import '../../markets/domain/pair_brief.dart';
import '../domain/copilot.dart';
import '../domain/drawing.dart';

/// The co-pilot's own line when it has nothing better: never a rating.
const kCopilotFallback = 'what in your written rules does this mark?';

/// Shown when the server's daily co-pilot count is used up.
const kCopilotLimitLine = "you've used today's co-pilot replies. your reason is saved.";

/// Worked out on the device from the trader's words, conditions and limits.
/// Tests and local runs use it; [SupabaseCopilot] falls back to it.
class FakeCopilot implements Copilot {
  const FakeCopilot({this.latency = const Duration(milliseconds: 400)});

  final Duration latency;

  @override
  Future<CopilotReply> reflect(CopilotRequest r) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return replyFor(r);
  }

  static CopilotReply replyFor(CopilotRequest r) {
    if (FakeCoach.intentOf(r.reason) == CoachIntent.crisis) {
      return CopilotReply(
        FakeCoach.replyFor(CoachIntent.crisis, r.coach),
        kind: CopilotKind.rule,
        crisis: true,
      );
    }
    final c = r.coach;
    final max = c.maxTradesPerDay;
    if (max != null && c.tradesToday >= max) {
      return CopilotReply(
        "that's ${c.tradesToday} of $max trades today. your rules say the day is done.",
        kind: CopilotKind.rule,
      );
    }
    final limit = c.dailyLossLimitPct;
    if (limit != null && c.lossTodayPct >= limit) {
      return CopilotReply(
        "you're at your daily loss limit (${_pct(limit)}). your rules say stop for today.",
        kind: CopilotKind.rule,
      );
    }
    if (c.lossStreak >= 2) {
      return const CopilotReply(
        'two losses in a row today. what does your plan say to do after that?',
        kind: CopilotKind.rule,
      );
    }
    final rule = _ruleMatching(r.strategyWords, r.reason);
    if (rule != null) {
      final line = 'your rules say: "$rule". was that there?';
      if (_clean(line)) return CopilotReply(line, kind: CopilotKind.rule);
    }
    final open = r.conditions.where((x) => x.status != ConditionStatus.met).firstOrNull;
    if (open != null) {
      final line =
          'your conditions show "${open.text.toLowerCase()}" as ${open.status.label.toLowerCase()}. '
          'how does this ${r.drawing.kind.label} fit with that?';
      if (_clean(line)) return CopilotReply(line, kind: CopilotKind.rule);
    }
    if (r.strategyWords.trim().isEmpty) {
      return CopilotReply(
        'which rule in your plan does this ${r.drawing.kind.label} belong to?',
        kind: CopilotKind.question,
      );
    }
    return CopilotReply('what in your plan does this ${r.drawing.kind.label} mark?');
  }

  static bool _clean(String s) => !breaksCopyRules(s) && !ratesOdds(s);

  static String _pct(double v) => '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v}%';

  static const _stop = {
    'the',
    'and',
    'this',
    'that',
    'with',
    'from',
    'only',
    'after',
    'before',
    'when',
    'then',
    'have',
    'into',
    'your',
    'mine',
    'just',
    'there',
    'what',
    'here',
    'will',
    'take',
    'look',
    'trade',
    'trades',
  };

  /// The sentence of [strategy] sharing the most words with [reason] (two at
  /// least, or one of five letters or more); null when none does.
  static String? _ruleMatching(String strategy, String reason) {
    Set<String> words(String s) => RegExp(
      r"[a-z0-9']+",
    ).allMatches(s.toLowerCase()).map((m) => m[0]!).where((w) => w.length >= 3 && !_stop.contains(w)).toSet();
    final asked = words(reason);
    if (asked.isEmpty) return null;
    String? best;
    var bestScore = 0;
    for (final raw in strategy.split(RegExp(r'[.\n;!?]+'))) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      final shared = words(s).intersection(asked);
      final score = shared.length >= 2 ? shared.length * 2 : (shared.any((w) => w.length >= 5) ? 1 : 0);
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    if (best == null) return null;
    final t = best.toLowerCase();
    return t.length > 120 ? '${t.substring(0, 117)}…' : t;
  }
}

/// The request as the `ai-copilot` function takes it.
Map<String, Object?> copilotBody(CopilotRequest r) {
  final d = r.drawing;
  return {
    'symbol': r.symbol,
    'timeframe': r.timeframe.label,
    'drawing': {
      'kind': d.kind.name,
      'prices': [for (final (_, p) in d.prices) p],
      'times': [d.a.at.toIso8601String(), ?d.b?.at.toIso8601String()],
      if (d.kind == DrawingKind.position)
        'position': {'entry': d.entry, 'stop': d.stop, 'target': d.target, 'r': r.r},
    },
    'reason': r.reason.length > 500 ? r.reason.substring(0, 500) : r.reason,
    'strategy': {
      'words': r.strategyWords.length > 2000 ? r.strategyWords.substring(0, 2000) : r.strategyWords,
      'conditions': [
        for (final c in r.conditions.take(12))
          {'text': c.text.length > 200 ? c.text.substring(0, 200) : c.text, 'status': c.status.name},
      ],
    },
    'facts': {...SupabaseCoach.contextJson(r.coach), 'lastPrice': r.lastPrice},
  };
}

/// Gemini behind `ai-copilot`. Any failure, or a reply that breaks the copy
/// rules or rates the odds, falls back to [FakeCopilot]; the server's daily
/// limit says so plainly.
class SupabaseCopilot implements Copilot {
  const SupabaseCopilot(this._ai);

  final AiFunctions _ai;

  @override
  Future<CopilotReply> reflect(CopilotRequest r) async {
    try {
      final res = await _ai.call('ai-copilot', copilotBody(r));
      final text = res['reply'];
      if (res['crisis'] == true && text is String) {
        return CopilotReply(text, kind: CopilotKind.rule, crisis: true);
      }
      if (text is String && text.trim().isNotEmpty && !breaksCopyRules(text) && !ratesOdds(text)) {
        return CopilotReply(
          text.trim(),
          kind: res['kind'] == 'rule' ? CopilotKind.rule : CopilotKind.question,
        );
      }
    } on AiRateLimited {
      return const CopilotReply(kCopilotLimitLine, kind: CopilotKind.notice);
    } on AiFailure {
      // fall through to the device's own line
    }
    return FakeCopilot.replyFor(r);
  }
}

/// [SupabaseCopilot] when Supabase started, else [FakeCopilot].
final copilotProvider = Provider<Copilot>((ref) {
  final ai = ref.watch(aiFunctionsProvider);
  return ai == null ? const FakeCopilot() : SupabaseCopilot(ai);
});
