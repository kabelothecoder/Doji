// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trading_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TradingAccount {

 String get id; String get name; AccountKind get kind;/// USD | ZAR | EUR | GBP. Position sizing converts into it.
 String get accountCurrency;/// The starting balance in [accountCurrency]. The only size: the prop
/// drawdown and Home's loss % are both measured against it. Null when the
/// trader has not given one (loss % then comes from risk per trade).
 double? get startingSize;/// Instrument symbols ('XAUUSD', 'R_75'), or the trader's own.
 List<String> get instruments;/// Risk % per trade, max trades a day, daily loss limit %.
 TradingRules? get rules;/// A prop challenge's own limits (percentages of [startingSize]).
 PropRules? get prop; StrategyProfile? get strategy;/// The MT5 account behind this one, linked through MetaRPC. The terminal
/// and the password stay server-side (`supabase/functions/mt5`); the app
/// keeps only what it shows.
 BrokerLink? get brokerLink;
/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TradingAccountCopyWith<TradingAccount> get copyWith => _$TradingAccountCopyWithImpl<TradingAccount>(this as TradingAccount, _$identity);

  /// Serializes this TradingAccount to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TradingAccount&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.accountCurrency, accountCurrency) || other.accountCurrency == accountCurrency)&&(identical(other.startingSize, startingSize) || other.startingSize == startingSize)&&const DeepCollectionEquality().equals(other.instruments, instruments)&&(identical(other.rules, rules) || other.rules == rules)&&(identical(other.prop, prop) || other.prop == prop)&&(identical(other.strategy, strategy) || other.strategy == strategy)&&(identical(other.brokerLink, brokerLink) || other.brokerLink == brokerLink));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,kind,accountCurrency,startingSize,const DeepCollectionEquality().hash(instruments),rules,prop,strategy,brokerLink);

@override
String toString() {
  return 'TradingAccount(id: $id, name: $name, kind: $kind, accountCurrency: $accountCurrency, startingSize: $startingSize, instruments: $instruments, rules: $rules, prop: $prop, strategy: $strategy, brokerLink: $brokerLink)';
}


}

/// @nodoc
abstract mixin class $TradingAccountCopyWith<$Res>  {
  factory $TradingAccountCopyWith(TradingAccount value, $Res Function(TradingAccount) _then) = _$TradingAccountCopyWithImpl;
@useResult
$Res call({
 String id, String name, AccountKind kind, String accountCurrency, double? startingSize, List<String> instruments, TradingRules? rules, PropRules? prop, StrategyProfile? strategy, BrokerLink? brokerLink
});


$TradingRulesCopyWith<$Res>? get rules;$PropRulesCopyWith<$Res>? get prop;$StrategyProfileCopyWith<$Res>? get strategy;$BrokerLinkCopyWith<$Res>? get brokerLink;

}
/// @nodoc
class _$TradingAccountCopyWithImpl<$Res>
    implements $TradingAccountCopyWith<$Res> {
  _$TradingAccountCopyWithImpl(this._self, this._then);

  final TradingAccount _self;
  final $Res Function(TradingAccount) _then;

/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? kind = null,Object? accountCurrency = null,Object? startingSize = freezed,Object? instruments = null,Object? rules = freezed,Object? prop = freezed,Object? strategy = freezed,Object? brokerLink = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AccountKind,accountCurrency: null == accountCurrency ? _self.accountCurrency : accountCurrency // ignore: cast_nullable_to_non_nullable
as String,startingSize: freezed == startingSize ? _self.startingSize : startingSize // ignore: cast_nullable_to_non_nullable
as double?,instruments: null == instruments ? _self.instruments : instruments // ignore: cast_nullable_to_non_nullable
as List<String>,rules: freezed == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as TradingRules?,prop: freezed == prop ? _self.prop : prop // ignore: cast_nullable_to_non_nullable
as PropRules?,strategy: freezed == strategy ? _self.strategy : strategy // ignore: cast_nullable_to_non_nullable
as StrategyProfile?,brokerLink: freezed == brokerLink ? _self.brokerLink : brokerLink // ignore: cast_nullable_to_non_nullable
as BrokerLink?,
  ));
}
/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TradingRulesCopyWith<$Res>? get rules {
    if (_self.rules == null) {
    return null;
  }

  return $TradingRulesCopyWith<$Res>(_self.rules!, (value) {
    return _then(_self.copyWith(rules: value));
  });
}/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PropRulesCopyWith<$Res>? get prop {
    if (_self.prop == null) {
    return null;
  }

  return $PropRulesCopyWith<$Res>(_self.prop!, (value) {
    return _then(_self.copyWith(prop: value));
  });
}/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StrategyProfileCopyWith<$Res>? get strategy {
    if (_self.strategy == null) {
    return null;
  }

  return $StrategyProfileCopyWith<$Res>(_self.strategy!, (value) {
    return _then(_self.copyWith(strategy: value));
  });
}/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BrokerLinkCopyWith<$Res>? get brokerLink {
    if (_self.brokerLink == null) {
    return null;
  }

  return $BrokerLinkCopyWith<$Res>(_self.brokerLink!, (value) {
    return _then(_self.copyWith(brokerLink: value));
  });
}
}


