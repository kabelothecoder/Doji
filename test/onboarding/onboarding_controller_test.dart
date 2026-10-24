import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/sample_profile.dart';

void main() {
  late SharedPreferences prefs;

  Future<ProviderContainer> make([Map<String, Object> seed = const {}]) async {
    SharedPreferences.setMockInitialValues(seed);
    prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: testOverrides(prefs));
    addTearDown(c.dispose);
    return c;
  }

  OnboardingController ctrl(ProviderContainer c) => c.read(onboardingControllerProvider.notifier);
  OnboardingState st(ProviderContainer c) => c.read(onboardingControllerProvider);

  group('next', () {
    test('starts at boot and walks the script in order', () async {
      final c = await make();
      expect(st(c).currentId, StepIds.boot);
      await ctrl(c).submit();
      expect(st(c).currentId, StepIds.manifesto);
      await ctrl(c).submit();
      expect(st(c).currentId, StepIds.name);
      await ctrl(c).submit('sam');
      expect(st(c).currentId, StepIds.experience);
      expect(st(c).answers[StepIds.name], 'sam');
    });

    test('info steps do not write answers', () async {
      final c = await make();
      await ctrl(c).submit();
      expect(st(c).answers.containsKey(StepIds.boot), isFalse);
    });

    test('doji replies to the previous answer (handoff copy)', () async {
      final c = await make(resumeAt(StepIds.name));
      await ctrl(c).submit('sam');
      expect(st(c).reply, 'sam. good to meet you.');
      await ctrl(c).submit('6_24m');
      expect(st(c).reply, '6–24 months. the stretch where habits get set.');
    });

    test('validation keeps the user on the step with doji\'s error line', () async {
      final c = await make(resumeAt(StepIds.name));
      final ok = await ctrl(c).submit('   ');
      expect(ok, isFalse);
      expect(st(c).currentId, StepIds.name);
      expect(st(c).error, contains('something to call you'));
      await ctrl(c).submit('sam');
      expect(st(c).error, isNull);
    });

    test('progress counts written lines against the lines expected', () async {
      final c = await make(resumeAt(StepIds.name));
      expect(st(c).progress, 0);
      await ctrl(c).submit('sam');
      expect(st(c).configLines, hasLength(1));
      // 14 lines without a prop goal (prop.size and prop.limits only apply to prop).
      expect(st(c).totalLines, 14);
      expect(st(c).progress, closeTo(1 / 14, 1e-9));
    });
  });

  group('back', () {
    test('goes to the previous visible step', () async {
      final c = await make(resumeAt(StepIds.experience));
      await ctrl(c).back();
      expect(st(c).currentId, StepIds.name);
    });

    test('is a no-op on the first step', () async {
      final c = await make();
      await ctrl(c).back();
      expect(st(c).currentId, StepIds.boot);
    });
  });

  group('skip', () {
    test('marks the step skipped, prints null in profile.doji, moves on', () async {
      final c = await make(resumeAt(StepIds.name));
      await ctrl(c).skip();
      expect(st(c).currentId, StepIds.experience);
      expect(st(c).skipped, contains(StepIds.name));
      final line = st(c).configLines.single;
      expect(line.keyName, 'name');
      expect(line.value, 'null');
      expect(line.comment, contains('skipped'));
      expect(st(c).reply, isNull, reason: 'no reply to a skipped answer');
    });

    test('answering later clears the skip', () async {
      final c = await make(resumeAt(StepIds.name));
      await ctrl(c).skip();
      await ctrl(c).editFromConfig(StepIds.name);
      await ctrl(c).submit('sam');
      expect(st(c).skipped, isNot(contains(StepIds.name)));
    });

    test('non-skippable steps ignore skip', () async {
      final c = await make(resumeAt(StepIds.rules));
      await ctrl(c).skip();
      expect(st(c).currentId, StepIds.rules);
    });
  });

  group('conditional steps', () {
    test('no strategy → the parsed review is hidden and risk follows', () async {
      final c = await make(resumeAt(StepIds.strategy));
      await ctrl(c).submitStrategy({'template': 'none', 'source': 'template'});
      expect(st(c).currentId, StepIds.risk);
      expect(st(c).visibleSteps.map((s) => s.id), isNot(contains(StepIds.strategyParsed)));
      expect(st(c).reply, contains('no strategy yet is fine'));
    });

    test('a described strategy is parsed and reviewed next', () async {
      final c = await make(resumeAt(StepIds.strategy));
      final raw = (handoffAnswers[StepIds.strategy]! as Map)['raw'];
      await ctrl(c).submitStrategy({'raw': raw, 'source': 'text'});
      expect(st(c).currentId, StepIds.strategyParsed);
      final parsed = st(c).answers[StepIds.strategyParsed]! as Map;
      expect(parsed['setup'], 'london breakout of the asian range');
      expect(parsed['timeframe'], 'M15');
      expect(st(c).reply, 'got it. check what i understood.');
    });

    test('a template fills the review with its structure', () async {
      final c = await make(resumeAt(StepIds.strategy));
      await ctrl(c).submitStrategy({'template': 'breakout', 'source': 'template'});
      expect(st(c).currentId, StepIds.strategyParsed);
      expect((st(c).answers[StepIds.strategyParsed]! as Map)['setup'], contains('breakout'));
    });

    test('prop.size and prop.limits only count when the goal is a prop challenge', () async {
      final c = await make(resumeAt(StepIds.goal));
      await ctrl(c).submit({'goal': 'learn'});
      expect(st(c).totalLines, 14);
      await ctrl(c).editFromConfig(StepIds.goal);
      await ctrl(c).submit({'goal': 'prop_challenge', 'propSize': 50000});
      expect(st(c).totalLines, 16);
      expect(st(c).configLines.map((l) => l.keyName), containsAll(['prop.size', 'prop.limits']));
    });
  });

  group('edit from profile.doji', () {
    test('jumps to the line\'s step, then returns to where the user was', () async {
      final c = await make(resumeAt(StepIds.struggles));
      await ctrl(c).editFromConfig(StepIds.name);
      expect(st(c).currentId, StepIds.name);
      expect(st(c).isEditing, isTrue);
      expect(st(c).reply, contains('editing'));
      await ctrl(c).submit('alex');
      expect(st(c).currentId, StepIds.struggles);
      expect(st(c).isEditing, isFalse);
      expect(st(c).answers[StepIds.name], 'alex');
    });

    test('back cancels the edit without changing the answer', () async {
      final c = await make(resumeAt(StepIds.struggles));
      await ctrl(c).editFromConfig(StepIds.style);
      await ctrl(c).back();
      expect(st(c).currentId, StepIds.struggles);
      expect(st(c).answers[StepIds.style], 'day_trader');
    });

    test('editing the description visits the parsed review before returning', () async {
      final c = await make(resumeAt(StepIds.coach));
      await ctrl(c).editFromConfig(StepIds.strategy);
      await ctrl(
        c,
      ).submitStrategy({'raw': 'pullback on H1, stop below the swing, target 3R', 'source': 'text'});
      expect(st(c).currentId, StepIds.strategyParsed);
      await ctrl(c).submit(st(c).answers[StepIds.strategyParsed]);
      expect(st(c).currentId, StepIds.coach);
    });

    test('every config line points at a visible step', () async {
      final c = await make(resumeAt(StepIds.compile));
      final visible = st(c).visibleSteps.map((s) => s.id).toSet();
      for (final line in st(c).configLines) {
        expect(visible, contains(line.targetId), reason: line.keyName);
      }
      expect(st(c).configLines, hasLength(st(c).totalLines));
    });
  });

  group('persistence', () {
    test('every answer is saved, and a relaunch resumes at the same step', () async {
      final c = await make(resumeAt(StepIds.name));
      await ctrl(c).submit('sam');
      await ctrl(c).submit('6_24m');

      // "Kill" the app: a brand-new container over the same storage.
      final relaunched = ProviderContainer(overrides: testOverrides(prefs));
      addTearDown(relaunched.dispose);
      final s = relaunched.read(onboardingControllerProvider);
      expect(s.currentId, StepIds.style);
      expect(s.answers[StepIds.name], 'sam');
      expect(s.answers[StepIds.experience], '6_24m');
    });

    test('an in-progress edit survives a relaunch', () async {
      final c = await make(resumeAt(StepIds.struggles));
      await ctrl(c).editFromConfig(StepIds.name);
      final relaunched = ProviderContainer(overrides: testOverrides(prefs));
      addTearDown(relaunched.dispose);
      expect(relaunched.read(onboardingControllerProvider).returnToId, StepIds.struggles);
    });

    test('time zone is detected once and stored with the answers', () async {
      final c = await make();
      st(c);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect((st(c).answers[StepIds.timeZone]! as Map)['id'], 'Africa/Johannesburg');
    });

    test('finishing locally stores the profile with pendingSync', () async {
      final c = await make(resumeAt(StepIds.save));
      final profile = await ctrl(c).finishLocally();
      expect(profile.pendingSync, isTrue);
      expect(profile.isComplete, isTrue);
      final repo = PrefsOnboardingRepository(prefs);
      expect(repo.loadProfile()?.name, 'sam');
      expect(repo.loadSnapshot(), isNull);
    });
  });
}
