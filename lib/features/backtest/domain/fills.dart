import '../../markets/domain/candle.dart';

/// How a planned trade ended on history.
enum ExitReason {
  stop('stop'),
  target('target'),
  sessionEnd('session end'),
  maxBars('time limit'),

  /// Replay only: the trader removed the box after entry; closed at the next bar's open.
  closedByYou('closed by you'),

  /// Replay only: not resolved yet (the bars that would decide it are hidden).
  open('open');

  const ExitReason(this.label);

  final String label;

  static ExitReason fromName(String? n) => values.where((v) => v.name == n).firstOrNull ?? open;
}

/// A fill decided on one bar.
class Fill {
  const Fill(this.price, this.reason);

  final double price;
  final ExitReason reason;
}

/// The one rule for stops and targets on bars doji cannot see inside:
///
/// - a bar that opens past the stop (a gap) fills at its open, so a loss can
///   be bigger than 1R;
/// - **a bar that reaches both the stop and the target counts as the stop**:
///   the order inside a bar is unknown, so doji takes the worse one;
/// - a bar that opens past the target fills at its open.
///
/// [stopBelow] is true when the stop is under the entry. Null = still open.
Fill? fillOn(Candle bar, {required double stop, required double target, required bool stopBelow}) {
  if (stopBelow) {
    if (bar.open <= stop) return Fill(bar.open, ExitReason.stop);
    if (bar.low <= stop) return Fill(stop, ExitReason.stop);
    if (bar.open >= target) return Fill(bar.open, ExitReason.target);
    if (bar.high >= target) return Fill(target, ExitReason.target);
  } else {
    if (bar.open >= stop) return Fill(bar.open, ExitReason.stop);
    if (bar.high >= stop) return Fill(stop, ExitReason.stop);
    if (bar.open <= target) return Fill(bar.open, ExitReason.target);
    if (bar.low <= target) return Fill(target, ExitReason.target);
  }
  return null;
}

/// The result in R of leaving at [exit]: the stop distance is 1R.
double rOf({required double entry, required double stop, required double exit}) {
  final risk = (entry - stop).abs();
  if (risk == 0) return 0;
  return (stop < entry ? exit - entry : entry - exit) / risk;
}

/// The words the UI uses for the same-bar rule (copy-scanned).
const kSameBarRule = 'when a bar reaches both your stop and your target, doji counts the stop.';
const kGapRule = 'a bar that opens past your stop fills at its open, so a loss can be more than 1R.';
const kNoCosts = 'no spread or costs counted.';
