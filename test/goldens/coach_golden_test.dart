// Goldens for the coach session (design/handoff/Doji Hero Screens.dc.html,
// 1c) on iPhone 390 × 844, plus the text session on Windows 1440 × 900.
//
//   flutter test test/goldens --update-goldens   # after an intended change
//
// Reduce motion is on, so typing is complete, cursors are solid and the orb
// is still (no rings). The clock is pinned so the session reads 00:00.
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/coach/presentation/widgets/push_to_talk_button.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/plans/data/billing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../helpers/fakes.dart';

const _urge = 'the break is right there. I want in before it runs.';

Future<void> _match(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('coach_$name.png'));

Map<String, Object> _seed({String? plan}) => {
  ...seedProfile(
    profile: ProfileDoji(
      name: 'sam',
      instruments: const ['XAUUSD'],
      strategy: const StrategyProfile(
        parsed: ParsedStrategy(setup: 'london breakout of the asian range', entry: 'the M15 close'),
      ),
      rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
      pledgedAt: DateTime.utc(2026, 7, 1),
      completedAt: DateTime.utc(2026, 7, 1),
    ),
  ),
  FakeBillingRepository.planKey: ?plan,
};

void main() {
  testWidgets('1c coach · after a reply', (tester) async {
    await withClock(summerDay, () async {
      final mic = FakeVoiceInput();
      final h = await AppHarness.pump(
        tester,
        at: Routes.coach,
        seed: _seed(plan: 'pro'),
        voice: mic,
      );
      await h.tap(find.byType(PushToTalkButton));
      mic.say(_urge);
      await h.wait(50);
      await h.tap(find.byType(PushToTalkButton));
      await _match('1c_phone');
    });
  }, variant: ios);

  testWidgets('1c coach · listening', (tester) async {
    await withClock(summerDay, () async {
      final mic = FakeVoiceInput();
      final h = await AppHarness.pump(
        tester,
        at: Routes.coach,
        seed: _seed(plan: 'pro'),
        voice: mic,
      );
      await h.tap(find.byType(PushToTalkButton));
      mic.say('the break is right there');
      await h.wait(50);
      await _match('listening_phone');
    });
  }, variant: ios);

  testWidgets('coach · text on windows', (tester) async {
    await withClock(summerDay, () async {
      final h = await AppHarness.pump(tester, at: Routes.coach, seed: _seed(), size: const Size(1440, 900));
      await tester.enterText(find.byType(TextField), _urge);
      await h.wait(50);
      await h.tap(find.bySemanticsLabel('send'));
      FocusManager.instance.primaryFocus?.unfocus();
      await h.wait(50);
      await _match('windows');
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
