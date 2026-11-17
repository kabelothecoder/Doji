// Handoff 1c (Doji Hero Screens): the coach as a full-screen cover. The orb
// opens it, the fake coach answers from the trader's own plan, voice is
// push-to-talk on pro and elite, text everywhere else, and an unsaved
// session asks before it closes.
import 'dart:convert';

import 'package:doji_app/app/routes.dart';
import 'package:doji_app/core/widgets/widgets.dart';
import 'package:doji_app/features/auth/presentation/auth_controller.dart';
import 'package:doji_app/features/coach/data/coach_session_repository.dart';
import 'package:doji_app/features/coach/presentation/widgets/push_to_talk_button.dart';
import 'package:doji_app/features/home/domain/home_models.dart';
import 'package:doji_app/features/home/presentation/home_controller.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/data/voice_input.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/plans/data/billing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/sample_profile.dart';
import '../helpers/fakes.dart';

const _urge = 'the break is right there. I want in before it runs.';

/// Sam, with a parsed strategy and rules. [plan]: free (text) unless set.
Map<String, Object> _seed({String? plan, String? voice}) => {
  ...seedProfile(
    profile: profileWith(
      name: 'sam',
      instruments: const ['XAUUSD'],
      strategy: const StrategyProfile(
        parsed: ParsedStrategy(setup: 'london breakout of the asian range', entry: 'the M15 close'),
      ),
      rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
      coach: CoachProfile(voice: voice),
      pledgedAt: DateTime.utc(2026, 10, 1),
      completedAt: DateTime.utc(2026, 10, 1),
    ),
  ),
  FakeBillingRepository.planKey: ?plan,
};

List<Object?> _saved(AppHarness h) {
  final raw = h.prefs.getString(PrefsCoachSessionRepository.key);
  return raw == null ? const [] : (jsonDecode(raw) as Map)['sessions'] as List;
}

Future<void> _type(AppHarness h, String text) async {
  await h.tester.enterText(find.byType(TextField), text);
  await h.wait(50);
  await h.tap(find.bySemanticsLabel('send'));
}

final _ptt = find.byType(PushToTalkButton);

