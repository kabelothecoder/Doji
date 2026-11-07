import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_functions.dart';
import '../../../core/copy_rules.dart';
import '../../coach/data/supabase_coach.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../plans/domain/plans.dart';
import '../../plans/presentation/plans_controller.dart';
import '../domain/brief_allowance.dart';
import '../domain/pair_brief.dart';
import 'brief_allowance_repository.dart';

/// What the `ai-brief` and `ai-brief-chat` functions are told: the facts the
/// device measured, never prices to predict from.
Map<String, Object?> briefFacts(PairBrief b, BriefRequest r) => {
  ...SupabaseCoach.contextJson(r.coach),
  'strategyName': b.strategyName,
  'strategyWords': r.profile.strategy?.rawText,
  'conditions': [
    for (final c in b.conditions) {'text': c.text, 'status': c.status.name},
  ],
  'nextNews': b.nextNews == null
      ? null
      : {'title': b.nextNews!.title, 'at': b.nextNews!.at.toIso8601String()},
  'dayDone': b.dayDone,
  'checkAgain': b.checkAgain == null
      ? null
      : {'at': b.checkAgain!.at.toIso8601String(), 'why': b.checkAgain!.why},
  'levels': b.levels == null ? null : {'label': b.levels!.spoken},
  'now': r.now.toUtc().toIso8601String(),
};

/// 1b's brief with Gemini writing 01, 02, 04 and the follow-ups. [measure]
/// (the on-device [FakeBrief]) works out the conditions, levels and
/// check-again first; they are never written by the model. A field the
/// function leaves null, or any failure, keeps the measured brief's own text,
/// so the brief still shows offline.
class SupabaseBrief implements BriefSource {
  const SupabaseBrief(
    this._ai, {
    required this.measure,
    required this.plan,
    required this.zone,
    required this.onBriefUsed,
  });

  final AiFunctions _ai;
  final BriefSource measure;
  final PlanId Function() plan;

  /// The trader's IANA zone: the server counts the free brief per local day.
  final String Function() zone;

  /// The server says today's free brief went to another instrument.
  final void Function(String symbol) onBriefUsed;

  @override
  Future<PairBrief> brief(BriefRequest request) async {
    final b = await measure.brief(request);
    final Map<String, dynamic> res;
    try {
      res = await _ai.call('ai-brief', {
        'symbol': request.symbol,
        'zone': zone(),
        'plan': plan().name,
        'facts': briefFacts(b, request),
      });
    } on AiBriefUsed {
      onBriefUsed(request.symbol);
      return b;
    } on AiFailure {
      return b;
    }
    String pick(Object? v, String own) =>
        v is String && v.trim().isNotEmpty && !breaksCopyRules(v) ? v.trim() : own;
    final ups = res['followUps'];
    final followUps = ups is List
        ? ups.whereType<String>().where((q) => !breaksCopyRules(q)).toList()
        : <String>[];
    return PairBrief(
      symbol: b.symbol,
      updatedAt: b.updatedAt,
      context: pick(res['context'], b.context),
      strategyName: b.strategyName,
      strategy: pick(res['strategy'], b.strategy),
      conditions: b.conditions,
      riskNote: pick(res['riskNote'], b.riskNote),
      checkAgain: b.checkAgain,
      followUps: followUps.isEmpty ? b.followUps : followUps,
      levels: b.levels,
      nextNews: b.nextNews,
      dayDone: b.dayDone,
    );
  }
}

/// "Ask about this brief" on Gemini (`ai-brief-chat`); [fallback] answers on
/// any failure or a reply that breaks the copy rules.
class SupabaseBriefChat implements BriefChat {
  const SupabaseBriefChat(this._ai, {required this.fallback, required this.plan, required this.zone});

  final AiFunctions _ai;
  final BriefChat fallback;
  final PlanId Function() plan;
  final String Function() zone;

  @override
  Future<String> reply(PairBrief brief, BriefRequest request, List<BriefTurn> history, String message) async {
    try {
      final res = await _ai.call('ai-brief-chat', {
        'symbol': request.symbol,
        'zone': zone(),
        'plan': plan().name,
        'brief': {'context': brief.context, 'strategy': brief.strategy, 'riskNote': brief.riskNote},
        'facts': briefFacts(brief, request),
        'history': [
          for (final t in history.length > 12 ? history.sublist(history.length - 12) : history)
            {'fromYou': t.fromYou, 'text': t.text.length > 600 ? t.text.substring(0, 600) : t.text},
        ],
        'message': message.length > 600 ? message.substring(0, 600) : message,
      });
      final reply = res['reply'];
      if (reply is String && reply.trim().isNotEmpty && !breaksCopyRules(reply)) return reply.trim();
    } on AiFailure {
      // fall through
    }
    return fallback.reply(brief, request, history, message);
  }
}

/// Bumped when the server says today's free brief is used elsewhere, so 1b's
/// access (BriefAccessController) reads the allowance again.
class BriefUsedSignal extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final briefUsedSignalProvider = NotifierProvider<BriefUsedSignal, int>(BriefUsedSignal.new);

/// The plan and zone the AI functions are told (read at call time).
PlanId currentPlan(Ref ref) => ref.read(entitlementProvider).plan;
String currentZone(Ref ref) => ref.read(onboardingRepositoryProvider).loadProfile()?.timeZone ?? 'UTC';

/// The server's count wins: today's free brief is spent, so lock the rest.
Future<void> markBriefUsed(Ref ref) async {
  final repo = ref.read(briefAllowanceRepositoryProvider);
  final now = clock.now();
  if (!repo.load().usedOn(now)) await repo.save(BriefAllowance(day: BriefAllowance.dayKey(now)));
  ref.read(briefUsedSignalProvider.notifier).bump();
}