/// Adds pattern-matching-related methods to [TradingAccount].
extension TradingAccountPatterns on TradingAccount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TradingAccount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TradingAccount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TradingAccount value)  $default,){
final _that = this;
switch (_that) {
case _TradingAccount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TradingAccount value)?  $default,){
final _that = this;
switch (_that) {
case _TradingAccount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  AccountKind kind,  String accountCurrency,  double? startingSize,  List<String> instruments,  TradingRules? rules,  PropRules? prop,  StrategyProfile? strategy,  BrokerLink? brokerLink)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TradingAccount() when $default != null:
return $default(_that.id,_that.name,_that.kind,_that.accountCurrency,_that.startingSize,_that.instruments,_that.rules,_that.prop,_that.strategy,_that.brokerLink);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  AccountKind kind,  String accountCurrency,  double? startingSize,  List<String> instruments,  TradingRules? rules,  PropRules? prop,  StrategyProfile? strategy,  BrokerLink? brokerLink)  $default,) {final _that = this;
switch (_that) {
case _TradingAccount():
return $default(_that.id,_that.name,_that.kind,_that.accountCurrency,_that.startingSize,_that.instruments,_that.rules,_that.prop,_that.strategy,_that.brokerLink);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  AccountKind kind,  String accountCurrency,  double? startingSize,  List<String> instruments,  TradingRules? rules,  PropRules? prop,  StrategyProfile? strategy,  BrokerLink? brokerLink)?  $default,) {final _that = this;
switch (_that) {
case _TradingAccount() when $default != null:
return $default(_that.id,_that.name,_that.kind,_that.accountCurrency,_that.startingSize,_that.instruments,_that.rules,_that.prop,_that.strategy,_that.brokerLink);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TradingAccount extends TradingAccount {
  const _TradingAccount({required this.id, required this.name, this.kind = AccountKind.personal, this.accountCurrency = 'USD', this.startingSize, final  List<String> instruments = const <String>[], this.rules, this.prop, this.strategy, this.brokerLink}): _instruments = instruments,super._();
  factory _TradingAccount.fromJson(Map<String, dynamic> json) => _$TradingAccountFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  AccountKind kind;
/// USD | ZAR | EUR | GBP. Position sizing converts into it.
@override@JsonKey() final  String accountCurrency;
/// The starting balance in [accountCurrency]. The only size: the prop
/// drawdown and Home's loss % are both measured against it. Null when the
/// trader has not given one (loss % then comes from risk per trade).
@override final  double? startingSize;
/// Instrument symbols ('XAUUSD', 'R_75'), or the trader's own.
 final  List<String> _instruments;
/// Instrument symbols ('XAUUSD', 'R_75'), or the trader's own.
@override@JsonKey() List<String> get instruments {
  if (_instruments is EqualUnmodifiableListView) return _instruments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_instruments);
}

/// Risk % per trade, max trades a day, daily loss limit %.
@override final  TradingRules? rules;
/// A prop challenge's own limits (percentages of [startingSize]).
@override final  PropRules? prop;
@override final  StrategyProfile? strategy;
/// The MT5 account behind this one, linked through MetaRPC. The terminal
/// and the password stay server-side (`supabase/functions/mt5`); the app
/// keeps only what it shows.
@override final  BrokerLink? brokerLink;

/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TradingAccountCopyWith<_TradingAccount> get copyWith => __$TradingAccountCopyWithImpl<_TradingAccount>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TradingAccountToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TradingAccount&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.accountCurrency, accountCurrency) || other.accountCurrency == accountCurrency)&&(identical(other.startingSize, startingSize) || other.startingSize == startingSize)&&const DeepCollectionEquality().equals(other._instruments, _instruments)&&(identical(other.rules, rules) || other.rules == rules)&&(identical(other.prop, prop) || other.prop == prop)&&(identical(other.strategy, strategy) || other.strategy == strategy)&&(identical(other.brokerLink, brokerLink) || other.brokerLink == brokerLink));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,kind,accountCurrency,startingSize,const DeepCollectionEquality().hash(_instruments),rules,prop,strategy,brokerLink);

