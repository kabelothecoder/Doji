import 'instrument.dart';
import 'rate_source.dart';

/// Turns "risk 1% with this stop" into a position size, for any market and
/// any account currency.
///
/// Risk stays a percent of the account everywhere. The loss per contract is
/// worked out in the instrument's quote currency (from tick size and tick
/// value), converted into the account currency with [RateSource], and then
/// compared with the money at risk.
abstract final class RiskSizing {
  /// Contracts (lots; units for stocks and crypto) that lose [riskPercent] of
  /// [accountBalance] (held in [accountCurrency]) if price moves
  /// [stopDistance] (in price units) against you.
  ///
  /// Null when the instrument's sizing data is unknown, the rate is unknown,
  /// or any input is not positive: doji does not guess a size.
  static double? contractsForRisk({
    required Instrument instrument,
    required double accountBalance,
    required String accountCurrency,
    required double riskPercent,
    required double stopDistance,
    required RateSource rates,
  }) {
    final tick = instrument.tickSize;
    final tickValue = instrument.effectiveTickValue;
    if (tick == null || tickValue == null) return null;
    if (tick <= 0 || tickValue <= 0) return null;
    if (accountBalance <= 0 || riskPercent <= 0 || stopDistance <= 0) return null;

    final toAccount = rates.rate(instrument.quoteCurrency, accountCurrency);
    if (toAccount == null || toAccount <= 0) return null;

    final riskMoney = accountBalance * riskPercent / 100; // account currency
    final lossPerContractQuote = stopDistance / tick * tickValue; // quote currency
    return riskMoney / (lossPerContractQuote * toAccount);
  }
}
