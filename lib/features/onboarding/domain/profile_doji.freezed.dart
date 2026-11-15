// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_doji.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProfileDoji {

 String? get name;/// lt_6m | 6_24m | 2_5y | 5y_plus
 String? get experience;/// scalper | day_trader | swing | undecided; several joined with ",".
 String? get style;/// sydney | tokyo | london | new_york | around_job
 List<String> get sessions;/// not_flexible | semi_flexible | fully_flexible: how often the trader can look at the
/// charts in those hours (`availabilityFit`). Nullable: no version bump.
 String? get availability;/// IANA id when detected (e.g. Africa/Johannesburg).
 String? get timeZone; int? get utcOffsetMinutes;/// prop_challenge | grow_account | consistent | make_it_my_job | learn
 String? get goal;/// revenge | fomo | overtrading | hesitation | moving_stop | oversizing | bored
 List<String> get struggles;/// careful | balanced | aggressive (the risk step). Feeds `recommendPlan`.
 String? get riskAppetite;/// How the trader usually funds a personal account: lt_500 | 500_5k | 5k_25k | 25k_plus.
/// TODO(backend): store on the account for plan offers.
 String? get usualDeposit;/// The trader's accounts, each with its own rules and strategy. Onboarding
/// creates the first one.
 List<TradingAccount> get accounts;/// The account everything reads. Falls back to the first one.
 String? get activeAccountId; CoachProfile? get coach;/// "The Open" ritual time, local HH:mm.
 String? get theOpenTime; bool? get notificationsAllowed; DateTime? get pledgedAt; int get onboardingVersion;/// Everyone starts at M1 · Impulsive.
 String get rank;/// Kept on device only ("continue without account"); sync when signed in.
 bool get pendingSync; DateTime? get completedAt;
/// Create a copy of ProfileDoji
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileDojiCopyWith<ProfileDoji> get copyWith => _$ProfileDojiCopyWithImpl<ProfileDoji>(this as ProfileDoji, _$identity);

  /// Serializes this ProfileDoji to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileDoji&&(identical(other.name, name) || other.name == name)&&(identical(other.experience, experience) || other.experience == experience)&&(identical(other.style, style) || other.style == style)&&const DeepCollectionEquality().equals(other.sessions, sessions)&&(identical(other.availability, availability) || other.availability == availability)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes)&&(identical(other.goal, goal) || other.goal == goal)&&const DeepCollectionEquality().equals(other.struggles, struggles)&&(identical(other.riskAppetite, riskAppetite) || other.riskAppetite == riskAppetite)&&(identical(other.usualDeposit, usualDeposit) || other.usualDeposit == usualDeposit)&&const DeepCollectionEquality().equals(other.accounts, accounts)&&(identical(other.activeAccountId, activeAccountId) || other.activeAccountId == activeAccountId)&&(identical(other.coach, coach) || other.coach == coach)&&(identical(other.theOpenTime, theOpenTime) || other.theOpenTime == theOpenTime)&&(identical(other.notificationsAllowed, notificationsAllowed) || other.notificationsAllowed == notificationsAllowed)&&(identical(other.pledgedAt, pledgedAt) || other.pledgedAt == pledgedAt)&&(identical(other.onboardingVersion, onboardingVersion) || other.onboardingVersion == onboardingVersion)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.pendingSync, pendingSync) || other.pendingSync == pendingSync)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,name,experience,style,const DeepCollectionEquality().hash(sessions),availability,timeZone,utcOffsetMinutes,goal,const DeepCollectionEquality().hash(struggles),riskAppetite,usualDeposit,const DeepCollectionEquality().hash(accounts),activeAccountId,coach,theOpenTime,notificationsAllowed,pledgedAt,onboardingVersion,rank,pendingSync,completedAt]);

