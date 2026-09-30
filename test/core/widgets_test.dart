import 'package:doji_app/core/haptics/doji_haptics.dart';
import 'package:doji_app/core/theme/doji_theme.dart';
import 'package:doji_app/core/widgets/widgets.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:doji_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/sample_profile.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: dojiDarkTheme(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('TypingText', () {
    testWidgets('types over time and completes instantly on tap', (tester) async {
      var done = 0;
      const line = 'no holy grail found.';
      await tester.pumpWidget(_host(TypingText(line, onDone: () => done++)));
      await tester.pump(const Duration(milliseconds: 100)); // ~4 of 20 chars

      final state = tester.state<TypingTextState>(find.byType(TypingText));
      expect(state.isComplete, isFalse);

      await tester.tap(find.byType(TypingText));
      await tester.pump(); // tap
      await tester.pump(); // post-frame onDone
      expect(state.isComplete, isTrue);
      expect(done, 1);
    });

    testWidgets('a TypingScope skip finishes every line on screen', (tester) async {
      final skip = TypingSkipController();
      addTearDown(skip.dispose);
      await tester.pumpWidget(
        _host(
          TypingScope(
            controller: skip,
            child: const Column(children: [TypingText('first line'), TypingText('second', start: false)]),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      skip.skip();
      await tester.pump();
      for (final s in tester.stateList<TypingTextState>(find.byType(TypingText))) {
        expect(s.isComplete, isTrue);
      }
    });

    testWidgets('screen readers get the whole line at once, in a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const TypingText('how do you trade?')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        tester.getSemantics(find.bySemanticsLabel('how do you trade?')),
        matchesSemantics(label: 'how do you trade?', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('reduce motion renders the full line on the first frame', (tester) async {
      await tester.pumpWidget(_host(const TypingText('hey.'), reduceMotion: true));
      expect(tester.state<TypingTextState>(find.byType(TypingText)).isComplete, isTrue);
    });
  });

  group('HoldToPledgeButton', () {
    Future<(RecordingHaptics, List<int>)> pumpButton(WidgetTester tester) async {
      final haptics = RecordingHaptics();
      final pledged = <int>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [hapticsProvider.overrideWithValue(haptics)],
          child: _host(HoldToPledgeButton(onPledged: () => pledged.add(1))),
        ),
      );
      return (haptics, pledged);
    }

    testWidgets('releasing early does not pledge and rewinds the ring', (tester) async {
      final (haptics, pledged) = await pumpButton(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.text('hold')));
      await tester.pump(); // first ticker frame: elapsed 0
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.textContaining('HOLD 1.5S TO PLEDGE ·'), findsOneWidget, reason: 'shows progress');
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 600));
      expect(pledged, isEmpty);
      expect(find.text('hold'), findsOneWidget);
      expect(haptics.events, isNot(contains('heavy')));
    });

    testWidgets('a full 1.5s hold pledges with quarter ticks and a heavy thud', (tester) async {
      final (haptics, pledged) = await pumpButton(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.text('hold')));
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pump();
      expect(pledged, [1]);
      expect(find.text('pledged'), findsOneWidget);
      expect(haptics.events.where((e) => e == 'light'), hasLength(3)); // 25, 50, 75%
      expect(haptics.events.last, 'heavy');
    });

    testWidgets('keyboard: holding Space for 1.5s pledges', (tester) async {
      final (_, pledged) = await pumpButton(tester);
      await tester.tap(find.text('hold')); // quick tap: focuses, too short to pledge
      await tester.pump(const Duration(milliseconds: 600));
      expect(pledged, isEmpty);
      Focus.of(tester.element(find.text('hold'))).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(pledged, [1]);
    });

    testWidgets('screen readers can pledge with the long-press action', (tester) async {
      final handle = tester.ensureSemantics();
      final (_, pledged) = await pumpButton(tester);
      final node = tester.getSemantics(find.byType(HoldToPledgeButton));
      expect(node.label, contains("i'll trade my plan, not my feelings"));
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp('not my feelings')),
        SemanticsAction.longPress,
      );
      await tester.pump();
      expect(pledged, [1]);
      handle.dispose();
    });
  });

  group('ConfigPanel', () {
    const lines = [
      ConfigLineData(
        number: 1,
        keyName: 'name',
        value: '"sam"',
        tone: ConfigValueTone.literal,
        targetId: 'name',
      ),
      ConfigLineData(
        number: 2,
        keyName: 'experience',
        value: '6-24m',
        tone: ConfigValueTone.symbol,
        targetId: 'experience',
      ),
      ConfigLineData(
        number: 3,
        keyName: 'style',
        value: 'day_trader',
        tone: ConfigValueTone.symbol,
        targetId: 'style',
        highlighted: true,
      ),
    ];

    testWidgets('tapping a line asks to edit that line\'s step', (tester) async {
      final edited = <String>[];
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: ConfigPanel(lines: lines, totalLines: 15, onEditLine: (l) => edited.add(l.targetId)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('3 / 15 lines'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('edit name: "sam"'));
      expect(edited, ['name']);
    });

    testWidgets('collapses from its header', (tester) async {
      var collapsed = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            SizedBox(
              width: 360,
              child: ConfigPanel(
                lines: lines,
                totalLines: 15,
                collapsed: collapsed,
                onToggleCollapsed: () => setState(() => collapsed = !collapsed),
                onEditLine: (_) {},
              ),
            ),
          ),
        ),
      );
      final expandedHeight = tester.getSize(find.byType(ConfigPanel)).height;
      await tester.tap(find.text('profile.doji'));
      await tester.pump(); // AnimatedSize picks up the new size
      await tester.pump(const Duration(milliseconds: 400));
      expect(collapsed, isTrue);
      expect(tester.getSize(find.byType(ConfigPanel)).height, lessThan(expandedHeight));
    });

    testWidgets('on the onboarding screen, tap → edit that step → return', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(resumeAt(StepIds.struggles, lastAnswered: StepIds.goal));
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: testOverrides(prefs));
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: dojiDarkTheme(),
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true, size: Size(390, 844)),
              child: OnboardingScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Expand the card so the first lines are reachable, then scroll to name.
      await tester.tap(find.bySemanticsLabel(RegExp('edit goal')));
      await tester.pump();
      await tester.pump();
      expect(container.read(onboardingControllerProvider).currentId, StepIds.goal);
      expect(container.read(onboardingControllerProvider).returnToId, StepIds.struggles);

      await tester.tap(find.text('save'));
      await tester.pump();
      await tester.pump();
      expect(container.read(onboardingControllerProvider).currentId, StepIds.struggles);
    });
  });
}
