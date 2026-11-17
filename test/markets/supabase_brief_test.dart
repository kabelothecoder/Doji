// SupabaseBrief / SupabaseBriefChat: the model writes only 01, 02, 04 and the
// follow-ups; measured parts stay; failures and copy-rule breaks keep the
// device's own text; the server's "brief used" locks the rest of the day.
import 'package:doji_app/core/ai/ai_functions.dart';
import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/markets/data/supabase_brief.dart';
import 'package:doji_app/features/markets/domain/pair_brief.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/plans/domain/plans.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_ai.dart';

final _now = DateTime.utc(2026, 7, 15, 9);

final _measured = PairBrief(
  symbol: 'EURUSD',
  updatedAt: _now,
  context: 'own context.',
  strategyName: 'london break',
  strategy: 'own strategy.',
  conditions: const [EntryCondition('London session is open', ConditionStatus.met)],
  riskNote: 'own risk note.',
  checkAgain: null,
  followUps: const ['own question?'],
  levels: null,
  nextNews: null,
  dayDone: false,
);

class _Measure implements BriefSource {
  @override
  Future<PairBrief> brief(BriefRequest request) async => _measured;
}

class _Chat implements BriefChat {
  @override
  Future<String> reply(
    PairBrief brief,
    BriefRequest request,
    List<BriefTurn> history,
    String message,
  ) async => 'own answer.';
}

final _request = BriefRequest(symbol: 'EURUSD', profile: const ProfileDoji(), trades: const [], now: _now);

SupabaseBrief _brief(FakeAi ai, {void Function(String)? onUsed}) => SupabaseBrief(
  ai,
  measure: _Measure(),
  plan: () => PlanId.free,
  zone: () => 'Africa/Johannesburg',
  onBriefUsed: onUsed ?? (_) {},
);

void main() {
  test('the written sections come from ai-brief; conditions stay measured', () async {
    final ai = FakeAi(
      (_, _) => {
        'context': 'london is open.',
        'strategy': 'one of one met.',
        'riskNote': '1% a trade.',
        'followUps': ['what next?'],
      },
    );
    final b = await _brief(ai).brief(_request);
    expect(
      [b.context, b.strategy, b.riskNote, b.followUps],
      [
        'london is open.',
        'one of one met.',
        '1% a trade.',
        ['what next?'],
      ],
    );
    expect(b.conditions, _measured.conditions);
    final body = ai.calls.single.$2;
    expect(body['plan'], 'free');
    expect(body['zone'], 'Africa/Johannesburg');
    expect((body['facts']! as Map)['conditions'], [
      {'text': 'London session is open', 'status': 'met'},
    ]);
  });

  test('null fields, a copy-rule break or a failure keep the device text', () async {
    var b = await _brief(
      FakeAi((_, _) => {'context': null, 'strategy': 'a clear sell signal.'}),
    ).brief(_request);
    expect(
      [b.context, b.strategy, b.riskNote, b.followUps],
      [
        'own context.',
        'own strategy.',
        'own risk note.',
        ['own question?'],
      ],
    );
    b = await _brief(FakeAi((_, _) => throw const AiOffline())).brief(_request);
    expect(b.context, 'own context.');
  });

  test("the server's brief-used locks the day", () async {
    String? used;
    final b = await _brief(
      FakeAi((_, _) => throw const AiBriefUsed()),
      onUsed: (s) => used = s,
    ).brief(_request);
    expect(used, 'EURUSD');
    expect(b.context, 'own context.');
  });

  test('the chat answers from ai-brief-chat, else the on-device chat', () async {
    SupabaseBriefChat chat(FakeAi ai) =>
        SupabaseBriefChat(ai, fallback: _Chat(), plan: () => PlanId.pro, zone: () => 'UTC');
    expect(
      await chat(FakeAi((_, _) => {'reply': 'the close back.'})).reply(_measured, _request, const [], 'q'),
      'the close back.',
    );
    expect(
      await chat(FakeAi((_, _) => {'reply': 'go long here.'})).reply(_measured, _request, const [], 'q'),
      'own answer.',
    );
    expect(
      await chat(FakeAi((_, _) => throw const AiRateLimited())).reply(_measured, _request, const [], 'q'),
      'own answer.',
    );
  });

  test('copy rules: nothing the brief sends to the functions is a call', () {
    final facts = briefFacts(_measured, _request);
    expect(breaksCopyRules(facts.toString()), isFalse);
  });
}