@override
String toString() {
  return 'ProfileDoji(name: $name, experience: $experience, style: $style, sessions: $sessions, availability: $availability, timeZone: $timeZone, utcOffsetMinutes: $utcOffsetMinutes, goal: $goal, struggles: $struggles, riskAppetite: $riskAppetite, usualDeposit: $usualDeposit, accounts: $accounts, activeAccountId: $activeAccountId, coach: $coach, theOpenTime: $theOpenTime, notificationsAllowed: $notificationsAllowed, pledgedAt: $pledgedAt, onboardingVersion: $onboardingVersion, rank: $rank, pendingSync: $pendingSync, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $ProfileDojiCopyWith<$Res>  {
  factory $ProfileDojiCopyWith(ProfileDoji value, $Res Function(ProfileDoji) _then) = _$ProfileDojiCopyWithImpl;
@useResult
$Res call({
 String? name, String? experience, String? style, List<String> sessions, String? availability, String? timeZone, int? utcOffsetMinutes, String? goal, List<String> struggles, String? riskAppetite, String? usualDeposit, List<TradingAccount> accounts, String? activeAccountId, CoachProfile? coach, String? theOpenTime, bool? notificationsAllowed, DateTime? pledgedAt, int onboardingVersion, String rank, bool pendingSync, DateTime? completedAt
});


$CoachProfileCopyWith<$Res>? get coach;

}
/// @nodoc
class _$ProfileDojiCopyWithImpl<$Res>
    implements $ProfileDojiCopyWith<$Res> {
  _$ProfileDojiCopyWithImpl(this._self, this._then);

  final ProfileDoji _self;
  final $Res Function(ProfileDoji) _then;

/// Create a copy of ProfileDoji
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? experience = freezed,Object? style = freezed,Object? sessions = null,Object? availability = freezed,Object? timeZone = freezed,Object? utcOffsetMinutes = freezed,Object? goal = freezed,Object? struggles = null,Object? riskAppetite = freezed,Object? usualDeposit = freezed,Object? accounts = null,Object? activeAccountId = freezed,Object? coach = freezed,Object? theOpenTime = freezed,Object? notificationsAllowed = freezed,Object? pledgedAt = freezed,Object? onboardingVersion = null,Object? rank = null,Object? pendingSync = null,Object? completedAt = freezed,}) {
  return _then(_self.copyWith(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,experience: freezed == experience ? _self.experience : experience // ignore: cast_nullable_to_non_nullable
as String?,style: freezed == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as String?,sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<String>,availability: freezed == availability ? _self.availability : availability // ignore: cast_nullable_to_non_nullable
as String?,timeZone: freezed == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String?,utcOffsetMinutes: freezed == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,goal: freezed == goal ? _self.goal : goal // ignore: cast_nullable_to_non_nullable
as String?,struggles: null == struggles ? _self.struggles : struggles // ignore: cast_nullable_to_non_nullable
as List<String>,riskAppetite: freezed == riskAppetite ? _self.riskAppetite : riskAppetite // ignore: cast_nullable_to_non_nullable
as String?,usualDeposit: freezed == usualDeposit ? _self.usualDeposit : usualDeposit // ignore: cast_nullable_to_non_nullable
as String?,accounts: null == accounts ? _self.accounts : accounts // ignore: cast_nullable_to_non_nullable
as List<TradingAccount>,activeAccountId: freezed == activeAccountId ? _self.activeAccountId : activeAccountId // ignore: cast_nullable_to_non_nullable
as String?,coach: freezed == coach ? _self.coach : coach // ignore: cast_nullable_to_non_nullable
as CoachProfile?,theOpenTime: freezed == theOpenTime ? _self.theOpenTime : theOpenTime // ignore: cast_nullable_to_non_nullable
as String?,notificationsAllowed: freezed == notificationsAllowed ? _self.notificationsAllowed : notificationsAllowed // ignore: cast_nullable_to_non_nullable
as bool?,pledgedAt: freezed == pledgedAt ? _self.pledgedAt : pledgedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,onboardingVersion: null == onboardingVersion ? _self.onboardingVersion : onboardingVersion // ignore: cast_nullable_to_non_nullable
as int,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as String,pendingSync: null == pendingSync ? _self.pendingSync : pendingSync // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of ProfileDoji
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CoachProfileCopyWith<$Res>? get coach {
    if (_self.coach == null) {
    return null;
  }

  return $CoachProfileCopyWith<$Res>(_self.coach!, (value) {
    return _then(_self.copyWith(coach: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProfileDoji].
extension ProfileDojiPatterns on ProfileDoji {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileDoji value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileDoji() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileDoji value)  $default,){
final _that = this;
switch (_that) {
case _ProfileDoji():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileDoji value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileDoji() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? name,  String? experience,  String? style,  List<String> sessions,  String? availability,  String? timeZone,  int? utcOffsetMinutes,  String? goal,  List<String> struggles,  String? riskAppetite,  String? usualDeposit,  List<TradingAccount> accounts,  String? activeAccountId,  CoachProfile? coach,  String? theOpenTime,  bool? notificationsAllowed,  DateTime? pledgedAt,  int onboardingVersion,  String rank,  bool pendingSync,  DateTime? completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileDoji() when $default != null:
return $default(_that.name,_that.experience,_that.style,_that.sessions,_that.availability,_that.timeZone,_that.utcOffsetMinutes,_that.goal,_that.struggles,_that.riskAppetite,_that.usualDeposit,_that.accounts,_that.activeAccountId,_that.coach,_that.theOpenTime,_that.notificationsAllowed,_that.pledgedAt,_that.onboardingVersion,_that.rank,_that.pendingSync,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? name,  String? experience,  String? style,  List<String> sessions,  String? availability,  String? timeZone,  int? utcOffsetMinutes,  String? goal,  List<String> struggles,  String? riskAppetite,  String? usualDeposit,  List<TradingAccount> accounts,  String? activeAccountId,  CoachProfile? coach,  String? theOpenTime,  bool? notificationsAllowed,  DateTime? pledgedAt,  int onboardingVersion,  String rank,  bool pendingSync,  DateTime? completedAt)  $default,) {final _that = this;
switch (_that) {
case _ProfileDoji():
return $default(_that.name,_that.experience,_that.style,_that.sessions,_that.availability,_that.timeZone,_that.utcOffsetMinutes,_that.goal,_that.struggles,_that.riskAppetite,_that.usualDeposit,_that.accounts,_that.activeAccountId,_that.coach,_that.theOpenTime,_that.notificationsAllowed,_that.pledgedAt,_that.onboardingVersion,_that.rank,_that.pendingSync,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? name,  String? experience,  String? style,  List<String> sessions,  String? availability,  String? timeZone,  int? utcOffsetMinutes,  String? goal,  List<String> struggles,  String? riskAppetite,  String? usualDeposit,  List<TradingAccount> accounts,  String? activeAccountId,  CoachProfile? coach,  String? theOpenTime,  bool? notificationsAllowed,  DateTime? pledgedAt,  int onboardingVersion,  String rank,  bool pendingSync,  DateTime? completedAt)?  $default,) {final _that = this;
switch (_that) {
case _ProfileDoji() when $default != null:
return $default(_that.name,_that.experience,_that.style,_that.sessions,_that.availability,_that.timeZone,_that.utcOffsetMinutes,_that.goal,_that.struggles,_that.riskAppetite,_that.usualDeposit,_that.accounts,_that.activeAccountId,_that.coach,_that.theOpenTime,_that.notificationsAllowed,_that.pledgedAt,_that.onboardingVersion,_that.rank,_that.pendingSync,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileDoji extends ProfileDoji {
  const _ProfileDoji({this.name, this.experience, this.style, final  List<String> sessions = const <String>[], this.availability, this.timeZone, this.utcOffsetMinutes, this.goal, final  List<String> struggles = const <String>[], this.riskAppetite, this.usualDeposit, final  List<TradingAccount> accounts = const <TradingAccount>[], this.activeAccountId, this.coach, this.theOpenTime, this.notificationsAllowed, this.pledgedAt, this.onboardingVersion = kOnboardingVersion, this.rank = 'M1', this.pendingSync = false, this.completedAt}): _sessions = sessions,_struggles = struggles,_accounts = accounts,super._();
  factory _ProfileDoji.fromJson(Map<String, dynamic> json) => _$ProfileDojiFromJson(json);

@override final  String? name;
/// lt_6m | 6_24m | 2_5y | 5y_plus
@override final  String? experience;
/// scalper | day_trader | swing | undecided; several joined with ",".
@override final  String? style;
/// sydney | tokyo | london | new_york | around_job
 final  List<String> _sessions;
/// sydney | tokyo | london | new_york | around_job
@override@JsonKey() List<String> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}

/// not_flexible | semi_flexible | fully_flexible: how often the trader can look at the
/// charts in those hours (`availabilityFit`). Nullable: no version bump.
@override final  String? availability;
/// IANA id when detected (e.g. Africa/Johannesburg).
@override final  String? timeZone;
@override final  int? utcOffsetMinutes;
/// prop_challenge | grow_account | consistent | make_it_my_job | learn
@override final  String? goal;
/// revenge | fomo | overtrading | hesitation | moving_stop | oversizing | bored
 final  List<String> _struggles;
/// revenge | fomo | overtrading | hesitation | moving_stop | oversizing | bored
@override@JsonKey() List<String> get struggles {
  if (_struggles is EqualUnmodifiableListView) return _struggles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_struggles);
}

/// careful | balanced | aggressive (the risk step). Feeds `recommendPlan`.
@override final  String? riskAppetite;
/// How the trader usually funds a personal account: lt_500 | 500_5k | 5k_25k | 25k_plus.
/// TODO(backend): store on the account for plan offers.
@override final  String? usualDeposit;
/// The trader's accounts, each with its own rules and strategy. Onboarding
/// creates the first one.
 final  List<TradingAccount> _accounts;
/// The trader's accounts, each with its own rules and strategy. Onboarding
/// creates the first one.
@override@JsonKey() List<TradingAccount> get accounts {
  if (_accounts is EqualUnmodifiableListView) return _accounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accounts);
}

/// The account everything reads. Falls back to the first one.
@override final  String? activeAccountId;
@override final  CoachProfile? coach;
/// "The Open" ritual time, local HH:mm.
@override final  String? theOpenTime;
@override final  bool? notificationsAllowed;
@override final  DateTime? pledgedAt;
@override@JsonKey() final  int onboardingVersion;
/// Everyone starts at M1 · Impulsive.
@override@JsonKey() final  String rank;
/// Kept on device only ("continue without account"); sync when signed in.
@override@JsonKey() final  bool pendingSync;
@override final  DateTime? completedAt;

/// Create a copy of ProfileDoji
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileDojiCopyWith<_ProfileDoji> get copyWith => __$ProfileDojiCopyWithImpl<_ProfileDoji>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileDojiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileDoji&&(identical(other.name, name) || other.name == name)&&(identical(other.experience, experience) || other.experience == experience)&&(identical(other.style, style) || other.style == style)&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&(identical(other.availability, availability) || other.availability == availability)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes)&&(identical(other.goal, goal) || other.goal == goal)&&const DeepCollectionEquality().equals(other._struggles, _struggles)&&(identical(other.riskAppetite, riskAppetite) || other.riskAppetite == riskAppetite)&&(identical(other.usualDeposit, usualDeposit) || other.usualDeposit == usualDeposit)&&const DeepCollectionEquality().equals(other._accounts, _accounts)&&(identical(other.activeAccountId, activeAccountId) || other.activeAccountId == activeAccountId)&&(identical(other.coach, coach) || other.coach == coach)&&(identical(other.theOpenTime, theOpenTime) || other.theOpenTime == theOpenTime)&&(identical(other.notificationsAllowed, notificationsAllowed) || other.notificationsAllowed == notificationsAllowed)&&(identical(other.pledgedAt, pledgedAt) || other.pledgedAt == pledgedAt)&&(identical(other.onboardingVersion, onboardingVersion) || other.onboardingVersion == onboardingVersion)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.pendingSync, pendingSync) || other.pendingSync == pendingSync)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,name,experience,style,const DeepCollectionEquality().hash(_sessions),availability,timeZone,utcOffsetMinutes,goal,const DeepCollectionEquality().hash(_struggles),riskAppetite,usualDeposit,const DeepCollectionEquality().hash(_accounts),activeAccountId,coach,theOpenTime,notificationsAllowed,pledgedAt,onboardingVersion,rank,pendingSync,completedAt]);

@override
String toString() {
  return 'ProfileDoji(name: $name, experience: $experience, style: $style, sessions: $sessions, availability: $availability, timeZone: $timeZone, utcOffsetMinutes: $utcOffsetMinutes, goal: $goal, struggles: $struggles, riskAppetite: $riskAppetite, usualDeposit: $usualDeposit, accounts: $accounts, activeAccountId: $activeAccountId, coach: $coach, theOpenTime: $theOpenTime, notificationsAllowed: $notificationsAllowed, pledgedAt: $pledgedAt, onboardingVersion: $onboardingVersion, rank: $rank, pendingSync: $pendingSync, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$ProfileDojiCopyWith<$Res> implements $ProfileDojiCopyWith<$Res> {
  factory _$ProfileDojiCopyWith(_ProfileDoji value, $Res Function(_ProfileDoji) _then) = __$ProfileDojiCopyWithImpl;
@override @useResult
$Res call({
 String? name, String? experience, String? style, List<String> sessions, String? availability, String? timeZone, int? utcOffsetMinutes, String? goal, List<String> struggles, String? riskAppetite, String? usualDeposit, List<TradingAccount> accounts, String? activeAccountId, CoachProfile? coach, String? theOpenTime, bool? notificationsAllowed, DateTime? pledgedAt, int onboardingVersion, String rank, bool pendingSync, DateTime? completedAt
});


@override $CoachProfileCopyWith<$Res>? get coach;

}
/// @nodoc
class __$ProfileDojiCopyWithImpl<$Res>
    implements _$ProfileDojiCopyWith<$Res> {
  __$ProfileDojiCopyWithImpl(this._self, this._then);

  final _ProfileDoji _self;
  final $Res Function(_ProfileDoji) _then;

/// Create a copy of ProfileDoji
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? experience = freezed,Object? style = freezed,Object? sessions = null,Object? availability = freezed,Object? timeZone = freezed,Object? utcOffsetMinutes = freezed,Object? goal = freezed,Object? struggles = null,Object? riskAppetite = freezed,Object? usualDeposit = freezed,Object? accounts = null,Object? activeAccountId = freezed,Object? coach = freezed,Object? theOpenTime = freezed,Object? notificationsAllowed = freezed,Object? pledgedAt = freezed,Object? onboardingVersion = null,Object? rank = null,Object? pendingSync = null,Object? completedAt = freezed,}) {
  return _then(_ProfileDoji(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,experience: freezed == experience ? _self.experience : experience // ignore: cast_nullable_to_non_nullable
as String?,style: freezed == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as String?,sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<String>,availability: freezed == availability ? _self.availability : availability // ignore: cast_nullable_to_non_nullable
as String?,timeZone: freezed == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String?,utcOffsetMinutes: freezed == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,goal: freezed == goal ? _self.goal : goal // ignore: cast_nullable_to_non_nullable
as String?,struggles: null == struggles ? _self._struggles : struggles // ignore: cast_nullable_to_non_nullable
as List<String>,riskAppetite: freezed == riskAppetite ? _self.riskAppetite : riskAppetite // ignore: cast_nullable_to_non_nullable
as String?,usualDeposit: freezed == usualDeposit ? _self.usualDeposit : usualDeposit // ignore: cast_nullable_to_non_nullable
as String?,accounts: null == accounts ? _self._accounts : accounts // ignore: cast_nullable_to_non_nullable
as List<TradingAccount>,activeAccountId: freezed == activeAccountId ? _self.activeAccountId : activeAccountId // ignore: cast_nullable_to_non_nullable
as String?,coach: freezed == coach ? _self.coach : coach // ignore: cast_nullable_to_non_nullable
as CoachProfile?,theOpenTime: freezed == theOpenTime ? _self.theOpenTime : theOpenTime // ignore: cast_nullable_to_non_nullable
as String?,notificationsAllowed: freezed == notificationsAllowed ? _self.notificationsAllowed : notificationsAllowed // ignore: cast_nullable_to_non_nullable
as bool?,pledgedAt: freezed == pledgedAt ? _self.pledgedAt : pledgedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,onboardingVersion: null == onboardingVersion ? _self.onboardingVersion : onboardingVersion // ignore: cast_nullable_to_non_nullable
as int,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as String,pendingSync: null == pendingSync ? _self.pendingSync : pendingSync // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of ProfileDoji
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CoachProfileCopyWith<$Res>? get coach {
    if (_self.coach == null) {
    return null;
  }

  return $CoachProfileCopyWith<$Res>(_self.coach!, (value) {
    return _then(_self.copyWith(coach: value));
  });
}
}


/// @nodoc
mixin _$StrategyProfile {

/// The user's own words (typed or dictated).
 String? get rawText;/// sr | smc_ict | trend_pullback | breakout | none
 String? get template;/// text | voice | template
 String? get source; ParsedStrategy? get parsed;/// What doji measures, in order. Anything it cannot measure is a manual
/// condition ("check on your chart").
 List<StrategyCondition> get conditions;/// How a backtest closes a setup. Null = not set: the backtest asks for it.
 ExitRules? get exits;
/// Create a copy of StrategyProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StrategyProfileCopyWith<StrategyProfile> get copyWith => _$StrategyProfileCopyWithImpl<StrategyProfile>(this as StrategyProfile, _$identity);

  /// Serializes this StrategyProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StrategyProfile&&(identical(other.rawText, rawText) || other.rawText == rawText)&&(identical(other.template, template) || other.template == template)&&(identical(other.source, source) || other.source == source)&&(identical(other.parsed, parsed) || other.parsed == parsed)&&const DeepCollectionEquality().equals(other.conditions, conditions)&&(identical(other.exits, exits) || other.exits == exits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rawText,template,source,parsed,const DeepCollectionEquality().hash(conditions),exits);

@override
String toString() {
  return 'StrategyProfile(rawText: $rawText, template: $template, source: $source, parsed: $parsed, conditions: $conditions, exits: $exits)';
}


}

/// @nodoc
abstract mixin class $StrategyProfileCopyWith<$Res>  {
  factory $StrategyProfileCopyWith(StrategyProfile value, $Res Function(StrategyProfile) _then) = _$StrategyProfileCopyWithImpl;
@useResult
$Res call({
 String? rawText, String? template, String? source, ParsedStrategy? parsed, List<StrategyCondition> conditions, ExitRules? exits
});


$ParsedStrategyCopyWith<$Res>? get parsed;$ExitRulesCopyWith<$Res>? get exits;

}
/// @nodoc
class _$StrategyProfileCopyWithImpl<$Res>
    implements $StrategyProfileCopyWith<$Res> {
  _$StrategyProfileCopyWithImpl(this._self, this._then);

  final StrategyProfile _self;
  final $Res Function(StrategyProfile) _then;

/// Create a copy of StrategyProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rawText = freezed,Object? template = freezed,Object? source = freezed,Object? parsed = freezed,Object? conditions = null,Object? exits = freezed,}) {
  return _then(_self.copyWith(
rawText: freezed == rawText ? _self.rawText : rawText // ignore: cast_nullable_to_non_nullable
as String?,template: freezed == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,parsed: freezed == parsed ? _self.parsed : parsed // ignore: cast_nullable_to_non_nullable
as ParsedStrategy?,conditions: null == conditions ? _self.conditions : conditions // ignore: cast_nullable_to_non_nullable
as List<StrategyCondition>,exits: freezed == exits ? _self.exits : exits // ignore: cast_nullable_to_non_nullable
as ExitRules?,
  ));
}
/// Create a copy of StrategyProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ParsedStrategyCopyWith<$Res>? get parsed {
    if (_self.parsed == null) {
    return null;
  }

  return $ParsedStrategyCopyWith<$Res>(_self.parsed!, (value) {
    return _then(_self.copyWith(parsed: value));
  });
}/// Create a copy of StrategyProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExitRulesCopyWith<$Res>? get exits {
    if (_self.exits == null) {
    return null;
  }

  return $ExitRulesCopyWith<$Res>(_self.exits!, (value) {
    return _then(_self.copyWith(exits: value));
  });
}
}


/// Adds pattern-matching-related methods to [StrategyProfile].
extension StrategyProfilePatterns on StrategyProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StrategyProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StrategyProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StrategyProfile value)  $default,){
final _that = this;
switch (_that) {
case _StrategyProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StrategyProfile value)?  $default,){
final _that = this;
switch (_that) {
case _StrategyProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? rawText,  String? template,  String? source,  ParsedStrategy? parsed,  List<StrategyCondition> conditions,  ExitRules? exits)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StrategyProfile() when $default != null:
return $default(_that.rawText,_that.template,_that.source,_that.parsed,_that.conditions,_that.exits);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? rawText,  String? template,  String? source,  ParsedStrategy? parsed,  List<StrategyCondition> conditions,  ExitRules? exits)  $default,) {final _that = this;
switch (_that) {
case _StrategyProfile():
return $default(_that.rawText,_that.template,_that.source,_that.parsed,_that.conditions,_that.exits);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? rawText,  String? template,  String? source,  ParsedStrategy? parsed,  List<StrategyCondition> conditions,  ExitRules? exits)?  $default,) {final _that = this;
switch (_that) {
case _StrategyProfile() when $default != null:
return $default(_that.rawText,_that.template,_that.source,_that.parsed,_that.conditions,_that.exits);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StrategyProfile implements StrategyProfile {
  const _StrategyProfile({this.rawText, this.template, this.source, this.parsed, final  List<StrategyCondition> conditions = const <StrategyCondition>[], this.exits}): _conditions = conditions;
  factory _StrategyProfile.fromJson(Map<String, dynamic> json) => _$StrategyProfileFromJson(json);

/// The user's own words (typed or dictated).
@override final  String? rawText;
/// sr | smc_ict | trend_pullback | breakout | none
@override final  String? template;
/// text | voice | template
@override final  String? source;
@override final  ParsedStrategy? parsed;
/// What doji measures, in order. Anything it cannot measure is a manual
/// condition ("check on your chart").
 final  List<StrategyCondition> _conditions;
/// What doji measures, in order. Anything it cannot measure is a manual
/// condition ("check on your chart").
@override@JsonKey() List<StrategyCondition> get conditions {
  if (_conditions is EqualUnmodifiableListView) return _conditions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_conditions);
}

/// How a backtest closes a setup. Null = not set: the backtest asks for it.
@override final  ExitRules? exits;

/// Create a copy of StrategyProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StrategyProfileCopyWith<_StrategyProfile> get copyWith => __$StrategyProfileCopyWithImpl<_StrategyProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StrategyProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StrategyProfile&&(identical(other.rawText, rawText) || other.rawText == rawText)&&(identical(other.template, template) || other.template == template)&&(identical(other.source, source) || other.source == source)&&(identical(other.parsed, parsed) || other.parsed == parsed)&&const DeepCollectionEquality().equals(other._conditions, _conditions)&&(identical(other.exits, exits) || other.exits == exits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rawText,template,source,parsed,const DeepCollectionEquality().hash(_conditions),exits);

@override
String toString() {
  return 'StrategyProfile(rawText: $rawText, template: $template, source: $source, parsed: $parsed, conditions: $conditions, exits: $exits)';
}


}

/// @nodoc
abstract mixin class _$StrategyProfileCopyWith<$Res> implements $StrategyProfileCopyWith<$Res> {
  factory _$StrategyProfileCopyWith(_StrategyProfile value, $Res Function(_StrategyProfile) _then) = __$StrategyProfileCopyWithImpl;
@override @useResult
$Res call({
 String? rawText, String? template, String? source, ParsedStrategy? parsed, List<StrategyCondition> conditions, ExitRules? exits
});


@override $ParsedStrategyCopyWith<$Res>? get parsed;@override $ExitRulesCopyWith<$Res>? get exits;

}
/// @nodoc
class __$StrategyProfileCopyWithImpl<$Res>
    implements _$StrategyProfileCopyWith<$Res> {
  __$StrategyProfileCopyWithImpl(this._self, this._then);

  final _StrategyProfile _self;
  final $Res Function(_StrategyProfile) _then;

/// Create a copy of StrategyProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rawText = freezed,Object? template = freezed,Object? source = freezed,Object? parsed = freezed,Object? conditions = null,Object? exits = freezed,}) {
  return _then(_StrategyProfile(
rawText: freezed == rawText ? _self.rawText : rawText // ignore: cast_nullable_to_non_nullable
as String?,template: freezed == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,parsed: freezed == parsed ? _self.parsed : parsed // ignore: cast_nullable_to_non_nullable
as ParsedStrategy?,conditions: null == conditions ? _self._conditions : conditions // ignore: cast_nullable_to_non_nullable
as List<StrategyCondition>,exits: freezed == exits ? _self.exits : exits // ignore: cast_nullable_to_non_nullable
as ExitRules?,
  ));
}

/// Create a copy of StrategyProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ParsedStrategyCopyWith<$Res>? get parsed {
    if (_self.parsed == null) {
    return null;
  }

  return $ParsedStrategyCopyWith<$Res>(_self.parsed!, (value) {
    return _then(_self.copyWith(parsed: value));
  });
}/// Create a copy of StrategyProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExitRulesCopyWith<$Res>? get exits {
    if (_self.exits == null) {
    return null;
  }

  return $ExitRulesCopyWith<$Res>(_self.exits!, (value) {
    return _then(_self.copyWith(exits: value));
  });
}
}


