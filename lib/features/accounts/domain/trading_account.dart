import 'package:freezed_annotation/freezed_annotation.dart';

import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/prop_rules.dart';

part 'trading_account.freezed.dart';
part 'trading_account.g.dart';

/// What kind of account it is. Only the label and the defaults differ:
/// every kind can hold prop rules.
enum AccountKind {
  @JsonValue('deriv_synthetic')
  derivSynthetic('deriv synthetics'),
  @JsonValue('prop_challenge')
  propChallenge('prop challenge'),
  @JsonValue('personal')
  personal('personal'),
  @JsonValue('demo')
  demo('demo');

  const AccountKind(this.label);

  final String label;
}

/// One trading account with its own rules and strategy. A trader has one or
/// more; one is active at a time (`ProfileDoji.activeAccountId`), and Home,
/// the journal, the brief, the coach and the rail read that one.
@freezed
abstract class TradingAccount with _$TradingAccount {
  const TradingAccount._();

  const factory TradingAccount({
    required String id,
    required String name,
    @Default(AccountKind.personal) AccountKind kind,

    /// USD | ZAR | EUR | GBP. Position sizing converts into it.
    @Default('USD') String accountCurrency,

    /// The starting balance in [accountCurrency]. The only size: the prop
    /// drawdown and Home's loss % are both measured against it. Null when the
    /// trader has not given one (loss % then comes from risk per trade).
    double? startingSize,

    /// Instrument symbols ('XAUUSD', 'R_75'), or the trader's own.
    @Default(<String>[]) List<String> instruments,

    /// Risk % per trade, max trades a day, daily loss limit %.
    TradingRules? rules,

    /// A prop challenge's own limits (percentages of [startingSize]).
    PropRules? prop,
    StrategyProfile? strategy,
  }) = _TradingAccount;

  factory TradingAccount.fromJson(Map<String, dynamic> json) => _$TradingAccountFromJson(json);

  /// The stricter of the trader's own daily loss limit and the prop firm's.
  double? get strictestDailyLossPct {
    final limits = [rules?.dailyLossLimit, prop?.dailyLossLimitPct].whereType<double>();
    return limits.isEmpty ? null : limits.reduce((a, b) => a < b ? a : b);
  }
}

/// What doji measures a condition with. Only kinds doji can measure from data
/// it has today; anything else is [manual] and doji never guesses it.
enum ConditionKind {
  /// One of the trader's sessions is open ([StrategyCondition.session], or any
  /// of profile.doji › sessions when null).
  @JsonValue('session')
  session,

  /// No high-impact news within the buffer either side.
  @JsonValue('news_buffer')
  newsBuffer,

  /// Trades today under the account's max.
  @JsonValue('trades_vs_max')
  tradesVsMax,

  /// Today's loss under the account's stricter daily limit.
  @JsonValue('daily_loss_vs_limit')
  dailyLossVsLimit,

  /// Price breaks the Asian range (Tokyo open to London open), and with
  /// [StrategyCondition.closeBack] a candle closes back beyond the broken level.
  @JsonValue('range_break')
  rangeBreak,

  /// Shown as "check on your chart": always waiting.
  @JsonValue('manual')
  manual,
}

/// One measurable rule of a strategy.
@freezed
abstract class StrategyCondition with _$StrategyCondition {
  const factory StrategyCondition({
    required ConditionKind kind,

    /// [ConditionKind.session]: sydney | tokyo | london | new_york. Null = any of
    /// the trader's sessions.
    String? session,

    /// [ConditionKind.rangeBreak]: also wait for the close back beyond the level.
    @Default(false) bool closeBack,

    /// [ConditionKind.manual]: the rule in the trader's words.
    String? text,
  }) = _StrategyCondition;

  factory StrategyCondition.fromJson(Map<String, dynamic> json) => _$StrategyConditionFromJson(json);
}
