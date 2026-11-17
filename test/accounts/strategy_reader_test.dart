// The strategy reader: Gemini's proposal checked again on the device, the
// keyword reader as the fallback.
import 'package:doji_app/core/ai/ai_functions.dart';
import 'package:doji_app/features/accounts/data/strategy_reader.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_ai.dart';

const _words = 'london breakout of the asian range on m15, wait for a close back. rsi under 30.';

void main() {
  test('the proposal keeps measurable kinds and manual rules in order', () async {
    final ai = FakeAi(
      (_, _) => {
        'parsed': {'setup': 'london breakout of the asian range', 'timeframe': 'M15'},
        'conditions': [
          {'kind': 'session', 'session': 'london'},
          {'kind': 'range_break', 'closeBack': true},
          {'kind': 'manual', 'text': 'rsi under 30'},
          {'kind': 'rsi_below'},
          {'kind': 'manual', 'text': 'a buy signal'},
        ],
      },
    );
    final p = await SupabaseStrategyReader(ai).propose(_words, sessions: const ['london']);
    expect(ai.calls.single.$2, {
      'words': _words,
      'sessions': ['london'],
    });
    expect(p.parsed.timeframe, 'M15');
    expect(p.conditions, const [
      StrategyCondition(kind: ConditionKind.session, session: 'london'),
      StrategyCondition(kind: ConditionKind.rangeBreak, closeBack: true),
      StrategyCondition(kind: ConditionKind.manual, text: 'rsi under 30'),
    ]);
  });

  test('a failure falls back to the on-device reader', () async {
    final p = await SupabaseStrategyReader(FakeAi((_, _) => throw const AiOffline())).propose(_words);
    final own = await const FakeStrategyReader().propose(_words);
    expect(p.parsed, own.parsed);
    expect(p.conditions, own.conditions);
  });

  test('it is also the parser onboarding and save use', () async {
    final ai = FakeAi(
      (_, _) => {
        'parsed': {'setup': 'new york breakout', 'stop': 'a guaranteed stop'},
        'conditions': <Object>[],
      },
    );
    final parsed = await SupabaseStrategyReader(ai).parse('new york breakout');
    expect(parsed.setup, 'new york breakout');
    expect(parsed.stop, isNull);
  });
}
