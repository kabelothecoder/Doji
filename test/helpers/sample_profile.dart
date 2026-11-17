import 'dart:convert';

import 'package:doji_app/features/accounts/domain/condition_eval.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_step.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';

/// The handoff's example trader ("sam"), answered up to a given step.
const Answers handoffAnswers = {
  StepIds.timeZone: {'id': 'Africa/Johannesburg', 'offsetMinutes': 120, 'detected': true},
  StepIds.name: 'sam',
  StepIds.experience: '6_24m',
  StepIds.style: 'day_trader',
  StepIds.markets: ['XAUUSD', 'NAS100'],
  StepIds.sessions: ['london'],
  StepIds.availability: 'semi_flexible',
  StepIds.goal: {'goal': 'prop_challenge', 'propSize': 50000},
  StepIds.struggles: ['revenge', 'fomo', 'moving_stop'],
  StepIds.strategy: {
    'raw':
        'i wait for the asian range, then trade the london breakout after a retest on M15. '
        'stop under the range, target 2R.',
    'source': 'text',
  },
  StepIds.strategyParsed: {
    'setup': 'london breakout of the asian range',
    'timeframe': 'M15',
    'entry': 'retest of the broken level, candle closes beyond',
    'stop': 'under the asian range',
    'target': '2R',
  },
  StepIds.risk: {'riskPct': 3.0, 'custom': true, 'maxTrades': 3, 'dailyLoss': 2.0},
  StepIds.rules: true,
  StepIds.coach: {'voice': 'calm_female'},
  StepIds.ritual: {'time': '08:30', 'notifications': 'granted'},
};

/// Answers for every step before [stepId] in catalogue order.
Answers answersBefore(String stepId) {
  final order = buildOnboardingSteps().map((s) => s.id).toList();
  final cut = order.indexOf(stepId);
  return {
    for (final e in handoffAnswers.entries)
      if (e.key == StepIds.timeZone || order.indexOf(e.key) < cut) e.key: e.value,
  };
}

/// shared_preferences seed that resumes onboarding at [stepId].
Map<String, Object> resumeAt(String stepId, {String? lastAnswered}) => {
  PrefsOnboardingRepository.snapshotKey: jsonEncode(
    OnboardingSnapshot(
      currentStepId: stepId,
      answers: answersBefore(stepId),
      lastAnsweredStepId: lastAnswered,
    ).toJson(),
  ),
};

/// A profile with one account holding the per-account fields, as onboarding
/// makes it. A strategy without conditions gets the default ones.
ProfileDoji profileWith({
  String? name,
  String? experience,
  String? style,
  List<String> sessions = const [],
  String? timeZone,
  int? utcOffsetMinutes,
  String? goal,
  List<String> struggles = const [],
  CoachProfile? coach,
  String? theOpenTime,
  bool? notificationsAllowed,
  DateTime? pledgedAt,
  DateTime? completedAt,
  bool pendingSync = false,
  List<String> instruments = const [],
  StrategyProfile? strategy,
  TradingRules? rules,
  PropRules? prop,
  String accountCurrency = 'USD',
  double? startingSize,
  AccountKind kind = AccountKind.personal,
}) => ProfileDoji(
  name: name,
  experience: experience,
  style: style,
  sessions: sessions,
  timeZone: timeZone,
  utcOffsetMinutes: utcOffsetMinutes,
  goal: goal,
  struggles: struggles,
  coach: coach,
  theOpenTime: theOpenTime,
  notificationsAllowed: notificationsAllowed,
  pledgedAt: pledgedAt,
  completedAt: completedAt,
  pendingSync: pendingSync,
  activeAccountId: kFirstAccountId,
  accounts: [
    TradingAccount(
      id: kFirstAccountId,
      name: kind.label,
      kind: kind,
      accountCurrency: accountCurrency,
      startingSize: startingSize,
      instruments: instruments,
      rules: rules,
      prop: prop,
      strategy: (strategy ?? const StrategyProfile()).conditions.isNotEmpty
          ? strategy
          : (strategy ?? const StrategyProfile()).copyWith(conditions: defaultConditions(strategy?.parsed)),
    ),
  ],
);
