import '../../accounts/domain/trading_account.dart';
import '../../markets/domain/news.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/sessions.dart';
import 'trade.dart';

/// Guardrail flags (design/research-intake-plan.md › 2): facts about how a trade was taken,
/// measured against the trader's own rules. Worked out when shown, never stored, never a grade.

/// Risk counts as above plan from 10% over it, so rounding in sizing is not flagged.
const double kRiskOverPlanTolerance = 1.1;

/// "09:35" → minutes after midnight; null when not a valid HH:mm.
int? minutesOf(String? hhmmText) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmmText?.trim() ?? '');
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  return h < 24 && min < 60 ? h * 60 + min : null;
}

/// Why [at] (shown on the trader's own clock) is outside their trading window, or null when it
/// is inside or no window is set.
String? outsideWindow(TradingRules? rules, DateTime at) {
  final local = at.toLocal();
  final now = local.hour * 60 + local.minute;
  final start = minutesOf(rules?.noTradesBefore);
  final end = minutesOf(rules?.noTradesAfter);
  if (start != null && now < start) return 'before your ${hhmm(start)} start';
  if (end != null && now >= end) return 'after your ${hhmm(end)} finish';
  return null;
}

/// The flags for [t] on [account]. [news]: high-impact events near the trade's open.
List<String> guardrailFlags(Trade t, {TradingAccount? account, List<NewsEvent> news = const []}) {
  final opened = t.openedAt.toLocal();
  final at = hhmm(opened.hour * 60 + opened.minute);
  final rules = account?.rules;
  final size = account?.startingSize;
  final plannedPct = rules?.riskPerTrade;
  return [
    if (t.stop == null) 'no stop recorded.',
    if (t.riskMoney case final risk? when size != null && size > 0 && plannedPct != null)
      if (risk / size * 100 > plannedPct * kRiskOverPlanTolerance)
        'risked ${_n(risk / size * 100)}% of the account; your plan is ${_n(plannedPct)}%.',
    for (final e in news)
      if (e.at.difference(t.openedAt).inMinutes.abs() <= kNewsBufferMinutes)
        'opened at $at, ${e.at.difference(t.openedAt).inMinutes.abs()} min from ${e.title}.',
    if (outsideWindow(rules, t.openedAt) case final why?) 'opened at $at, $why.',
  ];
}

String _n(double v) {
  final r = (v * 10).roundToDouble() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
}
