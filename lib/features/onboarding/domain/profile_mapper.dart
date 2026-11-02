import '../../accounts/domain/condition_eval.dart';
import '../../accounts/domain/trading_account.dart';
import '../../markets/domain/instrument.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/domain/currency.dart';
import 'onboarding_catalog.dart';
import 'onboarding_step.dart';
import 'profile_doji.dart';
import 'prop_rules.dart';

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
    sessions: A.list(a, StepIds.sessions),
    timeZone: A.mapStr(tz, 'id'),
    utcOffsetMinutes: A.mapNum(tz, 'offsetMinutes')?.round(),
    goal: A.mapStr(goal, 'goal'),
    struggles: A.list(a, StepIds.struggles),
    accounts: [
      _firstAccount(
        goal: goal,
        instruments: A.list(a, StepIds.markets),
        currency: AccountCurrency.fromCode(A.mapStr(risk, 'currency'))?.code ?? AccountCurrency.fallback.code,
        strategy: StrategyProfile(
          rawText: A.mapStr(strategy, 'raw'),
          template: A.mapStr(strategy, 'template'),
          source: A.mapStr(strategy, 'source'),
          parsed: parsedStrategy,
          conditions: defaultConditions(parsedStrategy),
        ),
        rules: risk is Map
            ? TradingRules(
                riskPerTrade: A.mapNum(risk, 'riskPct'),
                maxTradesPerDay: A.mapNum(risk, 'maxTrades')?.round(),
                dailyLossLimit: A.mapNum(risk, 'dailyLoss'),
              )
            : null,
      ),
    ],
    activeAccountId: kFirstAccountId,
    coach: coach is Map ? CoachProfile(voice: A.mapStr(coach, 'voice'), name: A.mapStr(coach, 'name')) : null,
    theOpenTime: A.mapStr(ritual, 'time'),
    notificationsAllowed: notifications == null ? null : notifications == 'granted',
    pledgedAt: pledgedAt == null ? null : DateTime.tryParse(pledgedAt),
  );
}

/// The prop limits typed on the goal step. Only for a prop challenge, and
/// null when the user entered none of them.
PropRules? _propRules(Object? goal) {
  if (A.mapStr(goal, 'goal') != 'prop_challenge') return null;
  final rules = PropRules(
    firm: A.mapStr(goal, 'propFirm'),
    dailyLossLimitPct: A.mapNum(goal, 'propDailyLoss')?.toDouble(),
    maxDrawdownPct: A.mapNum(goal, 'propMaxDrawdown')?.toDouble(),
    drawdownType: DrawdownType.values.asNameMap()[A.mapStr(goal, 'propDrawdownType')] ?? DrawdownType.fixed,
    trailingBasis:
        TrailingBasis.values.asNameMap()[A.mapStr(goal, 'propTrailingBasis')] ?? TrailingBasis.equity,
    profitTargetPct: A.mapNum(goal, 'propTarget')?.toDouble(),
  );
  return rules.isEmpty ? null : rules;
}

/// The id of the account onboarding creates.
const kFirstAccountId = 'account_1';

/// The first account, from the onboarding answers. A prop goal makes a prop
/// challenge (its size is the starting size); only synthetics makes a Deriv
/// synthetics account; anything else is personal.
TradingAccount _firstAccount({
  required Object? goal,
  required List<String> instruments,
  required String currency,
  required StrategyProfile strategy,
  required TradingRules? rules,
}) {
  final prop = _propRules(goal);
  final isProp = A.mapStr(goal, 'goal') == 'prop_challenge';
  final synthetic =
      instruments.isNotEmpty &&
      instruments.every((s) => instrumentBySymbol(s)?.assetClass == AssetClass.synthetic);
  final kind = isProp
      ? AccountKind.propChallenge
      : synthetic
      ? AccountKind.derivSynthetic
      : AccountKind.personal;
  return TradingAccount(
    id: kFirstAccountId,
    name: kind.label,
    kind: kind,
    accountCurrency: currency,
    startingSize: isProp ? A.mapNum(goal, 'propSize')?.toDouble() : null,
    instruments: instruments,
    rules: rules,
    prop: prop,
    strategy: strategy,
  );
}
