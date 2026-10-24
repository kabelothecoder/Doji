// The accessibility floor (CLAUDE.md) on the coach session: ≥ 44pt targets
// (48dp Android), labelled targets, ≥ 4.5:1 contrast, 200% text that
// scrolls instead of clipping, and reduce motion keeping the orb still.
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/coach/presentation/widgets/push_to_talk_button.dart';
import 'package:doji_app/features/plans/data/billing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';

Map<String, Object> _seed({String? plan}) => {...seedProfile(), FakeBillingRepository.planKey: ?plan};

/// One exchange, so save is live and both transcript lines show.
Future<void> _exchange(AppHarness h, {required bool voice, FakeVoiceInput? mic}) async {
  if (voice) {
    await h.tap(find.byType(PushToTalkButton));
    mic!.say('the break is right there. I want in before it runs.');
    await h.wait(50);
    await h.tap(find.byType(PushToTalkButton));
  } else {
    await h.tester.enterText(find.byType(TextField), 'the break is right there. I want in before it runs.');
    await h.wait(50);
    await h.tap(find.bySemanticsLabel('send'));
  }
}

Future<void> _floor(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  testWidgets('text (free plan): tap targets, labels and contrast', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await AppHarness.pump(tester, at: Routes.coach, seed: _seed(), voice: FakeVoiceInput());
    expect(find.text('see pro trader'), findsOneWidget);
    await _floor(tester);
    await _exchange(h, voice: false);
    await _floor(tester);
    handle.dispose();
  }, variant: ios);

  testWidgets('voice (pro): tap targets, labels and contrast, listening and after a reply', (tester) async {
    final handle = tester.ensureSemantics();
    final mic = FakeVoiceInput();
    final h = await AppHarness.pump(
      tester,
      at: Routes.coach,
      seed: _seed(plan: 'pro'),
      voice: mic,
    );
    await _floor(tester);
    await h.tap(find.byType(PushToTalkButton));
    expect(find.bySemanticsLabel('tap to send'), findsOneWidget);
    await _floor(tester);
    mic.say('one more trade');
    await h.wait(50);
    await h.tap(find.byType(PushToTalkButton));
    await _floor(tester);
    handle.dispose();
  }, variant: ios);

  testWidgets('android: 48dp targets', (tester) async {
    final handle = tester.ensureSemantics();
    await AppHarness.pump(
      tester,
      at: Routes.coach,
      seed: _seed(plan: 'pro'),
      voice: FakeVoiceInput(),
      size: const Size(412, 915),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final voice in [false, true]) {
    testWidgets('${voice ? 'voice' : 'text'}: 200% text scrolls instead of overflowing', (tester) async {
      final mic = FakeVoiceInput();
      final h = await AppHarness.pump(
        tester,
        at: Routes.coach,
        seed: _seed(plan: voice ? 'pro' : null),
        voice: mic,
        textScale: 2,
        size: const Size(375, 667),
      );
      expect(tester.takeException(), isNull);
      await _exchange(h, voice: voice, mic: mic);
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('what does your entry rule need to see first?', skipOffstage: false),
        findsOneWidget,
      );
    }, variant: ios);
  }

  // The orb and the live line's cursor are the only motion while listening.
  for (final reduced in [true, false]) {
    testWidgets(reduced ? 'reduce motion: listening is still' : 'with motion: listening breathes', (
      tester,
    ) async {
      final h = await AppHarness.pump(
        tester,
        at: Routes.coach,
        seed: _seed(plan: 'pro'),
        voice: FakeVoiceInput(),
        reduced: reduced,
      );
      await h.wait(3000); // the opener finishes typing
      await h.tap(find.byType(PushToTalkButton));
      expect(find.text('LISTENING…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount > 0, !reduced);
    }, variant: ios);
  }
}