@override
String toString() {
  return 'TradingAccount(id: $id, name: $name, kind: $kind, accountCurrency: $accountCurrency, startingSize: $startingSize, instruments: $instruments, rules: $rules, prop: $prop, strategy: $strategy, brokerLink: $brokerLink)';
}


}

/// @nodoc
abstract mixin class _$TradingAccountCopyWith<$Res> implements $TradingAccountCopyWith<$Res> {
  factory _$TradingAccountCopyWith(_TradingAccount value, $Res Function(_TradingAccount) _then) = __$TradingAccountCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, AccountKind kind, String accountCurrency, double? startingSize, List<String> instruments, TradingRules? rules, PropRules? prop, StrategyProfile? strategy, BrokerLink? brokerLink
});


@override $TradingRulesCopyWith<$Res>? get rules;@override $PropRulesCopyWith<$Res>? get prop;@override $StrategyProfileCopyWith<$Res>? get strategy;@override $BrokerLinkCopyWith<$Res>? get brokerLink;

}
/// @nodoc
class __$TradingAccountCopyWithImpl<$Res>
    implements _$TradingAccountCopyWith<$Res> {
  __$TradingAccountCopyWithImpl(this._self, this._then);

  final _TradingAccount _self;
  final $Res Function(_TradingAccount) _then;

/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? kind = null,Object? accountCurrency = null,Object? startingSize = freezed,Object? instruments = null,Object? rules = freezed,Object? prop = freezed,Object? strategy = freezed,Object? brokerLink = freezed,}) {
  return _then(_TradingAccount(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AccountKind,accountCurrency: null == accountCurrency ? _self.accountCurrency : accountCurrency // ignore: cast_nullable_to_non_nullable
as String,startingSize: freezed == startingSize ? _self.startingSize : startingSize // ignore: cast_nullable_to_non_nullable
as double?,instruments: null == instruments ? _self._instruments : instruments // ignore: cast_nullable_to_non_nullable
as List<String>,rules: freezed == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as TradingRules?,prop: freezed == prop ? _self.prop : prop // ignore: cast_nullable_to_non_nullable
as PropRules?,strategy: freezed == strategy ? _self.strategy : strategy // ignore: cast_nullable_to_non_nullable
as StrategyProfile?,brokerLink: freezed == brokerLink ? _self.brokerLink : brokerLink // ignore: cast_nullable_to_non_nullable
as BrokerLink?,
  ));
}

/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TradingRulesCopyWith<$Res>? get rules {
    if (_self.rules == null) {
    return null;
  }

  return $TradingRulesCopyWith<$Res>(_self.rules!, (value) {
    return _then(_self.copyWith(rules: value));
  });
}/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PropRulesCopyWith<$Res>? get prop {
    if (_self.prop == null) {
    return null;
  }

  return $PropRulesCopyWith<$Res>(_self.prop!, (value) {
    return _then(_self.copyWith(prop: value));
  });
}/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StrategyProfileCopyWith<$Res>? get strategy {
    if (_self.strategy == null) {
    return null;
  }

  return $StrategyProfileCopyWith<$Res>(_self.strategy!, (value) {
    return _then(_self.copyWith(strategy: value));
  });
}/// Create a copy of TradingAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BrokerLinkCopyWith<$Res>? get brokerLink {
    if (_self.brokerLink == null) {
    return null;
  }

  return $BrokerLinkCopyWith<$Res>(_self.brokerLink!, (value) {
    return _then(_self.copyWith(brokerLink: value));
  });
}
}


