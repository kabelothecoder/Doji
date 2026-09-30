// End to end: splash → full onboarding (mocks) → pledge → save your setup →
// continue without account → Home placeholder. Also kills and relaunches the
// app midway to prove answers survive and onboarding resumes.
//
//   flutter test integration_test -d windows
import 'package:doji_app/app/app.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Real-time frames. pumpAndSettle never settles here: cursors blink forever.
  Future<void> wait(WidgetTester tester, [int ms = 300]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> launch(WidgetTester tester, SharedPreferences prefs) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(), // a fresh scope = a fresh process
        overrides: testOverrides(prefs),
        child: const DojiApp(),
      ),
    );
    await wait(tester, 2000); // native splash → intro (1.5s) → first screen
  }

  /// Taps the widget showing [text] once doji has finished typing.
  Future<void> tapText(WidgetTester tester, String text, {int settle = 500}) async {
    final finder = find.text(text).hitTestable();
    final end = DateTime.now().add(const Duration(seconds: 6));
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets, reason: 'waiting for "$text"');
    await tester.tap(finder.first);
    await wait(tester, settle);
  }

  Future<void> skipTyping(WidgetTester tester) async {
    await tester.tapAt(const Offset(4, 400)); // any empty space finishes typing
    await wait(tester, 350);
  }

  testWidgets('splash → onboarding → pledge → save → home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await launch(tester, prefs);
    expect(find.textContaining("hey. i'm doji."), findsOneWidget);
    await tapText(tester, "let's go");
    await tapText(tester, "I'm in");

    // Identity
    await skipTyping(tester);
    await tester.enterText(find.byType(EditableText).first, 'sam');
    await tapText(tester, 'continue');
    await skipTyping(tester);
    await tapText(tester, '6–24 months', settle: 900); // auto-advance after 350ms
    await skipTyping(tester);
    await tapText(tester, 'day trader', settle: 900);
    await skipTyping(tester);
    await tapText(tester, 'XAUUSD');
    await tapText(tester, 'NAS100');
    await tapText(tester, 'continue');
    await skipTyping(tester);
    await tapText(tester, 'London');
    await tapText(tester, 'continue');

    // Goal, with the conditional prop details
    await skipTyping(tester);
    await tapText(tester, 'pass a prop challenge');
    await tapText(tester, '50k');
    await tapText(tester, 'continue');

    // Kill the app here and relaunch: onboarding resumes at the next question.
    expect(PrefsOnboardingRepository(prefs).loadSnapshot()?.currentStepId, 'struggles');
    await launch(tester, prefs);
    expect(find.textContaining('what usually gets you?'), findsOneWidget);
    expect(find.textContaining('prop_challenge'), findsWidgets, reason: 'profile.doji kept the answer');

    await skipTyping(tester);
    await tapText(tester, 'revenge trading');
    await tapText(tester, 'continue');

    // Strategy → AI parsing (mock) → structured review
    await skipTyping(tester);
    await tester.enterText(
      find.byType(EditableText).first,
      'i wait for the asian range, then trade the london breakout after a retest on M15. '
      'stop under the range, target 2R.',
    );
    await tapText(tester, 'read it', settle: 800);
    expect(find.text('london breakout of the asian range'), findsOneWidget);
    await tapText(tester, 'looks right');

    // Risk and rules
    await skipTyping(tester);
    await tapText(tester, '1%');
    await tapText(tester, 'continue');
    await skipTyping(tester);
    expect(find.text('your rules v1'), findsOneWidget);
    await tapText(tester, 'these are my rules');

    // Coach and ritual
    await skipTyping(tester);
    await tapText(tester, 'calm female');
    await tapText(tester, 'continue');
    await skipTyping(tester);
    await tapText(tester, 'not now');

    // Compile → profile card
    await wait(tester, 2500);
    expect(find.text('everyone starts here.'), findsOneWidget);
    await tapText(tester, 'continue');

    // Pledge: hold 1.5s; the first Grid square lights.
    final hold = find.text('hold');
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await wait(tester, 1800);
    await gesture.up();
    await wait(tester, 600);
    expect(find.text('pledged'), findsOneWidget);
    expect(find.text('GRID · DAY 1'), findsOneWidget);
    await tapText(tester, 'continue', settle: 800);

    // Save your setup → continue without account → Home
    expect(find.text('save your setup.'), findsOneWidget);
    await tapText(tester, 'continue without account', settle: 900);
    expect(find.textContaining('sam.'), findsOneWidget);
    expect(find.text('Impulsive'), findsOneWidget);

    final saved = PrefsOnboardingRepository(prefs).loadProfile()!;
    expect(saved.pendingSync, isTrue);
    expect(saved.pairs, ['XAUUSD', 'NAS100']);
    expect(saved.rules?.riskPerTrade, 1.0);
    expect(saved.pledgedAt, isNotNull);

    // A relaunch now goes straight Home.
    await launch(tester, prefs);
    expect(find.textContaining('sam.'), findsOneWidget);
  });
}
