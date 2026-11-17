import '../../onboarding/domain/prop_drawdown.dart';

/// How long a broker figure counts as current. Older ones are never shown as
/// today's balance or equity.
const Duration kBrokerFreshFor = Duration(minutes: 2);

/// The broker's balance and equity for one account, with the highs doji has
/// seen (for trailing drawdown) and the balance the day started at (for
/// today's loss). All in the account currency.
class BrokerReading {
  const BrokerReading({
    required this.balance,
    required this.equity,
    required this.currency,
    required this.asOf,
    required this.peakBalance,
    required this.peakEquity,
    required this.day,
    required this.dayStartBalance,
  });

  final double balance;
  final double equity;
  final String currency;

  /// The broker's time for these figures, UTC.
  final DateTime asOf;
  final double peakBalance;
  final double peakEquity;

  /// Local day ('2026-11-06') [dayStartBalance] belongs to.
  final String day;

  /// shortcut: the first balance doji saw today, not the broker's own
  /// day-start; losses closed before the first look of the day are missed.
  /// Upgrade with the `mt5` function reading today's deals (OrderHistory).
  final double dayStartBalance;

  bool freshAt(DateTime now) => now.toUtc().difference(asOf) <= kBrokerFreshFor;

  AccountState get state =>
      AccountState(balance: balance, equity: equity, peakBalance: peakBalance, peakEquity: peakEquity);

  /// Today's loss as a % of [accountSize], from the day-start balance to equity.
  double lossPercent(double accountSize) => accountSize <= 0
      ? 0
      : ((dayStartBalance - equity) / accountSize * 100).clamp(0, double.infinity).toDouble();

  /// Folds a new figure into [previous]: highs only rise (from at least the
  /// starting size), the day-start balance resets on a new local [day].
  static BrokerReading track(
    BrokerReading? previous, {
    required double balance,
    required double equity,
    required String currency,
    required DateTime asOf,
    required String day,
    required double startingSize,
  }) {
    double hi(double a, double? b) => b == null || a > b ? a : b;
    return BrokerReading(
      balance: balance,
      equity: equity,
      currency: currency,
      asOf: asOf.toUtc(),
      peakBalance: hi(balance, hi(startingSize, previous?.peakBalance)),
      peakEquity: hi(equity, hi(startingSize, previous?.peakEquity)),
      day: day,
      dayStartBalance: previous != null && previous.day == day ? previous.dayStartBalance : balance,
    );
  }

  Map<String, Object?> toJson() => {
    'balance': balance,
    'equity': equity,
    'currency': currency,
    'asOf': asOf.toIso8601String(),
    'peakBalance': peakBalance,
    'peakEquity': peakEquity,
    'day': day,
    'dayStartBalance': dayStartBalance,
  };

  static BrokerReading? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      return BrokerReading(
        balance: (json['balance'] as num).toDouble(),
        equity: (json['equity'] as num).toDouble(),
        currency: json['currency'] as String,
        asOf: DateTime.parse(json['asOf'] as String).toUtc(),
        peakBalance: (json['peakBalance'] as num).toDouble(),
        peakEquity: (json['peakEquity'] as num).toDouble(),
        day: json['day'] as String,
        dayStartBalance: (json['dayStartBalance'] as num).toDouble(),
      );
    } on Object {
      return null;
    }
  }
}

/// '2026-11-06' for [t] in local time.
String localDay(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}
