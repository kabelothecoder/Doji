// Mood and coach history at 1x and 2x text: no overflow, targets, labels.
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/coach/data/coach_session_repository.dart';
import 'package:doji_app/features/coach/domain/coach.dart';
import 'package:doji_app/features/coach/domain/coach_session.dart';
import 'package:doji_app/features/mood/data/mood_repository.dart';
import 'package:doji_app/features/mood/domain/mood.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';

/// Six entries around a loss, one saved coach session, on [summerDay].
Map<String, Object> moodSeed() {
  final now = summerDay.now();
  MoodEntry e(String f, int minutesAgo, {String? trade}) => MoodEntry(
    id: '$f$minutesAgo',
    feeling: f,
    intensity: 6,
    time: now.subtract(Duration(minutes: minutesAgo)),
    accountId: kFirstAccountId,
    tradeId: trade,
    moment: trade == null ? MoodMoment.checkIn : MoodMoment.afterTrade,
    note: f == 'calm' ? 'slept well, plan read' : '',
  );
  final start = now.subtract(const Duration(hours: 3));
  return {
    ...seedProfile(),
    ...seedJournal([sampleTrade(id: 'l', pnl: -50, minutesAgo: 120, now: now)]),
    MoodRepository.key: jsonEncode({
      'version': 1,
      'entries': [
        for (final m in [
          e('calm', 400),
          e('restless', 170),
          e('angry', 100, trade: 'l'),
          e('frustrated', 90, trade: 'l'),
          e('tired', 60 * 30),
          e('calm', 60 * 50),
        ])
          m.toJson(),
      ],
    }),
    PrefsCoachSessionRepository.key: jsonEncode({
      'version': 1,
      'sessions': [
        CoachSession(
          id: 's1',
          startedAt: start,
          voice: CoachVoice.coachTone,
          savedAt: start,
          turns: [
            CoachTurn(
              speaker: CoachSpeaker.coach,
              text: "sam, what's on your mind before the next trade?",
              at: start,
            ),
            CoachTurn(
              speaker: CoachSpeaker.you,
              text: 'why do I hesitate to enter?',
              at: start.add(const Duration(seconds: 6)),
            ),
          ],
        ).toJson(),
      ],
    }),
  };
}

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final route in [Routes.mood, Routes.coachHistory, Routes.coachTranscript('s1')]) {
      testWidgets('$route at ${scale}x text', (tester) async {
        await withClock(summerDay, () async {
          final h = await AppHarness.pump(tester, at: route, seed: moodSeed(), textScale: scale);
          await h.wait(300);
          expect(tester.takeException(), isNull, reason: 'no overflow at ${scale}x');
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          if (route == Routes.mood) expect(find.bySemanticsLabel('angry, 1'), findsWidgets);
        });
      }, variant: ios);
    }
  }
}
