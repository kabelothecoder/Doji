import 'package:freezed_annotation/freezed_annotation.dart';

import '../../accounts/domain/trading_account.dart';
import 'prop_rules.dart';

part 'profile_doji.freezed.dart';
part 'profile_doji.g.dart';

/// Bumped when the stored shape changes without a migration: older saved
/// profiles and half-finished onboarding are dropped and the user starts over.
/// 2: `pairs` → `instruments`, `propFirm`/`propSize` → `prop` (PropRules).
/// 3: sessions are real zones (`sydney`, `tokyo` replace `asia`); `accountCurrency`;
///    PropRules gains `drawdownType` and `trailingBasis`.
/// 4: instruments, accountCurrency, prop, strategy and rules move into
///    `accounts` (TradingAccount); PropRules loses accountSize (the account's
///    startingSize is the only size); strategies gain conditions.
const int kOnboardingVersion = 4;

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

    /// scalper | day_trader | swing | undecided; several joined with ",".
    String? style,

    /// sydney | tokyo | london | new_york | around_job
    @Default(<String>[]) List<String> sessions,

    /// not_flexible | semi_flexible | fully_flexible: how often the trader can look at the
    /// charts in those hours (`availabilityFit`). Nullable: no version bump.
    String? availability,

    /// IANA id when detected (e.g. Africa/Johannesburg).
    String? timeZone,
    int? utcOffsetMinutes,

    /// prop_challenge | grow_account | consistent | make_it_my_job | learn
    String? goal,

    /// revenge | fomo | overtrading | hesitation | moving_stop | oversizing | bored
    @Default(<String>[]) List<String> struggles,

    /// careful | balanced | aggressive (the risk step). Feeds `recommendPlan`.
    String? riskAppetite,

    /// How the trader usually funds a personal account: lt_500 | 500_5k | 5k_25k | 25k_plus.
    /// TODO(backend): store on the account for plan offers.
    String? usualDeposit,

    /// The trader's accounts, each with its own rules and strategy. Onboarding
    /// creates the first one.
    @Default(<TradingAccount>[]) List<TradingAccount> accounts,

    /// The account everything reads. Falls back to the first one.
    String? activeAccountId,
    CoachProfile? coach,

    /// "The Open" ritual time, local HH:mm.
    String? theOpenTime,
    bool? notificationsAllowed,
    DateTime? pledgedAt,
    @Default(kOnboardingVersion) int onboardingVersion,

    /// Everyone starts at M1 · Impulsive.
    @Default('M1') String rank,

    /// Kept on device only ("continue without account"); sync when signed in.
    @Default(false) bool pendingSync,
    DateTime? completedAt,
  }) = _ProfileDoji;

  factory ProfileDoji.fromJson(Map<String, dynamic> json) => _$ProfileDojiFromJson(json);

  static const int currentOnboardingVersion = kOnboardingVersion;

  bool get isComplete => completedAt != null;

  /// The active account, else the first, else null (onboarding not done).
  TradingAccount? get activeAccount =>
      accounts.where((a) => a.id == activeAccountId).firstOrNull ?? accounts.firstOrNull;

  // Read-only views of the active account, so readers need not know about accounts.
  List<String> get instruments => activeAccount?.instruments ?? const [];
  PropRules? get prop => activeAccount?.prop;
  String get accountCurrency => activeAccount?.accountCurrency ?? 'USD';
  StrategyProfile? get strategy => activeAccount?.strategy;
  TradingRules? get rules => activeAccount?.rules;
  double? get startingSize => activeAccount?.startingSize;

  /// This profile with the active account changed by [f]. No-op without accounts.
  ProfileDoji withActive(TradingAccount Function(TradingAccount a) f) {
    final active = activeAccount;
    return active == null ? this : upsertAccount(f(active));
  }

  /// Replaces the account with the same id, or adds it.
  ProfileDoji upsertAccount(TradingAccount account) {
    final i = accounts.indexWhere((a) => a.id == account.id);
    final next = [...accounts];
    i < 0 ? next.add(account) : next[i] = account;
    return copyWith(accounts: next);
  }

  ProfileDoji switchAccount(String id) =>
      accounts.any((a) => a.id == id) ? copyWith(activeAccountId: id) : this;

  /// Removes an account. The last one stays: a trader always has one. Removing
  /// the active one makes the first remaining one active.
  ProfileDoji removeAccount(String id) {
    if (accounts.length <= 1) return this;
    final next = accounts.where((a) => a.id != id).toList();
    final activeId = activeAccount?.id == id ? next.first.id : activeAccountId;
    return copyWith(accounts: next, activeAccountId: activeId);
  }
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

    /// What doji measures, in order. Anything it cannot measure is a manual
    /// condition ("check on your chart").
    @Default(<StrategyCondition>[]) List<StrategyCondition> conditions,

    /// How a backtest closes a setup. Null = not set: the backtest asks for it.
    ExitRules? exits,

    /// The trader's own plan lines (design/research-intake-plan.md › 2b), free text, read by the
    /// Open, the coach and the analyst. Where they are wrong (the stop), where they are right
    /// (the target), and when they stay out.
    String? wrongWhen,
    String? rightWhen,
    String? stayOutWhen,
  }) = _StrategyProfile;

  factory StrategyProfile.fromJson(Map<String, dynamic> json) => _$StrategyProfileFromJson(json);
}

/// Where a backtest puts the stop of a london break setup.
enum StopRule {
  /// Just past the broken level, on the range side.
  @JsonValue('broken_level')
  brokenLevel('past the broken level'),

  /// At the other side of the asian range.
  @JsonValue('range_opposite')
  rangeOpposite('other side of the range');

  const StopRule(this.label);

  final String label;
}

/// A strategy's exits as rules a backtest can run. Stop and target in the
/// trader's words stay in [ParsedStrategy]; these are what doji measures.
@freezed
abstract class ExitRules with _$ExitRules {
  const factory ExitRules({
    @Default(StopRule.brokenLevel) StopRule stop,

    /// The stop sits this share of the range past its level (0.1 = 10%).
    @Default(0.1) double bufferOfRange,

    /// Target in R (2 = twice the stop distance).
    @Default(2.0) double targetR,

    /// Closed at the close of this bar count after entry, when set; always closed
    /// at the session's end.
    int? maxBarsOpen,
  }) = _ExitRules;

  factory ExitRules.fromJson(Map<String, dynamic> json) => _$ExitRulesFromJson(json);
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

    /// Walk-away rules (`WalkAway`), all optional. Stop for the day at +x%.
    double? dailyGainCap,

    /// Stop after giving back x% of today's best running result.
    double? giveBackPct,

    /// Stop after the first winning trade of the day.
    bool? oneAndDone,

    /// Trading window inside the session, local HH:mm (`outsideWindow`). Either may be null.
    String? noTradesBefore,
    String? noTradesAfter,
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
