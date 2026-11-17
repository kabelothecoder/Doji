import 'dart:math';

/// How many of [runs] resampled futures reached the target first, hit the
/// ruin line first, or neither within [horizon] trades.
class RuinRow {
  const RuinRow({required this.riskPct, required this.reached, required this.ruined, required this.runs});

  final double riskPct;
  final int reached;
  final int ruined;
  final int runs;

  int get neither => runs - reached - ruined;
}

/// Risk of ruin from the trader's own R results: each run draws trades at
/// random (with replacement) from [rs] and plays them at a fixed risk until the
/// balance is up [targetPct] or down [ruinPct] from the start, or [horizon]
/// trades pass. Seeded, so the same sample gives the same table.
///
/// shortcut: risk is a fixed % of the starting size (as prop firms and
/// [LimitsCheck] count it), not of the running balance; add compounding when
/// a personal-account growth plan needs it.
List<RuinRow> riskOfRuin(
  List<double> rs, {
  required List<double> risks,
  required double targetPct,
  required double ruinPct,
  int horizon = 200,
  int runs = 1000,
  int seed = 7,
}) {
  if (rs.isEmpty || targetPct <= 0 || ruinPct <= 0) return const [];
  return [for (final risk in risks) _row(rs, risk, targetPct, ruinPct, horizon, runs, Random(seed))];
}

RuinRow _row(List<double> rs, double risk, double target, double ruin, int horizon, int runs, Random rng) {
  var reached = 0, ruined = 0;
  for (var run = 0; run < runs; run++) {
    var pct = 0.0;
    for (var i = 0; i < horizon; i++) {
      pct += rs[rng.nextInt(rs.length)] * risk;
      if (pct <= -ruin) {
        ruined++;
        break;
      }
      if (pct >= target) {
        reached++;
        break;
      }
    }
  }
  return RuinRow(riskPct: risk, reached: reached, ruined: ruined, runs: runs);
}
