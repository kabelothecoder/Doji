import 'dart:io';

import 'package:doji_app/core/ai/ai_functions.dart';
import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/chart/data/copilot_service.dart';
import 'package:doji_app/features/chart/domain/copilot.dart';
import 'package:doji_app/features/chart/domain/drawing.dart';
import 'package:doji_app/features/chart/presentation/pre_trade_check_sheet.dart';
import 'package:doji_app/features/coach/domain/coach.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/pair_brief.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime.utc(2026, 7, 15, 8);

CopilotRequest req({
  String reason = 'order block on the 15m',
  String words = 'i take order blocks only after a london sweep. risk 1% a trade.',
  List<EntryCondition> conditions = const [EntryCondition('London session is open', ConditionStatus.met)],
  CoachContext coach = const CoachContext(maxTradesPerDay: 3, dailyLossLimitPct: 2),
  DrawingKind kind = DrawingKind.zone,
}) => CopilotRequest(
  symbol: 'EURUSD',
  timeframe: Timeframe.m15,
  drawing: Drawing(
    id: 'd',
    kind: kind,
    a: ChartPoint(t0, 1.085),
    b: ChartPoint(t0.add(const Duration(hours: 2)), 1.084),
    stop: kind == DrawingKind.position ? 1.083 : null,
    target: kind == DrawingKind.position ? 1.089 : null,
  ),
  reason: reason,
  strategyWords: words,
  conditions: conditions,
  coach: coach,
);

class _Ai implements AiFunctions {
  _Ai(this.answer);

  final Object answer;
  Map<String, Object?>? body;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> body) async {
    this.body = body;
    final a = answer;
    if (a is AiFailure) throw a;
    return a as Map<String, dynamic>;
  }
}

/// Every replay the fake can give, over the inputs that steer it.
List<String> fakeReplies() => [
  for (final r in [
    req(),
    req(reason: 'something else entirely'),
    req(words: ''),
    req(words: 'buy the dip when it looks strong'),
    req(coach: const CoachContext(maxTradesPerDay: 3, tradesToday: 3)),
    req(coach: const CoachContext(dailyLossLimitPct: 2, lossTodayPct: 2.5)),
    req(coach: const CoachContext(lossStreak: 2)),
    req(
      conditions: const [EntryCondition('Price closes back above the Asian high', ConditionStatus.waiting)],
      words: '',
    ),
    req(reason: 'i want to die'),
    for (final k in DrawingKind.values) req(kind: k, words: ''),
  ])
    FakeCopilot.replyFor(r).text,
];

void main() {
  group('fake co-pilot', () {
    test('holds the reason up against the trader\'s own rule', () {
      final r = FakeCopilot.replyFor(req());
      expect(r.text, 'your rules say: "i take order blocks only after a london sweep". was that there?');
      expect(r.kind, CopilotKind.rule);
    });

    test('limits come first, plainly', () {
      expect(
        FakeCopilot.replyFor(req(coach: const CoachContext(maxTradesPerDay: 3, tradesToday: 3))).text,
        "that's 3 of 3 trades today. your rules say the day is done.",
      );
      expect(
        FakeCopilot.replyFor(req(coach: const CoachContext(dailyLossLimitPct: 2, lossTodayPct: 2))).text,
        contains('daily loss limit (2%)'),
      );
    });

    test('a strategy sentence with banned words is never quoted back', () {
      final r = FakeCopilot.replyFor(req(words: 'buy the order block when it looks strong'));
      expect(breaksCopyRules(r.text), isFalse);
      expect(r.text, 'what in your plan does this zone mark?');
    });

    test('crisis words get the helpline before anything else', () {
      final r = FakeCopilot.replyFor(req(reason: 'honestly i want to die'));
      expect(r.crisis, isTrue);
      expect(r.text, contains('0800 567 567'));
    });

    test('with no written strategy it asks which rule the mark belongs to', () {
      expect(
        FakeCopilot.replyFor(req(words: '', conditions: const [])).text,
        'which rule in your plan does this zone belong to?',
      );
    });
  });

  group('supabase co-pilot', () {
    test('sends the drawing, the reason, the strategy and the facts', () async {
      final ai = _Ai({'reply': 'was there a london sweep first?', 'kind': 'rule'});
      final r = await SupabaseCopilot(ai).reflect(req(kind: DrawingKind.position));
      expect(r.text, 'was there a london sweep first?');
      expect(r.kind, CopilotKind.rule);
      final body = ai.body!;
      expect(body['reason'], 'order block on the 15m');
      expect(body['timeframe'], 'M15');
      expect((body['drawing']! as Map)['kind'], 'position');
      expect(((body['drawing']! as Map)['position']! as Map)['stop'], 1.083);
      expect((body['strategy']! as Map)['words'], contains('london sweep'));
      expect((body['facts']! as Map)['maxTradesPerDay'], 3);
    });

    test('a reply that rates the odds or breaks the copy rules is replaced', () async {
      for (final bad in ['that is a high-quality setup', 'price will reach it', 'good spot to buy now']) {
        final r = await SupabaseCopilot(_Ai({'reply': bad, 'kind': 'rule'})).reflect(req());
        expect(r.text, FakeCopilot.replyFor(req()).text, reason: bad);
      }
    });

    test('the daily limit says so; any other failure answers on the device', () async {
      expect((await SupabaseCopilot(_Ai(const AiRateLimited())).reflect(req())).text, kCopilotLimitLine);
      expect(
        (await SupabaseCopilot(_Ai(const AiOffline())).reflect(req())).text,
        FakeCopilot.replyFor(req()).text,
      );
    });
  });

  test('copy rules: every co-pilot line, fallback and limit line', () {
    final lines = [
      ...fakeReplies(),
      kCopilotFallback,
      kCopilotLimitLine,
      ...limitLines(
        const CoachContext(
          maxTradesPerDay: 3,
          tradesToday: 3,
          dailyLossLimitPct: 2,
          lossTodayPct: 3,
          lossStreak: 2,
        ),
      ),
    ];
    for (final l in lines) {
      expect(breaksCopyRules(l), isFalse, reason: l);
      expect(ratesOdds(l), isFalse, reason: l);
    }
  });

  test('copy rules: every string in the chart feature', () {
    final single = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
    final double = RegExp(r'"((?:[^"\\\n]|\\.)*)"');
    final files = Directory(
      'lib/features/chart',
    ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    var count = 0;
    for (final f in files) {
      final src = f
          .readAsStringSync()
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('import') && !l.trimLeft().startsWith('//'));
      for (final line in src) {
        for (final m in [...single.allMatches(line), ...double.allMatches(line)]) {
          final s = m[1]!;
          // The odds pattern itself lists the words it bans.
          if (s.contains(r'\b') || s.contains('setup|')) continue;
          count++;
          expect(breaksCopyRules(s), isFalse, reason: '${f.path}: $s');
          expect(ratesOdds(s), isFalse, reason: '${f.path}: $s');
        }
      }
    }
    expect(count, greaterThan(50));
  });
}