/// @nodoc
mixin _$BrokerLink {

 String get server; int get login;
/// Create a copy of BrokerLink
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BrokerLinkCopyWith<BrokerLink> get copyWith => _$BrokerLinkCopyWithImpl<BrokerLink>(this as BrokerLink, _$identity);

  /// Serializes this BrokerLink to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BrokerLink&&(identical(other.server, server) || other.server == server)&&(identical(other.login, login) || other.login == login));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,server,login);

@override
String toString() {
  return 'BrokerLink(server: $server, login: $login)';
}


}

/// @nodoc
abstract mixin class $BrokerLinkCopyWith<$Res>  {
  factory $BrokerLinkCopyWith(BrokerLink value, $Res Function(BrokerLink) _then) = _$BrokerLinkCopyWithImpl;
@useResult
$Res call({
 String server, int login
});




}
/// @nodoc
class _$BrokerLinkCopyWithImpl<$Res>
    implements $BrokerLinkCopyWith<$Res> {
  _$BrokerLinkCopyWithImpl(this._self, this._then);

  final BrokerLink _self;
  final $Res Function(BrokerLink) _then;

/// Create a copy of BrokerLink
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? server = null,Object? login = null,}) {
  return _then(_self.copyWith(
server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String,login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BrokerLink].
extension BrokerLinkPatterns on BrokerLink {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BrokerLink value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BrokerLink() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BrokerLink value)  $default,){
final _that = this;
switch (_that) {
case _BrokerLink():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BrokerLink value)?  $default,){
final _that = this;
switch (_that) {
case _BrokerLink() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String server,  int login)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BrokerLink() when $default != null:
return $default(_that.server,_that.login);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String server,  int login)  $default,) {final _that = this;
switch (_that) {
case _BrokerLink():
return $default(_that.server,_that.login);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String server,  int login)?  $default,) {final _that = this;
switch (_that) {
case _BrokerLink() when $default != null:
return $default(_that.server,_that.login);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BrokerLink implements BrokerLink {
  const _BrokerLink({required this.server, required this.login});
  factory _BrokerLink.fromJson(Map<String, dynamic> json) => _$BrokerLinkFromJson(json);

@override final  String server;
@override final  int login;

/// Create a copy of BrokerLink
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BrokerLinkCopyWith<_BrokerLink> get copyWith => __$BrokerLinkCopyWithImpl<_BrokerLink>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BrokerLinkToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BrokerLink&&(identical(other.server, server) || other.server == server)&&(identical(other.login, login) || other.login == login));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,server,login);

@override
String toString() {
  return 'BrokerLink(server: $server, login: $login)';
}


}