void main() {
  testWidgets('the orb opens the coach over Home with a question; close returns to Home', (tester) async {
    // A phone that can dictate, on the free plan.
    final h = await AppHarness.pump(tester, at: Routes.home, seed: _seed(), voice: FakeVoiceInput());
    await h.tap(find.bySemanticsLabel('coach'));
    expect(h.location, Routes.coach);
    expect(find.textContaining("sam, what's on your mind before the next trade?"), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
    expect(find.textContaining('COACH SESSION · 00:0'), findsOneWidget);
    expect(find.text('coaching, not therapy. need someone now? SADAG 0800 567 567'), findsOneWidget);
    // Free plan: text coaching, and it says why.
    expect(find.text('voice coaching comes with pro trader. text coaching is on.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(_ptt, findsNothing);

    // Nothing said yet: close needs no question.
    await h.tap(find.bySemanticsLabel('close coach'));
    expect(h.location, Routes.home);
  }, variant: ios);

  testWidgets(
    "text: the reply comes from the trader's own entry rule; save keeps it and ticks the checklist",
    (tester) async {
      final h = await AppHarness.pump(tester, at: Routes.coach, seed: _seed());
      await _type(h, _urge);
      expect(find.text(_urge), findsOneWidget);
      expect(
        find.textContaining("the move isn't your rule. your plan waits for the M15 close."),
        findsOneWidget,
      );
      expect(h.container.read(homeControllerProvider).doneTasks, contains(SetupTask.coach));

      await h.tap(find.bySemanticsLabel('save session'));
      expect(find.text('saved'), findsOneWidget);
      expect(h.haptics.events, contains('light'));
      final saved = _saved(h);
      expect(saved, hasLength(1));
      final turns = (saved.single as Map)['turns'] as List;
      expect(turns.map((t) => (t as Map)['speaker']), ['coach', 'you', 'coach']);
      expect((turns[1] as Map)['text'], _urge);

      // Saved: closing asks nothing.
      await h.tap(find.bySemanticsLabel('close coach'));
      expect(find.text('save this session?'), findsNothing);
      expect(h.location, Routes.home);
    },
    variant: ios,
  );

  testWidgets("unsaved words: close asks; don't save keeps nothing", (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.coach, seed: _seed());
    await _type(h, 'what a morning');
    await h.tap(find.bySemanticsLabel('close coach'));
    expect(find.text('save this session?'), findsOneWidget);
    await h.tapText("don't save");
    expect(h.location, Routes.home);
    expect(_saved(h), isEmpty);
  }, variant: ios);

  testWidgets('unsaved words: end asks; save keeps the session', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.coach, seed: _seed());
    await _type(h, 'just one more trade');
    expect(find.textContaining('that would be trade 1 of 3 today.'), findsOneWidget);
    await h.tap(find.bySemanticsLabel('end session'));
    await h.tap(find.widgetWithText(DojiButton, 'save'));
    expect(h.location, Routes.home);
    expect(_saved(h), hasLength(1));
  }, variant: ios);

  testWidgets('the system back gesture asks too, and dismissing the sheet stays in the session', (
    tester,
  ) async {
    final h = await AppHarness.pump(tester, at: Routes.home, seed: _seed());
    await h.tap(find.bySemanticsLabel('coach'));
    await _type(h, 'what a morning');
    await tester.binding.handlePopRoute();
    await h.wait();
    expect(find.text('save this session?'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20)); // the barrier
    await h.wait();
    expect(find.text('save this session?'), findsNothing);
    expect(h.location, Routes.coach);
  }, variant: ios);

  testWidgets('crisis words get the helpline before anything about trading', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.coach, seed: _seed());
    await _type(h, "honestly I don't want to be here anymore");
    expect(find.textContaining('please talk to someone now: SADAG on 0800 567 567'), findsOneWidget);
  }, variant: ios);

  group('voice (pro trader)', () {
    testWidgets('hold to talk: the words show as heard, release sends; a tick on press and release', (
      tester,
    ) async {
      final voice = FakeVoiceInput();
      final h = await AppHarness.pump(
        tester,
        at: Routes.coach,
        seed: _seed(plan: 'pro'),
        voice: voice,
      );
      expect(find.text('hold to talk'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('voice coaching comes with pro trader. text coaching is on.'), findsNothing);

      final gesture = await tester.startGesture(tester.getCenter(_ptt));
      await h.wait(100);
      expect(voice.prepares, 1);
      expect(voice.starts, 1);
      expect(find.text('release to send'), findsOneWidget);
      expect(find.text('LISTENING…'), findsOneWidget);
      expect(find.bySemanticsLabel('voice orb, listening'), findsOneWidget);
      voice.say('I want to double my lot');
      await h.wait(400);
      expect(find.textContaining('I want to double my lot'), findsOneWidget);

      await gesture.up();
      await h.wait(300);
      expect(voice.stops, 1);
      expect(find.textContaining('your risk is 1% a trade.'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
      expect(h.haptics.events.where((e) => e == 'tick'), hasLength(2));
    }, variant: ios);

    testWidgets('tap to talk: a tap opens the mic, the next tap sends; a pause sends too', (tester) async {
      final voice = FakeVoiceInput();
      final h = await AppHarness.pump(
        tester,
        at: Routes.coach,
        seed: _seed(plan: 'pro'),
        voice: voice,
      );
      await h.tap(_ptt);
      expect(find.text('tap to send'), findsOneWidget);
      voice.say('just one more trade');
      await h.wait(50);
      await h.tap(_ptt);
      expect(find.textContaining('that would be trade 1 of 3 today.'), findsOneWidget);

      await h.tap(_ptt);
      voice.say("I'm frustrated");
      voice.silence();
      await h.wait();
      expect(find.textContaining('noticing it is the skill.'), findsOneWidget);
      expect(voice.prepares, 1, reason: 'the permission prompt is asked once a session');
    }, variant: ios);

    testWidgets('releasing before any words: nothing is sent, and it says so', (tester) async {
      final voice = FakeVoiceInput();
      final h = await AppHarness.pump(
        tester,
        at: Routes.coach,
        seed: _seed(plan: 'pro'),
        voice: voice,
      );
      final gesture = await tester.startGesture(tester.getCenter(_ptt));
      await h.wait(500);
      await gesture.up();
      await h.wait();
      expect(find.text("didn't catch that. hold the button and speak."), findsOneWidget);
      expect(find.text('save'), findsOneWidget);
      expect(tester.widget<DojiPressable>(find.widgetWithText(DojiPressable, 'save')).onPressed, isNull);
    }, variant: ios);

    testWidgets('a long-press on the orb opens the coach already listening', (tester) async {
      final voice = FakeVoiceInput();
      final h = await AppHarness.pump(
        tester,
        at: Routes.home,
        seed: _seed(plan: 'elite'),
        voice: voice,
      );
      await tester.longPress(find.bySemanticsLabel('coach'));
      await h.wait();
      expect(h.location, Routes.coach);
      expect(voice.starts, 1);
      expect(find.text('tap to send'), findsOneWidget);
      expect(find.textContaining("what's on your mind"), findsNothing, reason: 'no opener over the mic');
    }, variant: ios);

    testWidgets('the microphone refused: the session turns to text and says why', (tester) async {
      final voice = FakeVoiceInput(availability: VoiceAvailability.permissionDenied);
      final h = await AppHarness.pump(
        tester,
        at: Routes.coach,
        seed: _seed(plan: 'pro'),
        voice: voice,
      );
      await h.tap(_ptt);
      expect(
        find.text('the microphone is off for doji. type here, or turn it on in settings.'),
        findsOneWidget,
      );
      expect(_ptt, findsNothing);
      await _type(h, _urge);
      expect(find.textContaining('your plan waits for the M15 close.'), findsOneWidget);
    }, variant: ios);
  });

  testWidgets('the voice picker shows the stored voice and saves a new one to profile.doji', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.coach,
      seed: _seed(voice: 'calm_male'),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('calm male voice')),
      containsSemantics(isSelected: true),
    );
    await h.tap(find.bySemanticsLabel('calm female voice'));
    expect(h.container.read(onboardingRepositoryProvider).loadProfile()?.coach?.voice, 'calm_female');
    expect(
      tester.getSemantics(find.bySemanticsLabel('calm female voice')),
      containsSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('calm male voice')),
      containsSemantics(isSelected: false),
    );
  }, variant: ios);

  testWidgets(
    'windows: text with the reason, Enter sends, Esc asks then closes',
    (tester) async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.home,
        seed: _seed(plan: 'pro'),
        size: const Size(1440, 900),
      );
      await h.tap(find.bySemanticsLabel('coach'));
      expect(h.location, Routes.coach);
      expect(find.text("voice isn't on this computer yet. type to your coach."), findsOneWidget);
      await tester.enterText(find.byType(TextField), _urge);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await h.wait();
      expect(find.textContaining('your plan waits for the M15 close.'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await h.wait();
      expect(find.text('save this session?'), findsOneWidget);
      await h.tap(find.widgetWithText(DojiButton, 'save'));
      expect(h.location, Routes.home);
      expect(_saved(h), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('sign out erases saved coach sessions with the rest of this device', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.coach, seed: {..._seed(), ...seedSession()});
    await _type(h, 'what a morning');
    await h.tap(find.bySemanticsLabel('save session'));
    expect(_saved(h), hasLength(1));

    final out = h.container.read(accountActionsProvider).signOut();
    await h.wait();
    await out;
    expect(h.prefs.getString(PrefsCoachSessionRepository.key), isNull);
  }, variant: ios);
}
