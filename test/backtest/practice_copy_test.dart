import 'dart:io';

import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/backtest/domain/fills.dart';
import 'package:doji_app/features/gym/domain/gym.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hit rates and verdicts are out: results are R and counts, and doji never
/// picks a version.
const _banned = [
  'win rate',
  'winrate',
  'hit rate',
  'best version',
  'better',
  'worse',
  'recommended',
  'profitable',
];

void main() {
  test('copy rules: every string in history, backtest, replay and gym', () {
    final single = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
    final double = RegExp(r'"((?:[^"\\\n]|\\.)*)"');
    final files = [
      for (final dir in ['history', 'backtest', 'replay', 'gym'])
        ...Directory(
          'lib/features/$dir',
        ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
    ];
    expect(files.length, greaterThan(10));
    var n = 0;
    for (final f in files) {
      for (final line in f.readAsLinesSync()) {
        if (line.trimLeft().startsWith('import ') || line.trimLeft().startsWith('//')) continue;
        for (final m in [...single.allMatches(line), ...double.allMatches(line)]) {
          final s = m.group(1)!;
          n++;
          expect(breaksCopyRules(s), isFalse, reason: '${f.path}: $s');
          for (final b in _banned) {
            expect(s.toLowerCase().contains(b), isFalse, reason: '${f.path}: "$b" in $s');
          }
        }
      }
    }
    expect(n, greaterThan(100));
  });

  test('copy rules: drill explanations and fill rules', () {
    const account = TradingAccount(
      id: 'a',
      name: 'a',
      rules: TradingRules(riskPerTrade: 1, maxTradesPerDay: 2, dailyLossLimit: 3),
    );
    final lines = [
      kSameBarRule,
      kGapRule,
      kNoCosts,
      for (final l in [1, 2, 3, 4]) ...[
        afterLossesDrill(account, losses: l).question,
        afterLossesDrill(account, losses: l).explain,
      ],
      afterLossesDrill(const TradingAccount(id: 'b', name: 'b'), losses: 2).explain,
    ];
    for (final s in lines) {
      expect(breaksCopyRules(s), isFalse, reason: s);
    }
  });
}
