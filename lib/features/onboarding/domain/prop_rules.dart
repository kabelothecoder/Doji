import 'package:freezed_annotation/freezed_annotation.dart';

part 'prop_rules.freezed.dart';
part 'prop_rules.g.dart';

/// How a firm measures the maximum drawdown.
enum DrawdownType {
  /// "Static": the floor is fixed at the starting balance minus the limit.
  /// Called static in the app.
  fixed('static'),

  /// The floor follows the account's high: it rises with the peak and never
  /// falls back.
  trailing('trailing');

  const DrawdownType(this.label);

  /// The word the app uses.
  final String label;
}

/// What a trailing drawdown follows.
enum TrailingBasis {
  /// The highest closed balance.
  balance,

  /// The highest equity, open profit included.
  equity,
}

/// A prop challenge's own limits, entered by the user (no firm presets yet).
/// Every limit is optional; percentages are of the account's starting size
/// (`TradingAccount.startingSize`).
///
/// Not modelled yet: trailing drawdowns that lock at the starting balance once
/// reached. Minimum days and consistency are only checked by the backtest.
@freezed
abstract class PropRules with _$PropRules {
  const PropRules._();

  const factory PropRules({
    /// Free text, shown as a comment in profile.doji.
    String? firm,

    /// Most you may lose in one day, % of the account.
    double? dailyLossLimitPct,

    /// Most the account may fall, % of the account. How it is measured is
    /// [drawdownType] (and [trailingBasis] when trailing).
    double? maxDrawdownPct,

    /// Static unless the user says otherwise.
    @Default(DrawdownType.fixed) DrawdownType drawdownType,

    /// Only read when [drawdownType] is trailing. Equity is the stricter
    /// (open profit raises the high), so it is the default.
    @Default(TrailingBasis.equity) TrailingBasis trailingBasis,

    /// Profit that passes the challenge, %. Null on funded accounts.
    double? profitTargetPct,

    /// Days with at least one trade the firm asks for before a payout.
    int? minTradingDays,

    /// The best day may be at most this % of the total profit (consistency rule).
    double? consistencyPct,
  }) = _PropRules;

  factory PropRules.fromJson(Map<String, dynamic> json) => _$PropRulesFromJson(json);

  /// True when no limit or detail was entered. The drawdown settings alone do
  /// not count: they only describe a limit.
  bool get isEmpty =>
      firm == null &&
      dailyLossLimitPct == null &&
      maxDrawdownPct == null &&
      profitTargetPct == null &&
      minTradingDays == null &&
      consistencyPct == null;

  /// "static", "trailing balance" or "trailing equity": how the drawdown reads in
  /// profile.doji and on the meter.
  String get drawdownLabel =>
      drawdownType == DrawdownType.fixed ? DrawdownType.fixed.label : 'trailing ${trailingBasis.name}';
}
