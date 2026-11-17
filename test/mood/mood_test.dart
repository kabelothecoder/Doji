// Mood: the entry model and its store, trends on fixtures, and the flows that
// log a feeling (check-in, The Open, the post-trade sheet against a trade).
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/auth/presentation/auth_controller.dart';
import 'package:doji_app/features/mood/data/mood_repository.dart';
import 'package:doji_app/features/mood/domain/mood.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../journal/journal_fixtures.dart';

final _now = DateTime.utc(2026, 7, 15, 12);

MoodEntry _e(String feeling, Duration ago, {String id = 'x'}) =>
    MoodEntry(id: '$id$feeling${ago.inMinutes}', feeling: feeling, time: _now.subtract(ago), intensity: 5);

void main() {
  group('MoodEntry', () {
    test('json round trip; a broken record is skipped; intensity is clamped', () async {
      final e = MoodEntry(
        id: 'a',
        feeling: 'anxious',
        intensity: 7,
        note: 'after the news',
        time: _now,
        accountId: 'acc',
        tradeId: 't1',
        moment: MoodMoment.afterTrade,
      );
      final back = MoodEntry.fromJson(jsonDecode(jsonEncode(e.toJson())))!;
      expect(
        [back.feeling, back.intensity, back.note, back.accountId, back.tradeId, back.moment],
        ['anxious', 7, 'after the news', 'acc', 't1', MoodMoment.afterTrade],
      );
      expect(back.time, _now);
      expect(
        MoodEntry.fromJson({'id': 'b', 'feeling': 'calm', 'time': '$_now', 'intensity': 40})!.intensity,
        10,
      );
      expect(MoodEntry.fromJson({'id': 'b', 'feeling': 'calm', 'time': '$_now'})!.intensity, isNull);
      expect(MoodEntry.fromJson({'feeling': 'calm'}), isNull);

      SharedPreferences.setMockInitialValues({
        MoodRepository.key: jsonEncode({
          'version': 1,
          'entries': [
            {'nope': 1},
            e.toJson(),
            _e('calm', const Duration(hours: 1)).toJson(),
          ],
        }),
      });
      final repo = MoodRepository(await SharedPreferences.getInstance());
      expect(repo.load().map((m) => m.feeling), ['anxious', 'calm'], reason: 'newest first, broken skipped');
      await repo.clear();
      expect(repo.load(), isEmpty);
    });
  });

  group('trends', () {
    test('counts per feeling over 7 and 28 days, most first', () {
      final t = MoodTrends.of(
        [
          _e('anxious', const Duration(days: 1)),
          _e('anxious', const Duration(days: 2), id: 'y'),
          _e('calm', const Duration(days: 3)),
          _e('tired', const Duration(days: 10)),
          _e('calm', const Duration(days: 20), id: 'y'),
          _e('bored', const Duration(days: 40)),
        ],
        const [],
        _now,
      );
      expect(t.week.counts, [('anxious', 2), ('calm', 1)]);
      expect(t.week.total, 3);
      expect(t.week.smallSample, isTrue);
      expect(t.month.counts, [('calm', 2), ('anxious', 2), ('tired', 1)]);
      expect(t.month.smallSample, isFalse);
    });

    test('before vs after losses: the hour before a losing trade opened, the hour after it closed', () {
      // A loss closed 2h ago (opened 2h30 ago); a win closed 5h ago.
      final loss = sampleTrade(id: 'l', pnl: -50, minutesAgo: 120, now: _now);
      final win = sampleTrade(id: 'w', pnl: 50, minutesAgo: 300, now: _now);
      final t = MoodTrends.of(
        [
          _e('restless', const Duration(minutes: 170)), // 20 min before the loss opened
          _e('angry', const Duration(minutes: 90)), // 30 min after it closed
          _e('angry', const Duration(minutes: 80), id: 'y'),
          _e('calm', const Duration(minutes: 290)), // after the win: neither
          _e('tired', const Duration(minutes: 10)), // 110 min after: outside
        ],
        [loss, win],
        _now,
      );
      expect(t.beforeLoss.counts, [('restless', 1)]);
      expect(t.afterLoss.counts, [('angry', 2)]);
      expect(t.afterLoss.smallSample, isTrue);
    });

    test('latestTradeToday: the newest trade opened today, else none', () {
      final now = DateTime(2026, 7, 15, 15);
      final a = sampleTrade(id: 'a', pnl: 1, minutesAgo: 200, now: now);
      final b = sampleTrade(id: 'b', pnl: 1, minutesAgo: 30, now: now);
      final old = sampleTrade(id: 'o', pnl: 1, daysAgo: 1, now: now);
      expect(latestTradeToday([a, old, b], now), 'b');
      expect(latestTradeToday([old], now), isNull);
    });
  });

  group('flows', () {
    testWidgets('journal › mood: check in, the tracker shows it, trends say small sample', (tester) async {
      final h = await AppHarness.pump(tester, at: Routes.journal, seed: seedProfile());
      await h.tapText('mood · check in and trends');
      expect(h.location, Routes.mood);
      expect(find.text('nothing logged yet. a check-in takes ten seconds.'), findsOneWidget);
      await h.tapText('focused');
      await tester.enterText(find.byType(TextField), 'slept well');
      await h.tapText('log it');
      final saved = h.container.read(moodControllerProvider).single;
      expect(
        [saved.feeling, saved.intensity, saved.note, saved.moment],
        ['focused', 5, 'slept well', MoodMoment.checkIn],
      );
      expect(saved.accountId, isNotNull);
      expect(find.text('focused 5 · check-in'), findsOneWidget);
      expect(find.textContaining('1 entry · small sample'), findsWidgets);
      expect(h.prefs.getString(MoodRepository.key), contains('focused'));
    }, variant: ios);

    testWidgets("the open's mood step logs a MoodEntry", (tester) async {
      final h = await AppHarness.pump(tester, at: Routes.open, seed: seedProfile());
      await h.tapText('calm');
      await h.tapText('continue');
      final e = h.container.read(moodControllerProvider).single;
      expect([e.feeling, e.moment, e.intensity], ['calm', MoodMoment.open, null]);
    }, variant: ios);

    testWidgets('the post-trade sheet logs against the trade taken today', (tester) async {
      await withClock(summerDay, () async {
        final h = await AppHarness.pump(
          tester,
          at: Routes.home,
          seed: {
            ...seedProfile(),
            ...seedJournal([sampleTrade(id: 'today', pnl: -40, minutesAgo: 30, now: summerDay.now())]),
          },
          size: const Size(1280, 800),
        );
        await h.tapText('log emotion');
        await h.tapText('frustrated');
        await h.tapText('save');
        final e = h.container.read(moodControllerProvider).single;
        expect(
          [e.feeling, e.moment, e.tradeId, e.intensity],
          ['frustrated', MoodMoment.afterTrade, 'today', 6],
        );
      });
    }, variant: ios);

    testWidgets('sign out clears mood and voice minutes', (tester) async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.journal,
        seed: {
          ...seedProfile(),
          ...seedSession(),
          MoodRepository.key: jsonEncode({
            'entries': [_e('calm', Duration.zero).toJson()],
          }),
          'doji.voice_minutes.v1': jsonEncode({'month': '2026-07', 'seconds': 60}),
        },
      );
      expect(h.container.read(moodControllerProvider), hasLength(1));
      await h.container.read(accountActionsProvider).signOut();
      expect(h.prefs.getString(MoodRepository.key), isNull);
      expect(h.prefs.getString('doji.voice_minutes.v1'), isNull);
      expect(h.container.read(moodControllerProvider), isEmpty);
    }, variant: ios);
  });
}
