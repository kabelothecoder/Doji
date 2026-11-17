import '../../markets/domain/instrument.dart';
import '../../markets/domain/rate_source.dart';
import '../../markets/domain/risk_sizing.dart';
import 'drawing.dart';

/// What a position box shows: the trader's own plan in numbers. Never a
/// suggestion, never odds.
class PositionFigures {
  const PositionFigures({required this.r, this.riskPct, this.riskMoney, this.size});

  /// Target distance over stop distance ("1 : 2.4").
  final double? r;

  /// The account's risk per trade, and that as money of its starting size.
  final double? riskPct;
  final double? riskMoney;

  /// Lots / contracts from [RiskSizing]; null when doji can't size it
  /// (unknown specs, no rate, stale rate). Never guessed.
  final double? size;

  /// [d] must be a position. [startingSize], [riskPct] and [currency] come
  /// from the active account.
  static PositionFigures of(
    Drawing d, {
    required Instrument? instrument,
    required double? startingSize,
    required double? riskPct,
    required String currency,
    required RateSource rates,
  }) {
    final stopDistance = (d.entry - d.stop!).abs();
    final targetDistance = (d.target! - d.entry).abs();
    final r = stopDistance == 0 ? null : targetDistance / stopDistance;
    final money = (startingSize != null && riskPct != null && startingSize > 0 && riskPct > 0)
        ? startingSize * riskPct / 100
        : null;
    final size = (instrument == null || money == null)
        ? null
        : RiskSizing.contractsForRisk(
            instrument: instrument,
            accountBalance: startingSize!,
            accountCurrency: currency,
            riskPercent: riskPct!,
            stopDistance: stopDistance,
            rates: rates,
          );
    return PositionFigures(r: r, riskPct: money == null ? null : riskPct, riskMoney: money, size: size);
  }
}