/// @nodoc
abstract mixin class _$BrokerLinkCopyWith<$Res> implements $BrokerLinkCopyWith<$Res> {
  factory _$BrokerLinkCopyWith(_BrokerLink value, $Res Function(_BrokerLink) _then) = __$BrokerLinkCopyWithImpl;
@override @useResult
$Res call({
 String server, int login
});




}
/// @nodoc
class __$BrokerLinkCopyWithImpl<$Res>
    implements _$BrokerLinkCopyWith<$Res> {
  __$BrokerLinkCopyWithImpl(this._self, this._then);

  final _BrokerLink _self;
  final $Res Function(_BrokerLink) _then;

/// Create a copy of BrokerLink
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? server = null,Object? login = null,}) {
  return _then(_BrokerLink(
server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String,login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$StrategyCondition {

 ConditionKind get kind;/// [ConditionKind.session]: sydney | tokyo | london | new_york. Null = any of
/// the trader's sessions.
 String? get session;/// [ConditionKind.rangeBreak]: also wait for the close back beyond the level.
 bool get closeBack;/// [ConditionKind.manual]: the rule in the trader's words.
 String? get text;
/// Create a copy of StrategyCondition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StrategyConditionCopyWith<StrategyCondition> get copyWith => _$StrategyConditionCopyWithImpl<StrategyCondition>(this as StrategyCondition, _$identity);

  /// Serializes this StrategyCondition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StrategyCondition&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.session, session) || other.session == session)&&(identical(other.closeBack, closeBack) || other.closeBack == closeBack)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,session,closeBack,text);

@override
String toString() {
  return 'StrategyCondition(kind: $kind, session: $session, closeBack: $closeBack, text: $text)';
}


}

/// @nodoc
abstract mixin class $StrategyConditionCopyWith<$Res>  {
  factory $StrategyConditionCopyWith(StrategyCondition value, $Res Function(StrategyCondition) _then) = _$StrategyConditionCopyWithImpl;
@useResult
$Res call({
 ConditionKind kind, String? session, bool closeBack, String? text
});




}
/// @nodoc
class _$StrategyConditionCopyWithImpl<$Res>
    implements $StrategyConditionCopyWith<$Res> {
  _$StrategyConditionCopyWithImpl(this._self, this._then);

  final StrategyCondition _self;
  final $Res Function(StrategyCondition) _then;

/// Create a copy of StrategyCondition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? session = freezed,Object? closeBack = null,Object? text = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ConditionKind,session: freezed == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as String?,closeBack: null == closeBack ? _self.closeBack : closeBack // ignore: cast_nullable_to_non_nullable
as bool,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StrategyCondition].
extension StrategyConditionPatterns on StrategyCondition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StrategyCondition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StrategyCondition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StrategyCondition value)  $default,){
final _that = this;
switch (_that) {
case _StrategyCondition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StrategyCondition value)?  $default,){
final _that = this;
switch (_that) {
case _StrategyCondition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ConditionKind kind,  String? session,  bool closeBack,  String? text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StrategyCondition() when $default != null:
return $default(_that.kind,_that.session,_that.closeBack,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ConditionKind kind,  String? session,  bool closeBack,  String? text)  $default,) {final _that = this;
switch (_that) {
case _StrategyCondition():
return $default(_that.kind,_that.session,_that.closeBack,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ConditionKind kind,  String? session,  bool closeBack,  String? text)?  $default,) {final _that = this;
switch (_that) {
case _StrategyCondition() when $default != null:
return $default(_that.kind,_that.session,_that.closeBack,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StrategyCondition implements StrategyCondition {
  const _StrategyCondition({required this.kind, this.session, this.closeBack = false, this.text});
  factory _StrategyCondition.fromJson(Map<String, dynamic> json) => _$StrategyConditionFromJson(json);

@override final  ConditionKind kind;
/// [ConditionKind.session]: sydney | tokyo | london | new_york. Null = any of
/// the trader's sessions.
@override final  String? session;
/// [ConditionKind.rangeBreak]: also wait for the close back beyond the level.
@override@JsonKey() final  bool closeBack;
/// [ConditionKind.manual]: the rule in the trader's words.
@override final  String? text;

/// Create a copy of StrategyCondition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StrategyConditionCopyWith<_StrategyCondition> get copyWith => __$StrategyConditionCopyWithImpl<_StrategyCondition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StrategyConditionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StrategyCondition&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.session, session) || other.session == session)&&(identical(other.closeBack, closeBack) || other.closeBack == closeBack)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,session,closeBack,text);

@override
String toString() {
  return 'StrategyCondition(kind: $kind, session: $session, closeBack: $closeBack, text: $text)';
}


}

/// @nodoc
abstract mixin class _$StrategyConditionCopyWith<$Res> implements $StrategyConditionCopyWith<$Res> {
  factory _$StrategyConditionCopyWith(_StrategyCondition value, $Res Function(_StrategyCondition) _then) = __$StrategyConditionCopyWithImpl;
@override @useResult
$Res call({
 ConditionKind kind, String? session, bool closeBack, String? text
});




}
/// @nodoc
class __$StrategyConditionCopyWithImpl<$Res>
    implements _$StrategyConditionCopyWith<$Res> {
  __$StrategyConditionCopyWithImpl(this._self, this._then);

  final _StrategyCondition _self;
  final $Res Function(_StrategyCondition) _then;

/// Create a copy of StrategyCondition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? session = freezed,Object? closeBack = null,Object? text = freezed,}) {
  return _then(_StrategyCondition(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ConditionKind,session: freezed == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as String?,closeBack: null == closeBack ? _self.closeBack : closeBack // ignore: cast_nullable_to_non_nullable
as bool,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
