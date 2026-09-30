import 'onboarding_catalog.dart';
import 'onboarding_step.dart';
import 'profile_doji.dart';

/// Builds the typed profile from raw answers. Pure: safe to call on every
/// rebuild, and the single place that knows each answer's shape.
ProfileDoji profileFromAnswers(Answers a) {
  final goal = a[StepIds.goal];
  final strategy = a[StepIds.strategy];
  final parsed = a[StepIds.strategyParsed];
  final risk = a[StepIds.risk];
  final coach = a[StepIds.coach];
  final ritual = a[StepIds.ritual];
  final tz = a[StepIds.timeZone];
  final pledge = a[StepIds.pledge];

  ParsedStrategy? parsedStrategy;
  if (parsed is Map) {
    parsedStrategy = ParsedStrategy(
      setup: A.mapStr(parsed, 'setup'),
      timeframe: A.mapStr(parsed, 'timeframe'),
      entry: A.mapStr(parsed, 'entry'),
      stop: A.mapStr(parsed, 'stop'),
      target: A.mapStr(parsed, 'target'),
    );
  }

  final notifications = A.mapStr(ritual, 'notifications');
  final pledgedAt = A.mapStr(pledge, 'pledgedAt');

  return ProfileDoji(
    name: A.str(a, StepIds.name)?.trim(),
    experience: A.str(a, StepIds.experience),
    style: A.str(a, StepIds.style),
    pairs: A.list(a, StepIds.markets),
    sessions: A.list(a, StepIds.sessions),
    timeZone: A.mapStr(tz, 'id'),
    utcOffsetMinutes: A.mapNum(tz, 'offsetMinutes')?.round(),
    goal: A.mapStr(goal, 'goal'),
    propFirm: A.mapStr(goal, 'propFirm'),
    propSize: A.mapNum(goal, 'propSize')?.round(),
    struggles: A.list(a, StepIds.struggles),
    strategy: strategy is Map || parsedStrategy != null
        ? StrategyProfile(
            rawText: A.mapStr(strategy, 'raw'),
            template: A.mapStr(strategy, 'template'),
            source: A.mapStr(strategy, 'source'),
            parsed: parsedStrategy,
          )
        : null,
    rules: risk is Map
        ? TradingRules(
            riskPerTrade: A.mapNum(risk, 'riskPct'),
            maxTradesPerDay: A.mapNum(risk, 'maxTrades')?.round(),
            dailyLossLimit: A.mapNum(risk, 'dailyLoss'),
          )
        : null,
    coach: coach is Map ? CoachProfile(voice: A.mapStr(coach, 'voice'), name: A.mapStr(coach, 'name')) : null,
    theOpenTime: A.mapStr(ritual, 'time'),
    notificationsAllowed: notifications == null ? null : notifications == 'granted',
    pledgedAt: pledgedAt == null ? null : DateTime.tryParse(pledgedAt),
  );
}
