// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prop_rules.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PropRules _$PropRulesFromJson(Map<String, dynamic> json) => _PropRules(
  firm: json['firm'] as String?,
  dailyLossLimitPct: (json['dailyLossLimitPct'] as num?)?.toDouble(),
  maxDrawdownPct: (json['maxDrawdownPct'] as num?)?.toDouble(),
  drawdownType: $enumDecodeNullable(_$DrawdownTypeEnumMap, json['drawdownType']) ?? DrawdownType.fixed,
  trailingBasis: $enumDecodeNullable(_$TrailingBasisEnumMap, json['trailingBasis']) ?? TrailingBasis.equity,
  profitTargetPct: (json['profitTargetPct'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PropRulesToJson(_PropRules instance) => <String, dynamic>{
  'firm': ?instance.firm,
  'dailyLossLimitPct': ?instance.dailyLossLimitPct,
  'maxDrawdownPct': ?instance.maxDrawdownPct,
  'drawdownType': _$DrawdownTypeEnumMap[instance.drawdownType]!,
  'trailingBasis': _$TrailingBasisEnumMap[instance.trailingBasis]!,
  'profitTargetPct': ?instance.profitTargetPct,
};

const _$DrawdownTypeEnumMap = {DrawdownType.fixed: 'fixed', DrawdownType.trailing: 'trailing'};

const _$TrailingBasisEnumMap = {TrailingBasis.balance: 'balance', TrailingBasis.equity: 'equity'};
