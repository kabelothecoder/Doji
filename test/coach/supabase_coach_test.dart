// SupabaseCoach: sends only measured facts, uses the function's words, and
// falls back to the on-device coach on any failure or a reply that breaks the
// copy rules.
import 'package:doji_app/core/ai/ai_functions.dart';
import 'package:doji_app/features/coach/data/fake_coach.dart';
import 'package:doji_app/features/coach/data/supabase_coach.dart';
import 'package:doji_app/features/coach/domain/coach.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_ai.dart';

const _c = CoachContext(name: 'sam', maxTradesPerDay: 3, tradesToday: 1, riskPerTradePct: 1);
const _fake = FakeCoach(latency: Duration.zero);

void main() {
  test('opener and reply come from ai-coach with the facts', () async {
    final ai = FakeAi((_, _) => {'reply': 'one trade so far. what does your plan say?', 'crisis': false});
    final coach = SupabaseCoach(ai);
    expect(await coach.opener(_c), 'one trade so far. what does your plan say?');
    final history = [CoachTurn(speaker: CoachSpeaker.coach, text: 'hi', at: DateTime.utc(2026))];
    await coach.reply(_c, history, 'feeling the urge');
    final (name, body) = ai.calls.last;
    expect(name, 'ai-coach');
    expect(body['message'], 'feeling the urge');
    expect((body['context']! as Map)['tradesToday'], 1);
    expect(body['history'], [
      {'speaker': 'coach', 'text': 'hi'},
    ]);
  });

  test('a failure falls back to the on-device coach', () async {
    for (final failure in const <AiFailure>[AiOffline(), AiRateLimited(), AiNoSession(), AiUnavailable()]) {
      final coach = SupabaseCoach(FakeAi((_, _) => throw failure));
      expect(
        await coach.reply(_c, const [], 'should i go long?'),
        await _fake.reply(_c, const [], 'should i go long?'),
      );
    }
  });

  test('a reply that still breaks the copy rules is never shown', () async {
    final coach = SupabaseCoach(FakeAi((_, _) => {'reply': 'time to buy now.'}));
    final r = await coach.reply(_c, const [], 'hm');
    expect(r, isNot(contains('buy')));
    expect(r, await _fake.reply(_c, const [], 'hm'));
  });
}
