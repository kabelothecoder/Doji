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

    /// The MT5 account behind this one, linked through MetaRPC. The terminal
    /// and the password stay server-side (`supabase/functions/mt5`); the app
    /// keeps only what it shows.
    BrokerLink? brokerLink,

    /// Earlier strategies, oldest first, kept when a backtest draft is adopted.
    /// The current one is [strategy]; its number is [strategyVersion].
    @Default(<StrategyVersion>[]) List<StrategyVersion> strategyVersions,
  }) = _TradingAccount;

  factory TradingAccount.fromJson(Map<String, dynamic> json) => _$TradingAccountFromJson(json);

  /// The current strategy's number: 1 until a draft is adopted.
  int get strategyVersion => strategyVersions.length + 1;

  /// The stricter of the trader's own daily loss limit and the prop firm's.
  double? get strictestDailyLossPct {
    final limits = [rules?.dailyLossLimit, prop?.dailyLossLimitPct].whereType<double>();
    return limits.isEmpty ? null : limits.reduce((a, b) => a < b ? a : b);
  }
}

/// A strategy the account used before, with the limits it ran with.
@freezed
abstract class StrategyVersion with _$StrategyVersion {
  const factory StrategyVersion({
    required int number,

    /// When it stopped being the current strategy.
    required DateTime replacedAt,
    StrategyProfile? strategy,
    TradingRules? rules,

    /// Where the strategy that replaced it came from ('from backtest').
    String? note,
  }) = _StrategyVersion;

  factory StrategyVersion.fromJson(Map<String, dynamic> json) => _$StrategyVersionFromJson(json);
}

/// A trading account's link to the trader's MT5 account (read-only: prices,
/// balance and equity). Keyed server-side by [TradingAccount.id].
@freezed
abstract class BrokerLink with _$BrokerLink {
  const factory BrokerLink({required String server, required int login}) = _BrokerLink;

  factory BrokerLink.fromJson(Map<String, dynamic> json) => _$BrokerLinkFromJson(json);
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

/// [next] with its strategy words compared to [saved]'s: new words on a strategy that had words
/// make a new version, the old one kept and numbered, so stats never mix two plans.
TradingAccount versionOnNewWords(TradingAccount saved, TradingAccount next, {required DateTime now}) {
  final before = saved.strategy?.rawText?.trim() ?? '';
  final after = next.strategy?.rawText?.trim() ?? '';
  if (before.isEmpty || before == after) return next;
  return next.copyWith(
    strategyVersions: [
      ...saved.strategyVersions,
      StrategyVersion(
        number: saved.strategyVersion,
        replacedAt: now.toUtc(),
        strategy: saved.strategy,
        rules: saved.rules,
        note: 'replaced by new words',
      ),
    ],
  );
}
