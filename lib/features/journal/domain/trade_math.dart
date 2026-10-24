import '../../markets/domain/instrument.dart';
import '../../markets/domain/rate_source.dart';
import 'trade.dart';

/// Result and risk of a trade, in the account currency, from the instrument
/// model (tick size and tick value) and a [RateSource].
///
/// Everything returns null instead of guessing: an instrument without sizing
/// data (Deriv synthetics, custom symbols) or an unknown exchange rate means
/// the trader types the broker's own figure.
abstract final class TradeMath {
  /// Money made or lost moving from [entry] to [exit], or null when it cannot
  /// be worked out.
  static double? pnl({
    required Instrument? instrument,
    required TradeDirection direction,
    required double entry,
    required double exit,
    required double size,
    required String accountCurrency,
    required RateSource rates,
  }) => _money(
    instrument: instrument,
    move: (exit - entry) * direction.sign,
    size: size,
    accountCurrency: accountCurrency,
    rates: rates,
  );

  /// Money put at risk by the stop, always positive, or null when unknown.
  static double? riskMoney({
    required Instrument? instrument,
    required double entry,
    required double? stop,
    required double size,
    required String accountCurrency,
    required RateSource rates,
  }) {
    if (stop == null || stop == entry) return null;
    final risk = _money(
      instrument: instrument,
      move: (entry - stop).abs(),
      size: size,
      accountCurrency: accountCurrency,
      rates: rates,
    );
    return risk == null || risk <= 0 ? null : risk;
  }

  /// True when the quote currency differs from the account's: the figure then
  /// rests on the exchange rate, which is a placeholder until live rates exist.
  static bool usesRate(Instrument? instrument, String accountCurrency) =>
      instrument != null && instrument.quoteCurrency.toUpperCase() != accountCurrency.toUpperCase();

  static double? _money({
    required Instrument? instrument,
    required double move,
    required double size,
    required String accountCurrency,
    required RateSource rates,
  }) {
    if (instrument == null || size <= 0) return null;
    final tick = instrument.tickSize;
    final tickValue = instrument.effectiveTickValue;
    if (tick == null || tickValue == null || tick <= 0 || tickValue <= 0) return null;
    final rate = rates.rate(instrument.quoteCurrency, accountCurrency);
    if (rate == null || rate <= 0) return null;
    return move / tick * tickValue * size * rate;
  }

  /// Price places for [instrument]'s tick (0.00001 → 5), for showing prices.
  static int decimals(Instrument? instrument) {
    final tick = instrument?.tickSize;
    if (tick == null || tick <= 0) return 5;
    var places = 0;
    var v = tick;
    while (v < 1 && places < 8) {
      v *= 10;
      places++;
    }
    return places;
  }
}
