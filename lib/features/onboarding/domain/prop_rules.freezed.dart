// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prop_rules.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PropRules {

/// Free text, shown as a comment in profile.doji.
 String? get firm; int? get accountSize;/// Most you may lose in one day, % of the account.
 double? get dailyLossLimitPct;/// Most the account may fall, % of the account. How it is measured is
/// [drawdownType] (and [trailingBasis] when trailing).
 double? get maxDrawdownPct;/// Static unless the user says otherwise.
 DrawdownType get drawdownType;/// Only read when [drawdownType] is trailing. Equity is the stricter
/// (open profit raises the high), so it is the default.
 TrailingBasis get trailingBasis;/// Profit that passes the challenge, %. Null on funded accounts.
 double? get profitTargetPct;
/// Create a copy of PropRules
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PropRulesCopyWith<PropRules> get copyWith => _$PropRulesCopyWithImpl<PropRules>(this as PropRules, _$identity);

  /// Serializes this PropRules to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PropRules&&(identical(other.firm, firm) || other.firm == firm)&&(identical(other.accountSize, accountSize) || other.accountSize == accountSize)&&(identical(other.dailyLossLimitPct, dailyLossLimitPct) || other.dailyLossLimitPct == dailyLossLimitPct)&&(identical(other.maxDrawdownPct, maxDrawdownPct) || other.maxDrawdownPct == maxDrawdownPct)&&(identical(other.drawdownType, drawdownType) || other.drawdownType == drawdownType)&&(identical(other.trailingBasis, trailingBasis) || other.trailingBasis == trailingBasis)&&(identical(other.profitTargetPct, profitTargetPct) || other.profitTargetPct == profitTargetPct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,firm,accountSize,dailyLossLimitPct,maxDrawdownPct,drawdownType,trailingBasis,profitTargetPct);

@override
String toString() {
  return 'PropRules(firm: $firm, accountSize: $accountSize, dailyLossLimitPct: $dailyLossLimitPct, maxDrawdownPct: $maxDrawdownPct, drawdownType: $drawdownType, trailingBasis: $trailingBasis, profitTargetPct: $profitTargetPct)';
}


}

