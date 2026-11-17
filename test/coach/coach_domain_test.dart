// The fake coach: what a message is about, replies built only from the
// trader's own plan and day, the crisis line first, the copy rules over every
// line it can say, and where saved sessions live.
import 'dart:convert';
import 'dart:io';

import 'package:doji_app/features/coach/data/coach_session_repository.dart';
import 'package:doji_app/features/coach/data/fake_coach.dart';
import 'package:doji_app/features/coach/domain/coach.dart';
import 'package:doji_app/features/coach/domain/coach_session.dart';
import 'package:doji_app/features/coach/data/voice_minutes_repository.dart';
import 'package:doji_app/features/coach/domain/session_summary.dart';
import 'package:doji_app/features/plans/domain/plans.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:doji_app/core/copy_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../journal/journal_fixtures.dart';
import '../helpers/sample_profile.dart';

/// A trader with a parsed strategy and rules, on a rough morning.
const _full = CoachContext(
  name: 'Sam',
  setup: 'london breakout of the asian range',
  entry: 'the M15 close',
  riskPerTradePct: 1,
  maxTradesPerDay: 3,
  dailyLossLimitPct: 2,
  struggles: ['revenge', 'fomo'],
  tradesToday: 2,
  lossStreak: 2,
  lossTodayPct: 1.5,
);

/// Nothing known: the coach asks instead of assuming.
const _empty = CoachContext();

