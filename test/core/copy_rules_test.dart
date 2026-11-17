// One copy-rule list, two languages: the app's const and the edge functions'
// JSON must match, and every fixed line the functions can send must pass.
import 'dart:convert';
import 'dart:io';

import 'package:doji_app/core/copy_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Dart list and supabase/functions/_shared/copy_rules.json are the same', () {
    final json =
        jsonDecode(File('supabase/functions/_shared/copy_rules.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(kBannedPhrases, (json['banned'] as List).cast<String>());
  });

  test('breaksCopyRules catches calls with punctuation and lets plain words through', () {
    for (final s in ['you should buy here.', 'Sell, now', 'a clear signal', 'guaranteed', 'go short']) {
      expect(breaksCopyRules(s), isTrue, reason: s);
    }
    for (final s in ['london is open.', 'buyer', 'selling pressure', 'two of three conditions met']) {
      expect(breaksCopyRules(s), isFalse, reason: s);
    }
  });

  test("the functions' fallbacks and crisis line keep the copy rules", () {
    final guard = File('supabase/functions/_shared/guard.ts').readAsStringSync();
    final lines = RegExp(r'"([^"]{20,})"').allMatches(guard).map((m) => m.group(1)!).toList();
    expect(lines.any((l) => l.contains('SADAG') || l.contains('someone now')), isTrue);
    expect(lines.length, greaterThanOrEqualTo(4));
    for (final l in lines) {
      expect(breaksCopyRules(l), isFalse, reason: l);
    }
  });
}
