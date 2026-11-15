import 'process_grade.dart';
import 'trade.dart';

/// How often the plan was kept on one strategy version (design/research-intake-plan.md › 2b).
/// A process measure from the trader's own reviews; never a hit rate.
class PlanKept {
  const PlanKept({
    required this.version,
    required this.trades,
    required this.reviewed,
    required this.kept,
    required this.r,
  });

  /// Null = trades saved before versions were recorded.
  final int? version;
  final int trades;

  /// Trades with a review that says whether the plan was followed.
  final int reviewed;

  /// Reviews that say yes (partly is not kept).
  final int kept;

  /// Net R over the trades that have one.
  final double r;

  String get line {
    final v = version == null ? 'before versions' : 'version $version';
    if (reviewed == 0) return '$v · $trades trades, none reviewed yet';
    return '$v · plan kept on $kept of $reviewed reviewed trades';
  }

  /// One entry per version on [accountId], newest version first.
  static List<PlanKept> byVersion(Iterable<Trade> trades, String accountId) {
    final groups = <int?, List<Trade>>{};
    for (final t in trades) {
      if (t.accountId == accountId) (groups[t.strategyVersion] ??= []).add(t);
    }
    final keys = groups.keys.toList()..sort((a, b) => (b ?? 0).compareTo(a ?? 0));
    return [
      for (final k in keys)
        PlanKept(
          version: k,
          trades: groups[k]!.length,
          reviewed: groups[k]!.where((t) => t.plan != null).length,
          kept: groups[k]!.where((t) => t.plan == PlanFollowed.yes).length,
          r: groups[k]!.fold(0.0, (s, t) => s + (t.r ?? 0)),
        ),
    ];
  }
}
