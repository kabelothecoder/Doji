import 'onboarding_catalog.dart';
import 'onboarding_step.dart';
import 'profile_mapper.dart';
import 'risk.dart';

/// One plain-language rule on the "your rules v1" card. [stepId] is where
/// tapping it goes to edit.
typedef TradingRule = ({String text, String stepId});

/// Handoff 4d: "Summary of everything so far in plain language."
List<TradingRule> buildRules(Answers answers) {
  final p = profileFromAnswers(answers);
  final s = p.strategy?.parsed;
  final tf = s?.timeframe;
  final rules = <TradingRule>[];
  const strat = StepIds.strategyParsed;

  if (s?.setup != null) {
    rules.add((text: 'trade the ${s!.setup}${tf == null ? '' : ', $tf only'}.', stepId: strat));
  }
  final entry = s?.entry;
  if (entry != null) {
    rules.add((
      text: entry.contains('retest')
          ? 'enter only after ${tf == null ? 'a' : 'an $tf'} retest closes beyond the level.'
          : 'enter only on $entry.',
      stepId: strat,
    ));
  }
  final stopTarget = [
    if (s?.stop != null) 'stop ${s!.stop}.',
    if (s?.target != null) 'target ${s!.target}.',
  ].join(' ');
  if (stopTarget.isNotEmpty) rules.add((text: stopTarget, stepId: strat));

  final r = p.rules;
  final riskParts = [
    if (r?.riskPerTrade != null) 'risk ${fmtPct(r!.riskPerTrade!)}% a trade.',
    if (r?.maxTradesPerDay != null) 'max ${r!.maxTradesPerDay} trades a day.',
  ].join(' ');
  if (riskParts.isNotEmpty) rules.add((text: riskParts, stepId: StepIds.risk));
  if (r?.dailyLossLimit != null) {
    rules.add((text: 'stop for the day at -${fmtPct(r!.dailyLossLimit!)}%.', stepId: StepIds.risk));
  }
  return rules;
}

/// "LONDON BREAK · M15" on the rules card.
String rulesTag(Answers answers) {
  final s = profileFromAnswers(answers).strategy?.parsed;
  if (s == null || s.isEmpty) return 'RISK RULES';
  final name = s.slug.replaceAll('_', ' ').toUpperCase();
  return s.timeframe == null ? name : '$name · ${s.timeframe}';
}
