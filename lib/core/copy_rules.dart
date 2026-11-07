/// The copy rules (CLAUDE.md › no buy/sell language): phrases doji never
/// says, in UI copy, sample data or AI output.
///
/// The edge functions keep the same list in
/// `supabase/functions/_shared/copy_rules.json`; `test/core/copy_rules_test.dart`
/// fails when the two drift.
const List<String> kBannedPhrases = [
  ' buy ',
  ' sell ',
  'signal',
  'guarantee',
  'profit',
  'win rate',
  'go long',
  'go short',
];

final _punctuation = RegExp(r"[^a-z0-9'%\s-]");
final _spaces = RegExp(r'\s+');

/// True when [text] says something doji never says. Punctuation counts as a
/// space, so "sell." and "buy," are caught.
bool breaksCopyRules(String text) {
  final t = ' ${text.toLowerCase().replaceAll(_punctuation, ' ').replaceAll(_spaces, ' ')} ';
  return kBannedPhrases.any(t.contains);
}
