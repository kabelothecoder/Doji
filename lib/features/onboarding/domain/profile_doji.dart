import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_doji.freezed.dart';
part 'profile_doji.g.dart';

/// The user's `profile.doji`: everything onboarding learns, pre-account.
///
/// Stored locally first (shared_preferences), later synced to
/// `profiles.profile_doji` (jsonb) in Supabase — see
/// supabase/migrations/0001_profiles.sql.
@freezed
abstract class ProfileDoji with _$ProfileDoji {
  const ProfileDoji._();

  const factory ProfileDoji({
    String? name,

    /// lt_6m | 6_24m | 2_5y | 5y_plus
    String? experience,

    /// scalper | day_trader | swing | undecided
    String? style,
    @Default(<String>[]) List<String> pairs,

    /// asia | london | new_york | around_job
    @Default(<String>[]) List<String> sessions,

    /// IANA id when detected (e.g. Africa/Johannesburg).
    String? timeZone,
    int? utcOffsetMinutes,

    /// prop_challenge | grow_account | consistent | make_it_my_job | learn
    String? goal,
    String? propFirm,
    int? propSize,

    /// revenge | fomo | overtrading | hesitation | moving_stop | oversizing | bored
    @Default(<String>[]) List<String> struggles,
    StrategyProfile? strategy,
    TradingRules? rules,
    CoachProfile? coach,

    /// "The Open" ritual time, local HH:mm.
    String? theOpenTime,
    bool? notificationsAllowed,
    DateTime? pledgedAt,
    @Default(1) int onboardingVersion,

    /// Everyone starts at M1 · Impulsive.
    @Default('M1') String rank,

    /// Kept on device only ("continue without account"); sync when signed in.
    @Default(false) bool pendingSync,
    DateTime? completedAt,
  }) = _ProfileDoji;

  factory ProfileDoji.fromJson(Map<String, dynamic> json) => _$ProfileDojiFromJson(json);

  static const int currentOnboardingVersion = 1;

  bool get isComplete => completedAt != null;
}

@freezed
abstract class StrategyProfile with _$StrategyProfile {
  const factory StrategyProfile({
    /// The user's own words (typed or dictated).
    String? rawText,

    /// sr | smc_ict | trend_pullback | breakout | none
    String? template,

    /// text | voice | template
    String? source,
    ParsedStrategy? parsed,
  }) = _StrategyProfile;

  factory StrategyProfile.fromJson(Map<String, dynamic> json) => _$StrategyProfileFromJson(json);
}

/// Structured fields a [StrategyParser] extracts. Every field is editable.
@freezed
abstract class ParsedStrategy with _$ParsedStrategy {
  const ParsedStrategy._();

  const factory ParsedStrategy({
    String? setup,
    String? timeframe,
    String? entry,
    String? stop,
    String? target,
  }) = _ParsedStrategy;

  factory ParsedStrategy.fromJson(Map<String, dynamic> json) => _$ParsedStrategyFromJson(json);

  /// Short id for profile.doji, e.g. `london_break`.
  String get slug {
    final s = (setup ?? '').toLowerCase();
    if (s.contains('london') && s.contains('break')) return 'london_break';
    if (s.contains('smc') || s.contains('ict') || s.contains('order block') || s.contains('liquidity')) {
      return 'smc_ict';
    }
    if (s.contains('pullback')) return 'trend_pullback';
    if (s.contains('support') || s.contains('resistance')) return 's_r';
    if (s.contains('break')) return 'breakout';
    return 'custom';
  }

  bool get isEmpty => [setup, timeframe, entry, stop, target].every((v) => v == null || v.isEmpty);
}

@freezed
abstract class TradingRules with _$TradingRules {
  const factory TradingRules({
    /// Percent of account per trade (1.0 = 1%).
    double? riskPerTrade,
    int? maxTradesPerDay,

    /// Percent of account; stop for the day at -x%.
    double? dailyLossLimit,
  }) = _TradingRules;

  factory TradingRules.fromJson(Map<String, dynamic> json) => _$TradingRulesFromJson(json);
}

@freezed
abstract class CoachProfile with _$CoachProfile {
  const factory CoachProfile({
    /// calm_male | calm_female | coach_tone
    String? voice,
    String? name,
  }) = _CoachProfile;

  factory CoachProfile.fromJson(Map<String, dynamic> json) => _$CoachProfileFromJson(json);
}

/// Design system › RankPill ladder.
const Map<String, String> dojiRanks = {
  'M1': 'Impulsive',
  'M5': 'Aware',
  'M15': 'Learning',
  'H1': 'Steady',
  'H4': 'Disciplined',
  'D1': 'Consistent',
  'W1': 'Composed',
  'MN': 'Doji',
};
