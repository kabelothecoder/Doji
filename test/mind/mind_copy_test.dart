// Copy rules: every string in lib/features/mind, and every catalogue entry and scorecard line.
import 'dart:io';

import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/mind/domain/mind_catalog.dart';
import 'package:doji_app/features/mind/domain/scorecard.dart';
import 'package:flutter_test/flutter_test.dart';

/// Discipline only: no money, no rates, no promises.
const _banned = ['win rate', 'winrate', 'hit rate', 'p&l', 'pnl', 'roi', 'money', 'balance', 'return'];

void _check(String where, String s) {
  final t = s.toLowerCase();
  expect(breaksCopyRules(t), isFalse, reason: '$where: $s');
  for (final b in _banned) {
    expect(t.contains(b), isFalse, reason: '$where: "$b" in $s');
  }
}

void main() {
  test('copy rules: every string in lib/features/mind', () {
    final single = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
    final dbl = RegExp(r'"((?:[^"\\\n]|\\.)*)"');
    final files = Directory(
      'lib/features/mind',
    ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    var n = 0;
    for (final f in files) {
      for (final line in f.readAsLinesSync()) {
        final t = line.trimLeft();
        if (t.startsWith('import ') || t.startsWith('//')) continue;
        for (final m in [...single.allMatches(line), ...dbl.allMatches(line)]) {
          n++;
          _check(f.path, m.group(1)!);
        }
      }
    }
    expect(n, greaterThan(60));
  });

  test('copy rules: the catalogue and the scorecard, lowercase where doji wrote it', () {
    for (final p in kMindPrompts) {
      _check('prompt ${p.id}', p.text);
      expect(p.text, p.text.toLowerCase());
    }
    for (final a in kAffirmations) {
      _check('affirmation ${a.id}', a.text);
      expect(a.text, a.text.toLowerCase());
    }
    for (final r in kReading) {
      _check('reading ${r.id}', [r.title, r.summary, ?r.author, ...r.paragraphs].join(' '));
      if (!r.isBook) expect(r.title, r.title.toLowerCase());
    }
    final card = Scorecard.of(trades: const [], account: null, moods: const [], now: DateTime(2026, 7, 15));
    for (final l in card.lines) {
      _check('scorecard', '${l.title} ${l.line}');
    }
  });
}