/// @nodoc
abstract mixin class $PropRulesCopyWith<$Res>  {
  factory $PropRulesCopyWith(PropRules value, $Res Function(PropRules) _then) = _$PropRulesCopyWithImpl;
@useResult
$Res call({
 String? firm, int? accountSize, double? dailyLossLimitPct, double? maxDrawdownPct, DrawdownType drawdownType, TrailingBasis trailingBasis, double? profitTargetPct
});




}
/// @nodoc
class _$PropRulesCopyWithImpl<$Res>
    implements $PropRulesCopyWith<$Res> {
  _$PropRulesCopyWithImpl(this._self, this._then);

  final PropRules _self;
  final $Res Function(PropRules) _then;

/// Create a copy of PropRules
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? firm = freezed,Object? accountSize = freezed,Object? dailyLossLimitPct = freezed,Object? maxDrawdownPct = freezed,Object? drawdownType = null,Object? trailingBasis = null,Object? profitTargetPct = freezed,}) {
  return _then(_self.copyWith(
firm: freezed == firm ? _self.firm : firm // ignore: cast_nullable_to_non_nullable
as String?,accountSize: freezed == accountSize ? _self.accountSize : accountSize // ignore: cast_nullable_to_non_nullable
as int?,dailyLossLimitPct: freezed == dailyLossLimitPct ? _self.dailyLossLimitPct : dailyLossLimitPct // ignore: cast_nullable_to_non_nullable
as double?,maxDrawdownPct: freezed == maxDrawdownPct ? _self.maxDrawdownPct : maxDrawdownPct // ignore: cast_nullable_to_non_nullable
as double?,drawdownType: null == drawdownType ? _self.drawdownType : drawdownType // ignore: cast_nullable_to_non_nullable
as DrawdownType,trailingBasis: null == trailingBasis ? _self.trailingBasis : trailingBasis // ignore: cast_nullable_to_non_nullable
as TrailingBasis,profitTargetPct: freezed == profitTargetPct ? _self.profitTargetPct : profitTargetPct // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [PropRules].
extension PropRulesPatterns on PropRules {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PropRules value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PropRules() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PropRules value)  $default,){
final _that = this;
switch (_that) {
case _PropRules():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PropRules value)?  $default,){
final _that = this;
switch (_that) {
case _PropRules() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? firm,  int? accountSize,  double? dailyLossLimitPct,  double? maxDrawdownPct,  DrawdownType drawdownType,  TrailingBasis trailingBasis,  double? profitTargetPct)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PropRules() when $default != null:
return $default(_that.firm,_that.accountSize,_that.dailyLossLimitPct,_that.maxDrawdownPct,_that.drawdownType,_that.trailingBasis,_that.profitTargetPct);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? firm,  int? accountSize,  double? dailyLossLimitPct,  double? maxDrawdownPct,  DrawdownType drawdownType,  TrailingBasis trailingBasis,  double? profitTargetPct)  $default,) {final _that = this;
switch (_that) {
case _PropRules():
return $default(_that.firm,_that.accountSize,_that.dailyLossLimitPct,_that.maxDrawdownPct,_that.drawdownType,_that.trailingBasis,_that.profitTargetPct);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? firm,  int? accountSize,  double? dailyLossLimitPct,  double? maxDrawdownPct,  DrawdownType drawdownType,  TrailingBasis trailingBasis,  double? profitTargetPct)?  $default,) {final _that = this;
switch (_that) {
case _PropRules() when $default != null:
return $default(_that.firm,_that.accountSize,_that.dailyLossLimitPct,_that.maxDrawdownPct,_that.drawdownType,_that.trailingBasis,_that.profitTargetPct);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PropRules extends PropRules {
  const _PropRules({this.firm, this.accountSize, this.dailyLossLimitPct, this.maxDrawdownPct, this.drawdownType = DrawdownType.fixed, this.trailingBasis = TrailingBasis.equity, this.profitTargetPct}): super._();
  factory _PropRules.fromJson(Map<String, dynamic> json) => _$PropRulesFromJson(json);

/// Free text, shown as a comment in profile.doji.
@override final  String? firm;
@override final  int? accountSize;
/// Most you may lose in one day, % of the account.
@override final  double? dailyLossLimitPct;
/// Most the account may fall, % of the account. How it is measured is
/// [drawdownType] (and [trailingBasis] when trailing).
@override final  double? maxDrawdownPct;
/// Static unless the user says otherwise.
@override@JsonKey() final  DrawdownType drawdownType;
/// Only read when [drawdownType] is trailing. Equity is the stricter
/// (open profit raises the high), so it is the default.
@override@JsonKey() final  TrailingBasis trailingBasis;
/// Profit that passes the challenge, %. Null on funded accounts.
@override final  double? profitTargetPct;

/// Create a copy of PropRules
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PropRulesCopyWith<_PropRules> get copyWith => __$PropRulesCopyWithImpl<_PropRules>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PropRulesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PropRules&&(identical(other.firm, firm) || other.firm == firm)&&(identical(other.accountSize, accountSize) || other.accountSize == accountSize)&&(identical(other.dailyLossLimitPct, dailyLossLimitPct) || other.dailyLossLimitPct == dailyLossLimitPct)&&(identical(other.maxDrawdownPct, maxDrawdownPct) || other.maxDrawdownPct == maxDrawdownPct)&&(identical(other.drawdownType, drawdownType) || other.drawdownType == drawdownType)&&(identical(other.trailingBasis, trailingBasis) || other.trailingBasis == trailingBasis)&&(identical(other.profitTargetPct, profitTargetPct) || other.profitTargetPct == profitTargetPct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,firm,accountSize,dailyLossLimitPct,maxDrawdownPct,drawdownType,trailingBasis,profitTargetPct);

@override
String toString() {
  return 'PropRules(firm: $firm, accountSize: $accountSize, dailyLossLimitPct: $dailyLossLimitPct, maxDrawdownPct: $maxDrawdownPct, drawdownType: $drawdownType, trailingBasis: $trailingBasis, profitTargetPct: $profitTargetPct)';
}


}

/// @nodoc
abstract mixin class _$PropRulesCopyWith<$Res> implements $PropRulesCopyWith<$Res> {
  factory _$PropRulesCopyWith(_PropRules value, $Res Function(_PropRules) _then) = __$PropRulesCopyWithImpl;
@override @useResult
$Res call({
 String? firm, int? accountSize, double? dailyLossLimitPct, double? maxDrawdownPct, DrawdownType drawdownType, TrailingBasis trailingBasis, double? profitTargetPct
});




}
/// @nodoc
class __$PropRulesCopyWithImpl<$Res>
    implements _$PropRulesCopyWith<$Res> {
  __$PropRulesCopyWithImpl(this._self, this._then);

  final _PropRules _self;
  final $Res Function(_PropRules) _then;

/// Create a copy of PropRules
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? firm = freezed,Object? accountSize = freezed,Object? dailyLossLimitPct = freezed,Object? maxDrawdownPct = freezed,Object? drawdownType = null,Object? trailingBasis = null,Object? profitTargetPct = freezed,}) {
  return _then(_PropRules(
firm: freezed == firm ? _self.firm : firm // ignore: cast_nullable_to_non_nullable
as String?,accountSize: freezed == accountSize ? _self.accountSize : accountSize // ignore: cast_nullable_to_non_nullable
as int?,dailyLossLimitPct: freezed == dailyLossLimitPct ? _self.dailyLossLimitPct : dailyLossLimitPct // ignore: cast_nullable_to_non_nullable
as double?,maxDrawdownPct: freezed == maxDrawdownPct ? _self.maxDrawdownPct : maxDrawdownPct // ignore: cast_nullable_to_non_nullable
as double?,drawdownType: null == drawdownType ? _self.drawdownType : drawdownType // ignore: cast_nullable_to_non_nullable
as DrawdownType,trailingBasis: null == trailingBasis ? _self.trailingBasis : trailingBasis // ignore: cast_nullable_to_non_nullable
as TrailingBasis,profitTargetPct: freezed == profitTargetPct ? _self.profitTargetPct : profitTargetPct // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