/// @nodoc
mixin _$ExitRules {

 StopRule get stop;/// The stop sits this share of the range past its level (0.1 = 10%).
 double get bufferOfRange;/// Target in R (2 = twice the stop distance).
 double get targetR;/// Closed at the close of this bar count after entry, when set; always closed
/// at the session's end.
 int? get maxBarsOpen;
/// Create a copy of ExitRules
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExitRulesCopyWith<ExitRules> get copyWith => _$ExitRulesCopyWithImpl<ExitRules>(this as ExitRules, _$identity);

  /// Serializes this ExitRules to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExitRules&&(identical(other.stop, stop) || other.stop == stop)&&(identical(other.bufferOfRange, bufferOfRange) || other.bufferOfRange == bufferOfRange)&&(identical(other.targetR, targetR) || other.targetR == targetR)&&(identical(other.maxBarsOpen, maxBarsOpen) || other.maxBarsOpen == maxBarsOpen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stop,bufferOfRange,targetR,maxBarsOpen);

@override
String toString() {
  return 'ExitRules(stop: $stop, bufferOfRange: $bufferOfRange, targetR: $targetR, maxBarsOpen: $maxBarsOpen)';
}


}

/// @nodoc
abstract mixin class $ExitRulesCopyWith<$Res>  {
  factory $ExitRulesCopyWith(ExitRules value, $Res Function(ExitRules) _then) = _$ExitRulesCopyWithImpl;
@useResult
$Res call({
 StopRule stop, double bufferOfRange, double targetR, int? maxBarsOpen
});




}
/// @nodoc
class _$ExitRulesCopyWithImpl<$Res>
    implements $ExitRulesCopyWith<$Res> {
  _$ExitRulesCopyWithImpl(this._self, this._then);

  final ExitRules _self;
  final $Res Function(ExitRules) _then;

/// Create a copy of ExitRules
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stop = null,Object? bufferOfRange = null,Object? targetR = null,Object? maxBarsOpen = freezed,}) {
  return _then(_self.copyWith(
stop: null == stop ? _self.stop : stop // ignore: cast_nullable_to_non_nullable
as StopRule,bufferOfRange: null == bufferOfRange ? _self.bufferOfRange : bufferOfRange // ignore: cast_nullable_to_non_nullable
as double,targetR: null == targetR ? _self.targetR : targetR // ignore: cast_nullable_to_non_nullable
as double,maxBarsOpen: freezed == maxBarsOpen ? _self.maxBarsOpen : maxBarsOpen // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExitRules].
extension ExitRulesPatterns on ExitRules {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExitRules value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExitRules() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExitRules value)  $default,){
final _that = this;
switch (_that) {
case _ExitRules():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExitRules value)?  $default,){
final _that = this;
switch (_that) {
case _ExitRules() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StopRule stop,  double bufferOfRange,  double targetR,  int? maxBarsOpen)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExitRules() when $default != null:
return $default(_that.stop,_that.bufferOfRange,_that.targetR,_that.maxBarsOpen);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StopRule stop,  double bufferOfRange,  double targetR,  int? maxBarsOpen)  $default,) {final _that = this;
switch (_that) {
case _ExitRules():
return $default(_that.stop,_that.bufferOfRange,_that.targetR,_that.maxBarsOpen);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StopRule stop,  double bufferOfRange,  double targetR,  int? maxBarsOpen)?  $default,) {final _that = this;
switch (_that) {
case _ExitRules() when $default != null:
return $default(_that.stop,_that.bufferOfRange,_that.targetR,_that.maxBarsOpen);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExitRules implements ExitRules {
  const _ExitRules({this.stop = StopRule.brokenLevel, this.bufferOfRange = 0.1, this.targetR = 2.0, this.maxBarsOpen});
  factory _ExitRules.fromJson(Map<String, dynamic> json) => _$ExitRulesFromJson(json);

@override@JsonKey() final  StopRule stop;
/// The stop sits this share of the range past its level (0.1 = 10%).
@override@JsonKey() final  double bufferOfRange;
/// Target in R (2 = twice the stop distance).
@override@JsonKey() final  double targetR;
/// Closed at the close of this bar count after entry, when set; always closed
/// at the session's end.
@override final  int? maxBarsOpen;

/// Create a copy of ExitRules
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExitRulesCopyWith<_ExitRules> get copyWith => __$ExitRulesCopyWithImpl<_ExitRules>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExitRulesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExitRules&&(identical(other.stop, stop) || other.stop == stop)&&(identical(other.bufferOfRange, bufferOfRange) || other.bufferOfRange == bufferOfRange)&&(identical(other.targetR, targetR) || other.targetR == targetR)&&(identical(other.maxBarsOpen, maxBarsOpen) || other.maxBarsOpen == maxBarsOpen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stop,bufferOfRange,targetR,maxBarsOpen);

@override
String toString() {
  return 'ExitRules(stop: $stop, bufferOfRange: $bufferOfRange, targetR: $targetR, maxBarsOpen: $maxBarsOpen)';
}


}

/// @nodoc
abstract mixin class _$ExitRulesCopyWith<$Res> implements $ExitRulesCopyWith<$Res> {
  factory _$ExitRulesCopyWith(_ExitRules value, $Res Function(_ExitRules) _then) = __$ExitRulesCopyWithImpl;
@override @useResult
$Res call({
 StopRule stop, double bufferOfRange, double targetR, int? maxBarsOpen
});




}
/// @nodoc
class __$ExitRulesCopyWithImpl<$Res>
    implements _$ExitRulesCopyWith<$Res> {
  __$ExitRulesCopyWithImpl(this._self, this._then);

  final _ExitRules _self;
  final $Res Function(_ExitRules) _then;

/// Create a copy of ExitRules
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stop = null,Object? bufferOfRange = null,Object? targetR = null,Object? maxBarsOpen = freezed,}) {
  return _then(_ExitRules(
stop: null == stop ? _self.stop : stop // ignore: cast_nullable_to_non_nullable
as StopRule,bufferOfRange: null == bufferOfRange ? _self.bufferOfRange : bufferOfRange // ignore: cast_nullable_to_non_nullable
as double,targetR: null == targetR ? _self.targetR : targetR // ignore: cast_nullable_to_non_nullable
as double,maxBarsOpen: freezed == maxBarsOpen ? _self.maxBarsOpen : maxBarsOpen // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$ParsedStrategy {

 String? get setup; String? get timeframe; String? get entry; String? get stop; String? get target;
/// Create a copy of ParsedStrategy
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParsedStrategyCopyWith<ParsedStrategy> get copyWith => _$ParsedStrategyCopyWithImpl<ParsedStrategy>(this as ParsedStrategy, _$identity);

  /// Serializes this ParsedStrategy to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParsedStrategy&&(identical(other.setup, setup) || other.setup == setup)&&(identical(other.timeframe, timeframe) || other.timeframe == timeframe)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.stop, stop) || other.stop == stop)&&(identical(other.target, target) || other.target == target));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,setup,timeframe,entry,stop,target);

@override
String toString() {
  return 'ParsedStrategy(setup: $setup, timeframe: $timeframe, entry: $entry, stop: $stop, target: $target)';
}


}

/// @nodoc
abstract mixin class $ParsedStrategyCopyWith<$Res>  {
  factory $ParsedStrategyCopyWith(ParsedStrategy value, $Res Function(ParsedStrategy) _then) = _$ParsedStrategyCopyWithImpl;
@useResult
$Res call({
 String? setup, String? timeframe, String? entry, String? stop, String? target
});




}
/// @nodoc
class _$ParsedStrategyCopyWithImpl<$Res>
    implements $ParsedStrategyCopyWith<$Res> {
  _$ParsedStrategyCopyWithImpl(this._self, this._then);

  final ParsedStrategy _self;
  final $Res Function(ParsedStrategy) _then;

/// Create a copy of ParsedStrategy
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? setup = freezed,Object? timeframe = freezed,Object? entry = freezed,Object? stop = freezed,Object? target = freezed,}) {
  return _then(_self.copyWith(
setup: freezed == setup ? _self.setup : setup // ignore: cast_nullable_to_non_nullable
as String?,timeframe: freezed == timeframe ? _self.timeframe : timeframe // ignore: cast_nullable_to_non_nullable
as String?,entry: freezed == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as String?,stop: freezed == stop ? _self.stop : stop // ignore: cast_nullable_to_non_nullable
as String?,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ParsedStrategy].
extension ParsedStrategyPatterns on ParsedStrategy {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ParsedStrategy value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ParsedStrategy() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ParsedStrategy value)  $default,){
final _that = this;
switch (_that) {
case _ParsedStrategy():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ParsedStrategy value)?  $default,){
final _that = this;
switch (_that) {
case _ParsedStrategy() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? setup,  String? timeframe,  String? entry,  String? stop,  String? target)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ParsedStrategy() when $default != null:
return $default(_that.setup,_that.timeframe,_that.entry,_that.stop,_that.target);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? setup,  String? timeframe,  String? entry,  String? stop,  String? target)  $default,) {final _that = this;
switch (_that) {
case _ParsedStrategy():
return $default(_that.setup,_that.timeframe,_that.entry,_that.stop,_that.target);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? setup,  String? timeframe,  String? entry,  String? stop,  String? target)?  $default,) {final _that = this;
switch (_that) {
case _ParsedStrategy() when $default != null:
return $default(_that.setup,_that.timeframe,_that.entry,_that.stop,_that.target);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ParsedStrategy extends ParsedStrategy {
  const _ParsedStrategy({this.setup, this.timeframe, this.entry, this.stop, this.target}): super._();
  factory _ParsedStrategy.fromJson(Map<String, dynamic> json) => _$ParsedStrategyFromJson(json);

@override final  String? setup;
@override final  String? timeframe;
@override final  String? entry;
@override final  String? stop;
@override final  String? target;

/// Create a copy of ParsedStrategy
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParsedStrategyCopyWith<_ParsedStrategy> get copyWith => __$ParsedStrategyCopyWithImpl<_ParsedStrategy>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ParsedStrategyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ParsedStrategy&&(identical(other.setup, setup) || other.setup == setup)&&(identical(other.timeframe, timeframe) || other.timeframe == timeframe)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.stop, stop) || other.stop == stop)&&(identical(other.target, target) || other.target == target));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,setup,timeframe,entry,stop,target);

@override
String toString() {
  return 'ParsedStrategy(setup: $setup, timeframe: $timeframe, entry: $entry, stop: $stop, target: $target)';
}


}

/// @nodoc
abstract mixin class _$ParsedStrategyCopyWith<$Res> implements $ParsedStrategyCopyWith<$Res> {
  factory _$ParsedStrategyCopyWith(_ParsedStrategy value, $Res Function(_ParsedStrategy) _then) = __$ParsedStrategyCopyWithImpl;
@override @useResult
$Res call({
 String? setup, String? timeframe, String? entry, String? stop, String? target
});




}
/// @nodoc
class __$ParsedStrategyCopyWithImpl<$Res>
    implements _$ParsedStrategyCopyWith<$Res> {
  __$ParsedStrategyCopyWithImpl(this._self, this._then);

  final _ParsedStrategy _self;
  final $Res Function(_ParsedStrategy) _then;

/// Create a copy of ParsedStrategy
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? setup = freezed,Object? timeframe = freezed,Object? entry = freezed,Object? stop = freezed,Object? target = freezed,}) {
  return _then(_ParsedStrategy(
setup: freezed == setup ? _self.setup : setup // ignore: cast_nullable_to_non_nullable
as String?,timeframe: freezed == timeframe ? _self.timeframe : timeframe // ignore: cast_nullable_to_non_nullable
as String?,entry: freezed == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as String?,stop: freezed == stop ? _self.stop : stop // ignore: cast_nullable_to_non_nullable
as String?,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$TradingRules {

/// Percent of account per trade (1.0 = 1%).
 double? get riskPerTrade; int? get maxTradesPerDay;/// Percent of account; stop for the day at -x%.
 double? get dailyLossLimit;/// Walk-away rules (`WalkAway`), all optional. Stop for the day at +x%.
 double? get dailyGainCap;/// Stop after giving back x% of today's best running result.
 double? get giveBackPct;/// Stop after the first winning trade of the day.
 bool? get oneAndDone;/// Trading window inside the session, local HH:mm (`outsideWindow`). Either may be null.
 String? get noTradesBefore; String? get noTradesAfter;
/// Create a copy of TradingRules
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TradingRulesCopyWith<TradingRules> get copyWith => _$TradingRulesCopyWithImpl<TradingRules>(this as TradingRules, _$identity);

  /// Serializes this TradingRules to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TradingRules&&(identical(other.riskPerTrade, riskPerTrade) || other.riskPerTrade == riskPerTrade)&&(identical(other.maxTradesPerDay, maxTradesPerDay) || other.maxTradesPerDay == maxTradesPerDay)&&(identical(other.dailyLossLimit, dailyLossLimit) || other.dailyLossLimit == dailyLossLimit)&&(identical(other.dailyGainCap, dailyGainCap) || other.dailyGainCap == dailyGainCap)&&(identical(other.giveBackPct, giveBackPct) || other.giveBackPct == giveBackPct)&&(identical(other.oneAndDone, oneAndDone) || other.oneAndDone == oneAndDone)&&(identical(other.noTradesBefore, noTradesBefore) || other.noTradesBefore == noTradesBefore)&&(identical(other.noTradesAfter, noTradesAfter) || other.noTradesAfter == noTradesAfter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,riskPerTrade,maxTradesPerDay,dailyLossLimit,dailyGainCap,giveBackPct,oneAndDone,noTradesBefore,noTradesAfter);

@override
String toString() {
  return 'TradingRules(riskPerTrade: $riskPerTrade, maxTradesPerDay: $maxTradesPerDay, dailyLossLimit: $dailyLossLimit, dailyGainCap: $dailyGainCap, giveBackPct: $giveBackPct, oneAndDone: $oneAndDone, noTradesBefore: $noTradesBefore, noTradesAfter: $noTradesAfter)';
}


}

/// @nodoc
abstract mixin class $TradingRulesCopyWith<$Res>  {
  factory $TradingRulesCopyWith(TradingRules value, $Res Function(TradingRules) _then) = _$TradingRulesCopyWithImpl;
@useResult
$Res call({
 double? riskPerTrade, int? maxTradesPerDay, double? dailyLossLimit, double? dailyGainCap, double? giveBackPct, bool? oneAndDone, String? noTradesBefore, String? noTradesAfter
});




}
/// @nodoc
class _$TradingRulesCopyWithImpl<$Res>
    implements $TradingRulesCopyWith<$Res> {
  _$TradingRulesCopyWithImpl(this._self, this._then);

  final TradingRules _self;
  final $Res Function(TradingRules) _then;

/// Create a copy of TradingRules
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? riskPerTrade = freezed,Object? maxTradesPerDay = freezed,Object? dailyLossLimit = freezed,Object? dailyGainCap = freezed,Object? giveBackPct = freezed,Object? oneAndDone = freezed,Object? noTradesBefore = freezed,Object? noTradesAfter = freezed,}) {
  return _then(_self.copyWith(
riskPerTrade: freezed == riskPerTrade ? _self.riskPerTrade : riskPerTrade // ignore: cast_nullable_to_non_nullable
as double?,maxTradesPerDay: freezed == maxTradesPerDay ? _self.maxTradesPerDay : maxTradesPerDay // ignore: cast_nullable_to_non_nullable
as int?,dailyLossLimit: freezed == dailyLossLimit ? _self.dailyLossLimit : dailyLossLimit // ignore: cast_nullable_to_non_nullable
as double?,dailyGainCap: freezed == dailyGainCap ? _self.dailyGainCap : dailyGainCap // ignore: cast_nullable_to_non_nullable
as double?,giveBackPct: freezed == giveBackPct ? _self.giveBackPct : giveBackPct // ignore: cast_nullable_to_non_nullable
as double?,oneAndDone: freezed == oneAndDone ? _self.oneAndDone : oneAndDone // ignore: cast_nullable_to_non_nullable
as bool?,noTradesBefore: freezed == noTradesBefore ? _self.noTradesBefore : noTradesBefore // ignore: cast_nullable_to_non_nullable
as String?,noTradesAfter: freezed == noTradesAfter ? _self.noTradesAfter : noTradesAfter // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TradingRules].
extension TradingRulesPatterns on TradingRules {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TradingRules value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TradingRules() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TradingRules value)  $default,){
final _that = this;
switch (_that) {
case _TradingRules():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TradingRules value)?  $default,){
final _that = this;
switch (_that) {
case _TradingRules() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double? riskPerTrade,  int? maxTradesPerDay,  double? dailyLossLimit,  double? dailyGainCap,  double? giveBackPct,  bool? oneAndDone,  String? noTradesBefore,  String? noTradesAfter)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TradingRules() when $default != null:
return $default(_that.riskPerTrade,_that.maxTradesPerDay,_that.dailyLossLimit,_that.dailyGainCap,_that.giveBackPct,_that.oneAndDone,_that.noTradesBefore,_that.noTradesAfter);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double? riskPerTrade,  int? maxTradesPerDay,  double? dailyLossLimit,  double? dailyGainCap,  double? giveBackPct,  bool? oneAndDone,  String? noTradesBefore,  String? noTradesAfter)  $default,) {final _that = this;
switch (_that) {
case _TradingRules():
return $default(_that.riskPerTrade,_that.maxTradesPerDay,_that.dailyLossLimit,_that.dailyGainCap,_that.giveBackPct,_that.oneAndDone,_that.noTradesBefore,_that.noTradesAfter);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double? riskPerTrade,  int? maxTradesPerDay,  double? dailyLossLimit,  double? dailyGainCap,  double? giveBackPct,  bool? oneAndDone,  String? noTradesBefore,  String? noTradesAfter)?  $default,) {final _that = this;
switch (_that) {
case _TradingRules() when $default != null:
return $default(_that.riskPerTrade,_that.maxTradesPerDay,_that.dailyLossLimit,_that.dailyGainCap,_that.giveBackPct,_that.oneAndDone,_that.noTradesBefore,_that.noTradesAfter);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TradingRules implements TradingRules {
  const _TradingRules({this.riskPerTrade, this.maxTradesPerDay, this.dailyLossLimit, this.dailyGainCap, this.giveBackPct, this.oneAndDone, this.noTradesBefore, this.noTradesAfter});
  factory _TradingRules.fromJson(Map<String, dynamic> json) => _$TradingRulesFromJson(json);

/// Percent of account per trade (1.0 = 1%).
@override final  double? riskPerTrade;
@override final  int? maxTradesPerDay;
/// Percent of account; stop for the day at -x%.
@override final  double? dailyLossLimit;
/// Walk-away rules (`WalkAway`), all optional. Stop for the day at +x%.
@override final  double? dailyGainCap;
/// Stop after giving back x% of today's best running result.
@override final  double? giveBackPct;
/// Stop after the first winning trade of the day.
@override final  bool? oneAndDone;
/// Trading window inside the session, local HH:mm (`outsideWindow`). Either may be null.
@override final  String? noTradesBefore;
@override final  String? noTradesAfter;

/// Create a copy of TradingRules
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TradingRulesCopyWith<_TradingRules> get copyWith => __$TradingRulesCopyWithImpl<_TradingRules>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TradingRulesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TradingRules&&(identical(other.riskPerTrade, riskPerTrade) || other.riskPerTrade == riskPerTrade)&&(identical(other.maxTradesPerDay, maxTradesPerDay) || other.maxTradesPerDay == maxTradesPerDay)&&(identical(other.dailyLossLimit, dailyLossLimit) || other.dailyLossLimit == dailyLossLimit)&&(identical(other.dailyGainCap, dailyGainCap) || other.dailyGainCap == dailyGainCap)&&(identical(other.giveBackPct, giveBackPct) || other.giveBackPct == giveBackPct)&&(identical(other.oneAndDone, oneAndDone) || other.oneAndDone == oneAndDone)&&(identical(other.noTradesBefore, noTradesBefore) || other.noTradesBefore == noTradesBefore)&&(identical(other.noTradesAfter, noTradesAfter) || other.noTradesAfter == noTradesAfter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,riskPerTrade,maxTradesPerDay,dailyLossLimit,dailyGainCap,giveBackPct,oneAndDone,noTradesBefore,noTradesAfter);

@override
String toString() {
  return 'TradingRules(riskPerTrade: $riskPerTrade, maxTradesPerDay: $maxTradesPerDay, dailyLossLimit: $dailyLossLimit, dailyGainCap: $dailyGainCap, giveBackPct: $giveBackPct, oneAndDone: $oneAndDone, noTradesBefore: $noTradesBefore, noTradesAfter: $noTradesAfter)';
}


}

/// @nodoc
abstract mixin class _$TradingRulesCopyWith<$Res> implements $TradingRulesCopyWith<$Res> {
  factory _$TradingRulesCopyWith(_TradingRules value, $Res Function(_TradingRules) _then) = __$TradingRulesCopyWithImpl;
@override @useResult
$Res call({
 double? riskPerTrade, int? maxTradesPerDay, double? dailyLossLimit, double? dailyGainCap, double? giveBackPct, bool? oneAndDone, String? noTradesBefore, String? noTradesAfter
});




}
/// @nodoc
class __$TradingRulesCopyWithImpl<$Res>
    implements _$TradingRulesCopyWith<$Res> {
  __$TradingRulesCopyWithImpl(this._self, this._then);

  final _TradingRules _self;
  final $Res Function(_TradingRules) _then;

/// Create a copy of TradingRules
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? riskPerTrade = freezed,Object? maxTradesPerDay = freezed,Object? dailyLossLimit = freezed,Object? dailyGainCap = freezed,Object? giveBackPct = freezed,Object? oneAndDone = freezed,Object? noTradesBefore = freezed,Object? noTradesAfter = freezed,}) {
  return _then(_TradingRules(
riskPerTrade: freezed == riskPerTrade ? _self.riskPerTrade : riskPerTrade // ignore: cast_nullable_to_non_nullable
as double?,maxTradesPerDay: freezed == maxTradesPerDay ? _self.maxTradesPerDay : maxTradesPerDay // ignore: cast_nullable_to_non_nullable
as int?,dailyLossLimit: freezed == dailyLossLimit ? _self.dailyLossLimit : dailyLossLimit // ignore: cast_nullable_to_non_nullable
as double?,dailyGainCap: freezed == dailyGainCap ? _self.dailyGainCap : dailyGainCap // ignore: cast_nullable_to_non_nullable
as double?,giveBackPct: freezed == giveBackPct ? _self.giveBackPct : giveBackPct // ignore: cast_nullable_to_non_nullable
as double?,oneAndDone: freezed == oneAndDone ? _self.oneAndDone : oneAndDone // ignore: cast_nullable_to_non_nullable
as bool?,noTradesBefore: freezed == noTradesBefore ? _self.noTradesBefore : noTradesBefore // ignore: cast_nullable_to_non_nullable
as String?,noTradesAfter: freezed == noTradesAfter ? _self.noTradesAfter : noTradesAfter // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CoachProfile {

/// calm_male | calm_female | coach_tone
 String? get voice; String? get name;
/// Create a copy of CoachProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoachProfileCopyWith<CoachProfile> get copyWith => _$CoachProfileCopyWithImpl<CoachProfile>(this as CoachProfile, _$identity);

  /// Serializes this CoachProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CoachProfile&&(identical(other.voice, voice) || other.voice == voice)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,voice,name);

@override
String toString() {
  return 'CoachProfile(voice: $voice, name: $name)';
}


}

/// @nodoc
abstract mixin class $CoachProfileCopyWith<$Res>  {
  factory $CoachProfileCopyWith(CoachProfile value, $Res Function(CoachProfile) _then) = _$CoachProfileCopyWithImpl;
@useResult
$Res call({
 String? voice, String? name
});




}
/// @nodoc
class _$CoachProfileCopyWithImpl<$Res>
    implements $CoachProfileCopyWith<$Res> {
  _$CoachProfileCopyWithImpl(this._self, this._then);

  final CoachProfile _self;
  final $Res Function(CoachProfile) _then;

/// Create a copy of CoachProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? voice = freezed,Object? name = freezed,}) {
  return _then(_self.copyWith(
voice: freezed == voice ? _self.voice : voice // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CoachProfile].
extension CoachProfilePatterns on CoachProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CoachProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CoachProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CoachProfile value)  $default,){
final _that = this;
switch (_that) {
case _CoachProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CoachProfile value)?  $default,){
final _that = this;
switch (_that) {
case _CoachProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? voice,  String? name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CoachProfile() when $default != null:
return $default(_that.voice,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? voice,  String? name)  $default,) {final _that = this;
switch (_that) {
case _CoachProfile():
return $default(_that.voice,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? voice,  String? name)?  $default,) {final _that = this;
switch (_that) {
case _CoachProfile() when $default != null:
return $default(_that.voice,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CoachProfile implements CoachProfile {
  const _CoachProfile({this.voice, this.name});
  factory _CoachProfile.fromJson(Map<String, dynamic> json) => _$CoachProfileFromJson(json);

/// calm_male | calm_female | coach_tone
@override final  String? voice;
@override final  String? name;

/// Create a copy of CoachProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CoachProfileCopyWith<_CoachProfile> get copyWith => __$CoachProfileCopyWithImpl<_CoachProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CoachProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CoachProfile&&(identical(other.voice, voice) || other.voice == voice)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,voice,name);

@override
String toString() {
  return 'CoachProfile(voice: $voice, name: $name)';
}


}

/// @nodoc
abstract mixin class _$CoachProfileCopyWith<$Res> implements $CoachProfileCopyWith<$Res> {
  factory _$CoachProfileCopyWith(_CoachProfile value, $Res Function(_CoachProfile) _then) = __$CoachProfileCopyWithImpl;
@override @useResult
$Res call({
 String? voice, String? name
});




}
/// @nodoc
class __$CoachProfileCopyWithImpl<$Res>
    implements _$CoachProfileCopyWith<$Res> {
  __$CoachProfileCopyWithImpl(this._self, this._then);

  final _CoachProfile _self;
  final $Res Function(_CoachProfile) _then;

/// Create a copy of CoachProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? voice = freezed,Object? name = freezed,}) {
  return _then(_CoachProfile(
voice: freezed == voice ? _self.voice : voice // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
