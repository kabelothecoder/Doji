import 'package:doji_app/features/backtest/domain/risk_of_ruin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only losses: every run is ruined', () {
    final rows = riskOfRuin([-1, -1], risks: [10], targetPct: 100, ruinPct: 50);
    expect(rows.single.ruined, 1000);
    expect(rows.single.reached, 0);
  });

  test('only wins: every run reaches the target', () {
    final rows = riskOfRuin([2], risks: [5], targetPct: 10, ruinPct: 10);
    expect(rows.single.reached, 1000);
  });

  test('same edge, more risk: more runs ruined', () {
    final rs = <double>[2, -1, -1, 2, -1, 3, -1, -1];
    final rows = riskOfRuin(rs, risks: [1, 20], targetPct: 100, ruinPct: 50);
    expect(rows[1].ruined, greaterThan(rows[0].ruined));
    for (final r in rows) {
      expect(r.reached + r.ruined + r.neither, 1000);
    }
  });

  test('seeded: same input, same table', () {
    final rs = <double>[1.5, -1, 2, -1];
    final a = riskOfRuin(rs, risks: [5], targetPct: 20, ruinPct: 20).single;
    final b = riskOfRuin(rs, risks: [5], targetPct: 20, ruinPct: 20).single;
    expect([a.reached, a.ruined], [b.reached, b.ruined]);
  });

  test('empty sample: no rows', () {
    expect(riskOfRuin([], risks: [1], targetPct: 10, ruinPct: 10), isEmpty);
  });
}
