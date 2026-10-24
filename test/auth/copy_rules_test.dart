// Product rule (CLAUDE.md): no buy/sell calls, signals, guarantees, win rates
// or profit promises. The onboarding script is checked in domain_test; this
// covers every string literal in the auth, app-lock and settings screens.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth, app lock and settings copy has no buy/sell calls, signals or promises', () {
    final dirs = [
      'lib/features/auth',
      'lib/features/app_lock',
      'lib/features/settings',
      'lib/features/plans',
    ];
    final literals = [RegExp(r"'(?:[^'\\\n]|\\.)*'"), RegExp(r'"(?:[^"\\\n]|\\.)*"')];
    final copy = <String>[];
    for (final dir in dirs) {
      for (final file in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final src = file.readAsStringSync();
        for (final re in literals) {
          copy.addAll(re.allMatches(src).map((m) => m.group(0)!));
        }
      }
    }
    expect(copy, contains("'welcome back.'"));
    final text = ' ${copy.join(' ').toLowerCase()} ';
    for (final banned in [' buy ', ' sell ', 'signal', 'guarantee', 'profit', 'win rate']) {
      expect(text, isNot(contains(banned)), reason: banned);
    }
  });
}
