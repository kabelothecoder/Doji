import '../../plans/domain/plans.dart';

/// The free plan's "1 ai brief a day" (plans: `ai brief + chat` 1/day): the
/// first instrument whose brief is opened each day gets it, its chat
/// included; opening it again that day is free. Other instruments show the
/// brief locked until local midnight. Paid plans are unlimited.
///
/// Stored on this device. TODO(next-slice): metered by the `ai-brief` edge
/// function per account, so reinstalling doesn't reset it.
class BriefAllowance {
  const BriefAllowance({this.day, this.symbol});

  /// Local date the brief was used ('2026-10-24'); null = never.
  final String? day;

  /// Whose brief it was.
  final String? symbol;

  static String dayKey(DateTime now) {
    final l = now.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  bool usedOn(DateTime now) => day == dayKey(now);

  /// May [plan] see [symbol]'s brief at [now]? (Free: this is today's one,
  /// or today's one is still unused.)
  bool allows(PlanId plan, String symbol, DateTime now) =>
      plan != PlanId.free || !usedOn(now) || this.symbol == symbol;

  /// After opening [symbol]'s brief at [now]; unchanged when today's is already used.
  BriefAllowance use(String symbol, DateTime now) =>
      usedOn(now) ? this : BriefAllowance(day: dayKey(now), symbol: symbol);

  Map<String, Object?> toJson() => {'day': day, 'symbol': symbol};

  static BriefAllowance fromJson(Object? json) {
    if (json is! Map) return const BriefAllowance();
    final day = json['day'], symbol = json['symbol'];
    return BriefAllowance(day: day is String ? day : null, symbol: symbol is String ? symbol : null);
  }
}
