// Product rule (CLAUDE.md): no buy/sell calls, signals, guarantees, win rates
// or profit promises. The onboarding script is checked in domain_test; this
// covers every string literal in the auth, app-lock, settings, plans and
// coach screens.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth, app lock and settings copy has no buy/sell calls, signals or promises', () {
    final dirs = [
      'lib/features/auth',
      'lib/features/app_lock',
      'lib/features/settings',
      'lib/features/plans',
      // The coach's screens; what the fake coach says is checked in coach_domain_test.
      'lib/features/coach/domain',
      'lib/features/coach/presentation',
      // Markets 1b's screens; what the fake brief and its chat say is checked in brief_test.
      'lib/features/markets/domain',
      'lib/features/markets/presentation',
      // Accounts and the strategy editor, and the conditions doji measures.
      'lib/features/accounts',
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
    expect(copy, contains("'before you start.'"), reason: 'A7 is scanned too');
    final text = ' ${copy.join(' ').toLowerCase()} ';
    for (final banned in [' buy ', ' sell ', 'signal', 'guarantee', 'profit', 'win rate']) {
      expect(text, isNot(contains(banned)), reason: banned);
    }
  });
}