void main() {
  group('intent', () {
    const cases = {
      'the break is right there. I want in before it runs.': CoachIntent.urge,
      "I'm scared to miss the move": CoachIntent.urge,
      'should I go long here?': CoachIntent.call,
      'is it going up from here': CoachIntent.call,
      'I just want to make it back': CoachIntent.revenge,
      'thinking of doubling... no, double my lot': CoachIntent.sizing,
      'can I move my stop a bit lower': CoachIntent.stop,
      "I keep hesitating, can't pull the trigger": CoachIntent.hesitation,
      "honestly I'm frustrated": CoachIntent.feeling,
      'just one more trade': CoachIntent.another,
      "I'm done for today": CoachIntent.done,
      'what a morning': CoachIntent.other,
    };
    for (final MapEntry(key: message, value: intent) in cases.entries) {
      test('"$message" → ${intent.name}', () => expect(FakeCoach.intentOf(message), intent));
    }

    test('the crisis line wins over everything else in the message', () {
      for (final m in [
        "I want to win it back or I'll kill myself",
        'sometimes I feel suicidal after days like this',
        "I don't want to be here anymore",
      ]) {
        expect(FakeCoach.intentOf(m), CoachIntent.crisis, reason: m);
      }
    });
  });

  group('replies', () {
    test("the urge: the trader's own entry rule, and the calm-day question (the handoff's line)", () {
      final r = FakeCoach.replyFor(CoachIntent.urge, _full);
      expect(
        r,
        "the move isn't your rule. your plan waits for the M15 close. what would you tell yourself on a calm day?",
      );
      expect(
        FakeCoach.replyFor(CoachIntent.urge, _empty),
        contains('what does your entry rule need to see first?'),
      );
    });

    test('revenge: the streak and the stricter daily limit, with how much is used', () {
      final r = FakeCoach.replyFor(CoachIntent.revenge, _full);
      expect(r, startsWith('2 losses in a row today. '));
      expect(r, contains("your limit is 2% today and you're at 1.5%."));
      expect(
        FakeCoach.replyFor(CoachIntent.revenge, _empty),
        startsWith('wanting it back is the loss talking'),
      );
    });

    test('another trade counts against the max; at the max, the rule says that was the day', () {
      expect(FakeCoach.replyFor(CoachIntent.another, _full), contains('trade 3 of 3 today'));
      const done = CoachContext(maxTradesPerDay: 3, tradesToday: 3);
      expect(FakeCoach.replyFor(CoachIntent.another, done), contains("you've taken 3 of 3 today"));
      expect(
        FakeCoach.replyFor(CoachIntent.another, _empty),
        'is the next one in your plan, or in your mood?',
      );
    });

    test('sizing names the planned risk; without one it asks', () {
      expect(FakeCoach.replyFor(CoachIntent.sizing, _full), contains('keep it at 1%?'));
      expect(FakeCoach.replyFor(CoachIntent.sizing, _empty), contains('what size does your plan say?'));
    });

    test('asked for a call, the coach declines and points at the plan', () {
      expect(FakeCoach.replyFor(CoachIntent.call, _full), startsWith("i don't call the market"));
    });

    test('crisis: the helpline, before anything about trading', () {
      final r = FakeCoach.replyFor(CoachIntent.crisis, _full);
      expect(r, contains('SADAG on 0800 567 567'));
      expect(r, isNot(contains('plan')));
    });

    test('open questions rotate so the coach does not repeat itself', () {
      final lines = {for (var i = 0; i < 3; i++) FakeCoach.replyFor(CoachIntent.other, _empty, turn: i)};
      expect(lines, hasLength(3));
    });

    test('the opener: tilt first, then the max, else the name', () {
      expect(FakeCoach.openerFor(_full), startsWith('2 losses in a row today.'));
      expect(
        FakeCoach.openerFor(const CoachContext(maxTradesPerDay: 2, tradesToday: 2)),
        contains('the plan is done for today'),
      );
      expect(
        FakeCoach.openerFor(const CoachContext(name: 'Sam')),
        "sam, what's on your mind before the next trade?",
      );
      expect(FakeCoach.openerFor(_empty), "what's on your mind before the next trade?");
    });

    test('reply() skips the latency at zero and rotates by the replies so far', () async {
      const coach = FakeCoach(latency: Duration.zero);
      final at = DateTime.utc(2026, 10, 12);
      final history = [CoachTurn(speaker: CoachSpeaker.coach, text: 'x', at: at)];
      expect(
        await coach.reply(_empty, history, 'hmm'),
        FakeCoach.replyFor(CoachIntent.other, _empty, turn: 1),
      );
    });
  });

  test(
    'copy rules: no buy/sell calls, signals, guarantees or profit promises in anything the coach says',
    () {
      final lines = <String>[];
      for (final c in [_full, _empty, const CoachContext(maxTradesPerDay: 3, tradesToday: 3)]) {
        lines.add(FakeCoach.openerFor(c));
        for (final intent in CoachIntent.values) {
          for (var turn = 0; turn < 3; turn++) {
            lines.add(FakeCoach.replyFor(intent, c, turn: turn));
          }
        }
      }
      final text = ' ${lines.join(' ').toLowerCase()} ';
      expect(breaksCopyRules(text), isFalse, reason: text);
    },
  );

  group('CoachContext.from', () {
    test("profile.doji and today's journal: the stricter limit, the streak, today's loss", () {
      final profile = profileWith(
        name: 'sam',
        strategy: const StrategyProfile(
          parsed: ParsedStrategy(setup: 'london break', entry: 'M15 retest'),
        ),
        rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
        prop: const PropRules(dailyLossLimitPct: 1),
        startingSize: 100000,
      );
      final c = CoachContext.from(
        profile,
        trades: [
          sampleTrade(id: 'a', pnl: -300, minutesAgo: 120),
          sampleTrade(id: 'b', pnl: -200, minutesAgo: 60),
          sampleTrade(id: 'old', pnl: -900, daysAgo: 1),
        ],
        now: journalNow,
      );
      expect(c.entry, 'M15 retest');
      expect(c.setup, 'london break');
      expect(c.dailyLossLimitPct, 1);
      expect(c.tradesToday, 2);
      expect(c.lossStreak, 2);
      expect(c.lossTodayPct, closeTo(0.5, 1e-9));
    });

    test('blank strategy fields read as unknown', () {
      final profile = profileWith(
        strategy: const StrategyProfile(parsed: ParsedStrategy(entry: '  ')),
      );
      expect(CoachContext.from(profile, trades: const [], now: journalNow).entry, isNull);
    });
  });

  test('voices: the stored value, else coach tone', () {
    expect(CoachVoice.of('calm_female'), CoachVoice.calmFemale);
    expect(CoachVoice.of(null), CoachVoice.coachTone);
    expect(CoachVoice.of('robot'), CoachVoice.coachTone);
  });

  group('saved sessions', () {
    final at = DateTime.utc(2026, 10, 12, 9);
    CoachSession session(String id, {int turns = 2}) => CoachSession(
      id: id,
      startedAt: at,
      voice: CoachVoice.calmMale,
      savedAt: at.add(const Duration(minutes: 3)),
      turns: [
        for (var i = 0; i < turns; i++)
          CoachTurn(
            speaker: i.isEven ? CoachSpeaker.coach : CoachSpeaker.you,
            text: 'line $i',
            at: at.add(Duration(seconds: i)),
          ),
      ],
    );

    test('json round trip; a broken turn is dropped, the rest stay', () {
      final json = jsonDecode(jsonEncode(session('a').toJson())) as Map<String, dynamic>;
      (json['turns'] as List).add({'speaker': 'robot', 'text': 1});
      final back = CoachSession.fromJson(json)!;
      expect(back.id, 'a');
      expect(back.voice, CoachVoice.calmMale);
      expect(back.turns.map((t) => t.text), ['line 0', 'line 1']);
      expect(back.turns.last.speaker, CoachSpeaker.you);
      expect(back.savedAt, at.add(const Duration(minutes: 3)));
      expect(CoachSession.fromJson('nope'), isNull);
    });

    test('repository: newest first, saving again replaces, clear empties, corrupt reads empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsCoachSessionRepository(prefs);
      expect(repo.load(), isEmpty);

      await repo.save(session('a'));
      await repo.save(session('b'));
      await repo.save(session('a', turns: 4));
      expect(repo.load().map((s) => (s.id, s.turns.length)), [('a', 4), ('b', 2)]);

      await repo.clear();
      expect(repo.load(), isEmpty);

      await prefs.setString(PrefsCoachSessionRepository.key, '{not json');
      expect(repo.load(), isEmpty);
    });
  });

  group('session summary', () {
    final t0 = DateTime.utc(2026, 7, 15, 9);
    CoachTurn you(String x, int s) => CoachTurn(
      speaker: CoachSpeaker.you,
      text: x,
      at: t0.add(Duration(seconds: s)),
    );
    CoachTurn coach(String x, int s) => CoachTurn(
      speaker: CoachSpeaker.coach,
      text: x,
      at: t0.add(Duration(seconds: s)),
    );

    test('topics are the lines the trader said (three at most); minutes round up', () {
      final s = SessionSummary.of(
        [coach('hi', 0), you('why do I hesitate to enter?', 5), you('a', 9), you('b', 20), you('c', 30)],
        startedAt: t0,
        endedAt: t0.add(const Duration(seconds: 61)),
      );
      expect(s.topics, ['why do I hesitate to enter?', 'a', 'b']);
      expect(s.minutes, 2);
      expect(s.focus, SessionSummary.focusFor[CoachIntent.hesitation]);
    });

    test('the focus follows the first concern in intent order; nothing named = read your rules', () {
      SessionSummary of(List<String> lines) =>
          SessionSummary.of([for (final l in lines) you(l, 1)], startedAt: t0, endedAt: t0);
      expect(
        of(['I want to double my lot', 'I want to win it back']).focus,
        SessionSummary.focusFor[CoachIntent.revenge],
      );
      expect(of(['hello']).focus, SessionSummary.focusFor[CoachIntent.other]);
      expect(of(['hello']).minutes, 1);
    });
  });

  test('distress: crisis words and lost-everything lines; ordinary tilt is not distress', () {
    expect(isDistress("i can't do this anymore. i've lost everything."), isTrue);
    expect(isDistress('I blew my account'), isTrue);
    expect(isDistress("honestly I don't want to be here anymore"), isTrue);
    expect(isDistress('I am frustrated, 3 losses'), isFalse);
    expect(isDistress('just one more trade'), isFalse);
  });

  group('voice minutes', () {
    test('pro gets 60 a month; elite (fair use) and free are not counted', () {
      expect(voiceMinutesLeft(PlanId.pro, 0), 60);
      expect(voiceMinutesLeft(PlanId.pro, 90), 58);
      expect(voiceMinutesLeft(PlanId.pro, 3600), 0);
      expect(voiceMinutesLeft(PlanId.pro, 9999), 0);
      expect(voiceMinutesLeft(PlanId.elite, 9999), isNull);
      expect(voiceMinutesLeft(PlanId.free, 0), isNull);
      expect(voiceMinutesResetOn(DateTime(2026, 11, 17)), '1 dec');
      expect(voiceMinutesResetOn(DateTime(2026, 12, 3)), '1 jan');
    });

    test('repository: counts per month, a new month starts at 0, clear empties', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = VoiceMinutesRepository(await SharedPreferences.getInstance());
      final nov = DateTime(2026, 11, 17);
      expect(await repo.add(const Duration(seconds: 45), nov), 45);
      expect(await repo.add(const Duration(seconds: 30), nov), 75);
      expect(repo.usedSeconds(DateTime(2026, 12, 1)), 0);
      await repo.clear();
      expect(repo.usedSeconds(nov), 0);
    });
  });

  test('copy rules: every string in lib/features/mood and the new coach files', () {
    final single = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
    final dbl = RegExp(r'"((?:[^"\\\n]|\\.)*)"');
    final files = [
      ...Directory('lib/features/mood').listSync(recursive: true).whereType<File>(),
      for (final f in [
        'domain/session_summary.dart',
        'data/voice_minutes_repository.dart',
        'presentation/session_summary_view.dart',
        'presentation/coach_history_screen.dart',
        'presentation/widgets/distress_card.dart',
        'presentation/coach_screen.dart',
      ])
        File('lib/features/coach/$f'),
    ].where((f) => f.path.endsWith('.dart'));
    var n = 0;
    for (final f in files) {
      for (final line in f.readAsLinesSync()) {
        final t = line.trimLeft();
        if (t.startsWith('import ') || t.startsWith('//')) continue;
        for (final m in [...single.allMatches(line), ...dbl.allMatches(line)]) {
          n++;
          expect(breaksCopyRules(m.group(1)!), isFalse, reason: '${f.path}: ${m.group(1)}');
        }
      }
    }
    expect(n, greaterThan(60));
    for (final line in SessionSummary.focusFor.values) {
      expect(breaksCopyRules(line), isFalse, reason: line);
    }
  });
}
