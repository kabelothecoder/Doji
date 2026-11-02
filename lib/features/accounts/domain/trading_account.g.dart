// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trading_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TradingAccount _$TradingAccountFromJson(Map<String, dynamic> json) => _TradingAccount(
  id: json['id'] as String,
  name: json['name'] as String,
  kind: $enumDecodeNullable(_$AccountKindEnumMap, json['kind']) ?? AccountKind.personal,
  accountCurrency: json['accountCurrency'] as String? ?? 'USD',
  startingSize: (json['startingSize'] as num?)?.toDouble(),
  instruments: (json['instruments'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const <String>[],
  rules: json['rules'] == null ? null : TradingRules.fromJson(json['rules'] as Map<String, dynamic>),
  prop: json['prop'] == null ? null : PropRules.fromJson(json['prop'] as Map<String, dynamic>),
  strategy: json['strategy'] == null
      ? null
      : StrategyProfile.fromJson(json['strategy'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TradingAccountToJson(_TradingAccount instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'kind': _$AccountKindEnumMap[instance.kind]!,
  'accountCurrency': instance.accountCurrency,
  'startingSize': ?instance.startingSize,
  'instruments': instance.instruments,
  'rules': ?instance.rules?.toJson(),
  'prop': ?instance.prop?.toJson(),
  'strategy': ?instance.strategy?.toJson(),
};

const _$AccountKindEnumMap = {
  AccountKind.derivSynthetic: 'deriv_synthetic',
  AccountKind.propChallenge: 'prop_challenge',
  AccountKind.personal: 'personal',
  AccountKind.demo: 'demo',
};

_StrategyCondition _$StrategyConditionFromJson(Map<String, dynamic> json) => _StrategyCondition(
  kind: $enumDecode(_$ConditionKindEnumMap, json['kind']),
  session: json['session'] as String?,
  closeBack: json['closeBack'] as bool? ?? false,
  text: json['text'] as String?,
);

Map<String, dynamic> _$StrategyConditionToJson(_StrategyCondition instance) => <String, dynamic>{
  'kind': _$ConditionKindEnumMap[instance.kind]!,
  'session': ?instance.session,
  'closeBack': instance.closeBack,
  'text': ?instance.text,
};

const _$ConditionKindEnumMap = {
  ConditionKind.session: 'session',
  ConditionKind.newsBuffer: 'news_buffer',
  ConditionKind.tradesVsMax: 'trades_vs_max',
  ConditionKind.dailyLossVsLimit: 'daily_loss_vs_limit',
  ConditionKind.rangeBreak: 'range_break',
  ConditionKind.manual: 'manual',
};
