import 'market_hours.dart';

/// What kind of market an instrument trades in.
enum AssetClass {
  forex,

  /// Broker CFDs: indices, metals, oil.
  cfd,
  futures,
  crypto,
  stock,

  /// Deriv synthetic indices: Volatility, Boom and Crash.
  synthetic;

  /// Futures and stocks are modelled but not offered yet.
  /// TODO(next-slice): flip when their onboarding and feeds are ready.
  bool get shownInUi => switch (this) {
    forex || cfd || crypto || synthetic => true,
    futures || stock => false,
  };
}

/// How the markets step groups instruments.
enum InstrumentGroup {
  forex('forex'),
  metals('metals'),
  indices('indices'),
  oil('oil'),
  crypto('crypto'),
  volatility('volatility indices'),
  boomCrash('boom and crash'),
  futures('futures'),
  stocks('stocks');

  const InstrumentGroup(this.label);
  final String label;
}

/// One tradable instrument, whatever the market.
///
/// Sizing fields are nullable on purpose: where the real spec comes from the
/// broker (synthetics, some crypto) they stay null until a feed reports them,
/// and `RiskSizing` then declines to size rather than guess.
class Instrument {
  const Instrument({
    required this.symbol,
    required this.name,
    required this.assetClass,
    required this.group,
    required this.hours,
    this.label,
    this.quoteCurrency = 'USD',
    this.tickSize,
    this.tickValue,
    this.contractSize,
    this.aliases = const [],
    this.fastMover = false,
  });

  /// Canonical id: 'XAUUSD', 'ES', 'AAPL', 'R_75' (Deriv's symbol).
  final String symbol;

  /// Spoken in doji's replies: 'gold', 'the dow', 'volatility 75 index'.
  final String name;
  final AssetClass assetClass;
  final InstrumentGroup group;
  final MarketHours hours;

  /// Chip text when the symbol is cryptic ('Volatility 75' for R_75).
  final String? label;
  final String quoteCurrency;

  /// Smallest price step.
  final double? tickSize;

  /// Money per tick for one contract, in [quoteCurrency]. Futures publish it;
  /// for forex and CFDs it is [tickSize] × [contractSize].
  final double? tickValue;

  /// Units per 1.0 lot or contract (forex 100000, gold 100 oz, ES multiplier 50).
  final double? contractSize;

  /// Broker spellings people search for ('GOLD', 'XAU/USD').
  final List<String> aliases;

  /// Moves fast enough that doji says so in onboarding.
  final bool fastMover;

  String get displayLabel => label ?? symbol;

  double? get effectiveTickValue =>
      tickValue ?? (tickSize != null && contractSize != null ? tickSize! * contractSize! : null);
}
