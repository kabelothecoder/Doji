// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_doji.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileDoji _$ProfileDojiFromJson(Map<String, dynamic> json) => _ProfileDoji(
  name: json['name'] as String?,
  experience: json['experience'] as String?,
  style: json['style'] as String?,
  sessions: (json['sessions'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const <String>[],
  timeZone: json['timeZone'] as String?,
  utcOffsetMinutes: (json['utcOffsetMinutes'] as num?)?.toInt(),
  goal: json['goal'] as String?,
  struggles: (json['struggles'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const <String>[],
  accounts:
      (json['accounts'] as List<dynamic>?)
          ?.map((e) => TradingAccount.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <TradingAccount>[],
  activeAccountId: json['activeAccountId'] as String?,
  coach: json['coach'] == null ? null : CoachProfile.fromJson(json['coach'] as Map<String, dynamic>),
  theOpenTime: json['theOpenTime'] as String?,
  notificationsAllowed: json['notificationsAllowed'] as bool?,
  pledgedAt: json['pledgedAt'] == null ? null : DateTime.parse(json['pledgedAt'] as String),
  onboardingVersion: (json['onboardingVersion'] as num?)?.toInt() ?? kOnboardingVersion,
  rank: json['rank'] as String? ?? 'M1',
  pendingSync: json['pendingSync'] as bool? ?? false,
  completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
);

Map<String, dynamic> _$ProfileDojiToJson(_ProfileDoji instance) => <String, dynamic>{
  'name': ?instance.name,
  'experience': ?instance.experience,
  'style': ?instance.style,
  'sessions': instance.sessions,
  'timeZone': ?instance.timeZone,
  'utcOffsetMinutes': ?instance.utcOffsetMinutes,
  'goal': ?instance.goal,
  'struggles': instance.struggles,
  'accounts': instance.accounts.map((e) => e.toJson()).toList(),
  'activeAccountId': ?instance.activeAccountId,
  'coach': ?instance.coach?.toJson(),
  'theOpenTime': ?instance.theOpenTime,
  'notificationsAllowed': ?instance.notificationsAllowed,
  'pledgedAt': ?instance.pledgedAt?.toIso8601String(),
  'onboardingVersion': instance.onboardingVersion,
  'rank': instance.rank,
  'pendingSync': instance.pendingSync,
  'completedAt': ?instance.completedAt?.toIso8601String(),
};

_StrategyProfile _$StrategyProfileFromJson(Map<String, dynamic> json) => _StrategyProfile(
  rawText: json['rawText'] as String?,
  template: json['template'] as String?,
  source: json['source'] as String?,
  parsed: json['parsed'] == null ? null : ParsedStrategy.fromJson(json['parsed'] as Map<String, dynamic>),
  conditions:
      (json['conditions'] as List<dynamic>?)
          ?.map((e) => StrategyCondition.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <StrategyCondition>[],
);

Map<String, dynamic> _$StrategyProfileToJson(_StrategyProfile instance) => <String, dynamic>{
  'rawText': ?instance.rawText,
  'template': ?instance.template,
  'source': ?instance.source,
  'parsed': ?instance.parsed?.toJson(),
  'conditions': instance.conditions.map((e) => e.toJson()).toList(),
};

_ParsedStrategy _$ParsedStrategyFromJson(Map<String, dynamic> json) => _ParsedStrategy(
  setup: json['setup'] as String?,
  timeframe: json['timeframe'] as String?,
  entry: json['entry'] as String?,
  stop: json['stop'] as String?,
  target: json['target'] as String?,
);

Map<String, dynamic> _$ParsedStrategyToJson(_ParsedStrategy instance) => <String, dynamic>{
  'setup': ?instance.setup,
  'timeframe': ?instance.timeframe,
  'entry': ?instance.entry,
  'stop': ?instance.stop,
  'target': ?instance.target,
};

_TradingRules _$TradingRulesFromJson(Map<String, dynamic> json) => _TradingRules(
  riskPerTrade: (json['riskPerTrade'] as num?)?.toDouble(),
  maxTradesPerDay: (json['maxTradesPerDay'] as num?)?.toInt(),
  dailyLossLimit: (json['dailyLossLimit'] as num?)?.toDouble(),
);

Map<String, dynamic> _$TradingRulesToJson(_TradingRules instance) => <String, dynamic>{
  'riskPerTrade': ?instance.riskPerTrade,
  'maxTradesPerDay': ?instance.maxTradesPerDay,
  'dailyLossLimit': ?instance.dailyLossLimit,
};

_CoachProfile _$CoachProfileFromJson(Map<String, dynamic> json) =>
    _CoachProfile(voice: json['voice'] as String?, name: json['name'] as String?);

Map<String, dynamic> _$CoachProfileToJson(_CoachProfile instance) => <String, dynamic>{
  'voice': ?instance.voice,
  'name': ?instance.name,
};
