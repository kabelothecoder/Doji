import 'package:doji_app/features/onboarding/data/mock_strategy_parser.dart';
import 'package:doji_app/features/onboarding/domain/config_lines.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/domain/risk.dart';
import 'package:doji_app/features/onboarding/domain/rules.dart';
import 'package:doji_app/features/onboarding/domain/sessions.dart';
import 'package:doji_app/features/splash/domain/launch_destination.dart';
import 'package:doji_app/app/routes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample_profile.dart';

void main() {
  group('risk note (> 2%)', () {
    test('no note at or below 2%', () {
      expect(riskNote(null), isNull);
      expect(riskNote(0.5), isNull);
      expect(riskNote(1), isNull);
      expect(riskNote(2), isNull);
    });

    test('3% gets the handoff copy with computed numbers', () {
      expect(
        riskNote(3),
        '3% is above what most plans allow. three losses in a row is about 9% down. '
        "you can keep it; i'll remind you before sessions.",
      );
    });

    test('fractional risk formats cleanly', () {
      expect(riskNote(2.5), startsWith('2.5% is above'));
      expect(riskNote(2.5), contains('about 7.5% down'));
      expect(fmtPct(0.5), '0.5');
      expect(fmtPct(2.0), '2');
    });

    test('the note is calm: never blocks, never promises', () {
      final note = riskNote(5)!;
      expect(note, contains('you can keep it'));
      for (final banned in ['guarantee', 'signal', 'buy', 'sell', 'profit']) {
        expect(note.toLowerCase(), isNot(contains(banned)));
      }
    });
  });

  group('MockStrategyParser', () {
    const parser = MockStrategyParser(latency: Duration.zero);

    test('parses the handoff example exactly as the handoff shows', () async {
      final p = await parser.parse(
        'i wait for the asian range, then trade the london breakout after a retest on M15. '
        'stop under the range, target 2R.',
      );
      expect(p.setup, 'london breakout of the asian range');
      expect(p.timeframe, 'M15');
      expect(p.entry, 'retest of the broken level, candle closes beyond');
      expect(p.stop, 'under the asian range');
      expect(p.target, '2R');
      expect(p.slug, 'london_break');
    });

    test('recognises other styles and timeframe spellings', () {
      final smc = parser.parseSync(
        'i look for a liquidity sweep into an order block on the 15 min, sl below the sweep, 1:3',
      );
      expect(smc.setup, contains('smc/ict'));
      expect(smc.timeframe, 'M15');
      expect(smc.stop, 'below the sweep');
      expect(smc.target, '3R');

      final pullback = parser.parseSync('Trend pullback on the 4h. Engulfing candle to enter.');
      expect(pullback.setup, 'pullback in an established trend');
      expect(pullback.timeframe, 'H4');
      expect(pullback.entry, 'engulfing candle at the level');
    });

    test('unknown text keeps the user\'s own words as the setup', () {
      final p = parser.parseSync('i buy the dip when it looks cheap');
      expect(p.setup, 'i buy the dip when it looks cheap');
      expect(p.timeframe, isNull);
      expect(p.slug, 'custom');
    });

    test('empty text yields an empty, editable result', () async {
      expect((await parser.parse('   ')).isEmpty, isTrue);
    });
  });

  group('profile.doji lines', () {
    test('print like the handoff config for the example trader', () {
      final lines = buildConfigLines(answersBefore(StepIds.compile));
      String line(String k) {
        final l = lines.firstWhere((l) => l.keyName == k);
        return '${l.value}${l.comment}';
      }

      expect(line('name'), '"sam"');
      expect(line('experience'), '6-24m');
      expect(line('markets'), '[XAUUSD, NAS100]');
      expect(line('sessions'), '[london]  # UTC+2');
      expect(line('prop.size'), '50_000');
      expect(line('strategy'), 'london_break  # M15');
      expect(line('risk'), '3.0%  # above 2%');
      expect(line('ritual'), '08:30  # 30m pre-london');
      expect(lines.map((l) => l.number), [for (var i = 1; i <= lines.length; i++) i]);
    });
  });

  group('sessions', () {
    test('london opens 09:00 at UTC+2 (handoff example)', () {
      expect(hhmm(TradingSession.london.localOpen(120)!), '09:00');
      expect(firstSession(['new_york', 'london'], 120), TradingSession.london);
      expect(firstSession(['around_job'], 120), isNull);
      expect(ritualOptions(answersBefore(StepIds.ritual)).map((o) => o.value), ['08:30', '08:45', '09:00']);
    });

    test('utc labels', () {
      expect(utcLabel(0), 'UTC');
      expect(utcLabel(120), 'UTC+2');
      expect(utcLabel(-330), 'UTC-5:30');
    });
  });

  group('rules v1', () {
    test('summarise the plan in plain language', () {
      final rules = buildRules(answersBefore(StepIds.rules)).map((r) => r.text).toList();
      expect(rules, [
        'trade the london breakout of the asian range, M15 only.',
        'enter only after an M15 retest closes beyond the level.',
        'stop under the asian range. target 2R.',
        'risk 3% a trade. max 3 trades a day.',
        'stop for the day at -2%.',
      ]);
      expect(rulesTag(answersBefore(StepIds.rules)), 'LONDON BREAK · M15');
    });
  });

  group('launch routing', () {
    test('signed in → home', () {
      expect(decideLaunchRoute(signedIn: true, profileComplete: false, pausedAtStep: null), Routes.home);
    });
    test('finished on this device → home', () {
      expect(decideLaunchRoute(signedIn: false, profileComplete: true, pausedAtStep: null), Routes.home);
    });
    test('paused on save → save screen', () {
      expect(
        decideLaunchRoute(signedIn: false, profileComplete: false, pausedAtStep: StepIds.save),
        Routes.save,
      );
    });
    test('fresh or partial → onboarding (controller resumes the step)', () {
      expect(
        decideLaunchRoute(signedIn: false, profileComplete: false, pausedAtStep: null),
        Routes.onboarding,
      );
      expect(
        decideLaunchRoute(signedIn: false, profileComplete: false, pausedAtStep: StepIds.risk),
        Routes.onboarding,
      );
    });
  });

  group('copy rules', () {
    test('no buy/sell calls, signals, guarantees or profit promises in the script', () {
      final copy = <String>[];
      for (final s in buildOnboardingSteps()) {
        copy
          ..add(s.prompt)
          ..add(s.sub ?? '')
          ..add(s.cta)
          ..add(s.skipLabel)
          ..addAll(s.options.map((o) => o.label));
      }
      final text = copy.join(' ').toLowerCase();
      for (final banned in [' buy ', ' sell ', 'signal', 'guarantee', 'profit', 'win rate']) {
        expect(text, isNot(contains(banned)), reason: banned);
      }
    });
  });
}
