import 'prop_rules.dart';

/// The account as the broker reports it. All in the account's currency.
class AccountState {
  const AccountState({
    required this.balance,
    required this.equity,
    required this.peakBalance,
    required this.peakEquity,
  });

  /// Closed-trade balance.
  final double balance;

  /// Balance plus open profit or loss.
  final double equity;

  /// Highest balance / equity since the account started.
  final double peakBalance;
  final double peakEquity;
}

/// Where the account stands against a firm's maximum drawdown.
class DrawdownStatus {
  const DrawdownStatus({
    required this.type,
    required this.basis,
    required this.limitPct,
    required this.usedPct,
    required this.floor,
  });

  final DrawdownType type;

  /// Null for a static drawdown.
  final TrailingBasis? basis;

  /// The firm's limit and how much of it is used, both % of the account size.
  final double limitPct;
  final double usedPct;

  /// The level the measured value must stay above, in account currency.
  final double floor;

  /// Share of the limit used, 0–1.
  double get fraction => limitPct <= 0 ? 0 : (usedPct / limitPct).clamp(0, 1).toDouble();
  bool get breached => usedPct >= limitPct;

  /// "static drawdown" or "trailing equity drawdown".
  String get label => basis == null ? '${type.label} drawdown' : '${type.label} ${basis!.name} drawdown';
}

/// The maximum-drawdown rule, one function per type so a warning always uses
/// the type the user chose.
abstract final class PropDrawdown {
  /// Null when the rules have no drawdown limit or [accountSize] is not positive.
  ///
  /// - **static**: how far equity is below the starting balance. Open losses
  ///   count (it is the stricter reading); gains never reduce it below zero.
  /// - **trailing balance**: how far the balance is below its highest value.
  /// - **trailing equity**: how far equity is below its highest value.
  ///
  /// Percentages are of the starting [accountSize], as firms state them.
  static DrawdownStatus? evaluate(
    PropRules rules, {
    required double accountSize,
    required AccountState state,
  }) {
    final limit = rules.maxDrawdownPct;
    if (limit == null || limit <= 0 || accountSize <= 0) return null;
    final money = limit / 100 * accountSize;

    final (double reference, double current, TrailingBasis? basis) = switch (rules.drawdownType) {
      DrawdownType.fixed => (accountSize, state.equity, null),
      DrawdownType.trailing when rules.trailingBasis == TrailingBasis.balance => (
        state.peakBalance,
        state.balance,
        TrailingBasis.balance,
      ),
      DrawdownType.trailing => (state.peakEquity, state.equity, TrailingBasis.equity),
    };

    final down = reference - current;
    return DrawdownStatus(
      type: rules.drawdownType,
      basis: basis,
      limitPct: limit,
      usedPct: down <= 0 ? 0 : down / accountSize * 100,
      floor: reference - money,
    );
  }
}
