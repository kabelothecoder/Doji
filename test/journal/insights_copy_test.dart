// Copy rules: every string in the insights and import files, and every line the rules write.
import 'dart:io';

import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/journal/domain/insights.dart';
import 'package:flutter_test/flutter_test.dart';

import 'insights_fixtures.dart';

/// R only: no money, no rates, no forecasts.
const _banned = ['win rate', 'hit rate', '% of the time', 'p&l', 'will ', 'consider ', 'should '];

void _check(String where, String s) {
  final t = s.toLowerCase();
  expect(breaksCopyRules(t), isFalse, reason: '$where: $s');
  for (final b in _banned) {
    expect(t.contains(b), isFalse, reason: '$where: "$b" in $s');
  }
}

void main() {
  test('copy rules: every string in the insights slice', () {
    final single = RegExp(r"'((?:[^'\\n]|\.)*)'");
    final dbl = RegExp(r'"((?:[^"\\n]|\.)*)"');
    var n = 0;
    for (final path in [
      'lib/features/journal/domain/insights.dart',
      'lib/features/journal/data/insights_repository.dart',
      'lib/features/journal/data/trade_import.dart',
      'lib/features/journal/presentation/insights_screen.dart',
      'lib/features/journal/presentation/widgets/imported_trade_banner.dart',
    ]) {
      for (final line in File(path).readAsLinesSync()) {
        final t = line.trimLeft();
        if (t.startsWith('import ') || t.startsWith('//')) continue;
        for (final m in [...single.allMatches(line), ...dbl.allMatches(line)]) {
          n++;
          _check(path, m.group(1)!);
        }
      }
    }
    expect(n, greaterThan(60));
  });

  test('copy rules: headlines, how lines, notes and rules on fixtures', () {
    final found = findInsights(insightTrades(DateTime(2026, 7, 15, 12)));
    expect(found, isNotEmpty);
    for (final i in found) {
      _check(i.id, [i.headline, ...i.how, i.rule, ?i.note].join(' '));
    }
  });
}
