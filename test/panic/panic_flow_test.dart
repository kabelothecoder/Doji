// Doji Panic Phone: breathe, ground, pause, talk, support, later.
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/core/widgets/widgets.dart';
import 'package:doji_app/features/panic/data/market_pause.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

void main() {
  test('4-7-8 phases', () {
    expect(breathAt(0).phase.word, 'breathe in');
    expect(breathAt(0).left, 4);
    expect(breathAt(4).phase.word, 'hold');
    expect(breathAt(10).left, 1);
    expect(breathAt(11).phase.word, 'breathe out');
    expect(breathAt(18).left, 1);
    expect(breathAt(19).phase.word, 'breathe in');
  });

  testWidgets('walks all six steps, pauses market views and schedules both reminders', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.panic);
    expect(find.text('breathe in'), findsOneWidget);

    await h.tapText("i'm a little calmer");
    expect(find.text("you're more than this account."), findsOneWidget);
    await h.tapText('name three things you can see.');
    await h.tapText('continue');

    expect(find.text("let's pause."), findsOneWidget);
    await h.tap(find.byType(Switch).first);
    expect(h.container.read(marketPauseProvider), isNotNull);
    await h.tapText('continue');

    expect(find.text('talk it through?'), findsOneWidget);
    await h.tapText('not right now');

    expect(find.text('call SADAG'), findsOneWidget);
    await h.tapText('continue');

    expect(find.textContaining("i'll check in tomorrow"), findsOneWidget);
    expect(h.reminders.scheduled.map((r) => r.body), [
      'your 24-hour pause is over. take it slow.',
      'how are you today? one line in your journal is enough.',
    ]);
    expect(find.text('next'), findsNothing);
  });
}
