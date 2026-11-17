// Copy rules: every string in the me tab, the share card and the badges.
import 'dart:io';

import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/me/domain/me.dart';
import 'package:flutter_test/flutter_test.dart';

/// The share card and badges never show money or rates.
const _banned = ['win rate', 'winrate', 'hit rate', 'profit', 'p&l', 'pnl', 'roi'];

void main() {
  test('copy rules: every string in lib/features/me', () {
    final single = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
    final dbl = RegExp(r'"((?:[^"\\\n]|\\.)*)"');
    final files = Directory(
      'lib/features/me',
    ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    var n = 0;
    for (final f in files) {
      for (final line in f.readAsLinesSync()) {
        final t = line.trimLeft();
        if (t.startsWith('import ') || t.startsWith('//')) continue;
        for (final m in [...single.allMatches(line), ...dbl.allMatches(line)]) {
          final s = m.group(1)!.toLowerCase();
          n++;
          expect(breaksCopyRules(s), isFalse, reason: '${f.path}: $s');
          for (final b in _banned) {
            expect(s.contains(b), isFalse, reason: '${f.path}: "$b" in $s');
          }
        }
      }
    }
    expect(n, greaterThan(40));
    for (final b in badgesFor(const [], const {}, const {})) {
      expect(breaksCopyRules('${b.title} ${b.line}'), isFalse);
    }
  });
}
