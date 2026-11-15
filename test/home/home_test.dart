// Home, the open, close your day, the rail and the tab shell.
import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/app/shell/doji_bottom_bar.dart';
import 'package:doji_app/app/shell/doji_nav_rail.dart';
import 'package:doji_app/core/widgets/widgets.dart';
import 'package:doji_app/features/home/domain/home_models.dart';
import 'package:doji_app/features/markets/presentation/pair_detail_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/sample_profile.dart';
import '../journal/journal_fixtures.dart';

/// A fixed morning, so "evening" never depends on when the suite runs.
final _morning = Clock.fixed(DateTime(2026, 10, 8, 10));
final _evening = Clock.fixed(DateTime(2026, 10, 8, 19));

Map<String, Object> _dayZeroSeed() => seedProfile(
  profile: profileWith(
    name: 'sam',
    instruments: const ['XAUUSD', 'NAS100'],
    pledgedAt: DateTime(2026, 10, 8, 9),
    completedAt: DateTime(2026, 10, 8, 9),
  ),
);

/// `ensureVisible` scrolls a tapped item to the top; scroll back up to read the cards above it.
Future<void> _toTop(WidgetTester tester, AppHarness h) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
  await h.wait();
}

void main() {
  testWidgets('normal day: score, the open, brief, rules and the five tabs', (tester) async {
    await withClock(_morning, () async {
      await AppHarness.pump(tester, at: Routes.home, seed: seedProfile());
      expect(find.text('hey, sam'), findsOneWidget);
      expect(find.text('DOJI SCORE'), findsOneWidget);
      expect(find.text('sample data'), findsOneWidget);
      expect(find.text('the open'), findsOneWidget);
      expect(find.text('finish setup'), findsNothing, reason: 'not day zero');
      expect(find.byType(DojiBottomBar), findsOneWidget);
      expect(find.byType(DojiNavRail), findsNothing);
      for (final tab in ['home', 'markets', 'coach', 'journal', 'me']) {
        expect(find.bySemanticsLabel(tab), findsOneWidget, reason: tab);
      }
    });
  }, variant: ios);

  testWidgets('day zero: the checklist ticks, counts and hides when all three are done', (tester) async {
    await withClock(_morning, () async {
      final h = await AppHarness.pump(tester, at: Routes.home, seed: _dayZeroSeed());
      expect(find.text('finish setup'), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
      expect(find.text('DOJI SCORE'), findsNothing);

      await h.tapText(SetupTask.brief.title);
      expect(find.text('1/3'), findsOneWidget);
      expect(h.haptics.events, contains('light'));

      await h.tapText(SetupTask.coach.title);
      await h.tapText(SetupTask.connect.title);
      expect(find.text('finish setup'), findsNothing);
    });
  }, variant: ios);

  testWidgets('the open: mood → hold to pledge → today’s line → done, then Home says done', (tester) async {
    await withClock(_morning, () async {
      final h = await AppHarness.pump(tester, at: Routes.home, seed: seedProfile());
      await h.tapText('the open');
      expect(h.location, Routes.open);
      expect(find.text('how are you walking in?'), findsOneWidget);
      expect(tester.widget<DojiButton>(find.widgetWithText(DojiButton, 'continue')).onPressed, isNull);

      await h.tapText('calm');
      await h.tapText('continue');
      expect(find.text('read it once.'), findsOneWidget);
      await h.tapText("i've read it");
      expect(find.text('your rules for today.'), findsOneWidget);

      final hold = await tester.startGesture(tester.getCenter(find.byType(HoldToPledgeButton)));
      await h.wait(1700);
      await hold.up();
      await h.wait(600);
      expect(find.text('one line for today.'), findsOneWidget);
      expect(find.textContaining('not financial advice'), findsOneWidget);

      await h.tapText("i'm ready");
      expect(find.textContaining('the open: complete.'), findsOneWidget);
      await h.tapText('go home');
      expect(h.location, Routes.home);
      expect(find.text('done'), findsOneWidget);
      expect(find.textContaining('calm'), findsWidgets);
    });
  }, variant: ios);

  testWidgets('closing the open early goes back without completing it', (tester) async {
    await withClock(_morning, () async {
      final h = await AppHarness.pump(tester, at: Routes.home, seed: seedProfile());
      await h.tapText('the open');
      await h.tap(find.bySemanticsLabel('close'));
      expect(h.location, Routes.home);
      expect(find.text('done'), findsNothing);
    });
  }, variant: ios);

  testWidgets('close your day: from the evening card, then Home shows day closed', (tester) async {
    await withClock(_evening, () async {
      final h = await AppHarness.pump(tester, at: Routes.home, seed: seedProfile());
      expect(find.text('evening, sam'), findsOneWidget);
      expect(find.text('close your day.'), findsOneWidget);

      await h.tapText('close your day');
      expect(h.location, Routes.closeDay);
      expect(find.text('how did today go?'), findsOneWidget);
      await h.tapText('close the day');
      await h.wait(600);

      expect(h.location, Routes.home);
      await _toTop(tester, h);
      expect(find.textContaining('day closed.'), findsOneWidget);
      expect(find.text('close your day.'), findsNothing);
      expect(h.haptics.events, contains('light'));
    });
  }, variant: ios);

  testWidgets('no trades today: no tilt banner', (tester) async {
    await withClock(_morning, () async {
      await AppHarness.pump(tester, at: Routes.home, seed: seedProfile());
      expect(find.textContaining('losses today'), findsNothing);
    });
  }, variant: ios);

  testWidgets('tilt: two losses in the journal show the banner; talk to coach opens the coach', (
    tester,
  ) async {
    await withClock(_morning, () async {
      final seed = {
        ...seedProfile(),
        ...seedJournal([
          sampleTrade(id: 'a', pnl: -50, minutesAgo: 200),
          sampleTrade(id: 'b', pnl: -50, minutesAgo: 100),
        ]),
      };
      final h = await AppHarness.pump(tester, at: Routes.home, seed: seed);
      await _toTop(tester, h);
      expect(find.text('2 losses today. one more and cooldown starts.'), findsOneWidget);

      await h.tapText('talk to coach');
      expect(h.location, Routes.coach);
    });
  }, variant: ios);

  testWidgets('a win after the losses ends the tilt', (tester) async {
    await withClock(_morning, () async {
      final seed = {
        ...seedProfile(),
        ...seedJournal([
          sampleTrade(id: 'a', pnl: -50, minutesAgo: 300),
          sampleTrade(id: 'b', pnl: -50, minutesAgo: 200),
          sampleTrade(id: 'c', pnl: 80, minutesAgo: 100),
        ]),
      };
      await AppHarness.pump(tester, at: Routes.home, seed: seed);
      expect(find.textContaining('losses today'), findsNothing);
    });
  }, variant: ios);

  testWidgets('tabs switch in place; me reaches account settings', (tester) async {
    await withClock(_morning, () async {
      final h = await AppHarness.pump(tester, at: Routes.home, seed: seedProfile());
      await h.tap(find.bySemanticsLabel('markets'));
      expect(h.location, Routes.markets);
      expect(find.text('MEASURED AGAINST'), findsOneWidget);

      await h.tap(find.bySemanticsLabel('me'));
      await h.tapText('account and settings');
      expect(h.location, Routes.settings);
    });
  }, variant: ios);

  testWidgets('log a trade opens the manual add in the journal', (tester) async {
    await withClock(_morning, () async {
      final h = await AppHarness.pump(tester, at: Routes.home, seed: seedProfile());
      await tester.scrollUntilVisible(find.text('log a trade'), 300);
      await h.tapText('log a trade');
      expect(h.location, Routes.addTrade);
      expect(find.text('add a trade'), findsOneWidget);
    });
  }, variant: ios);

  testWidgets("the rules card counts today's trades from the journal", (tester) async {
    await withClock(_morning, () async {
      final seed = {
        ...seedProfile(),
        ...seedJournal([
          sampleTrade(id: 'a', pnl: 50, minutesAgo: 100),
          sampleTrade(id: 'b', pnl: -50, minutesAgo: 50),
        ]),
      };
      await AppHarness.pump(tester, at: Routes.home, seed: seed);
      await tester.scrollUntilVisible(find.text('RULES TODAY'), 300);
      expect(find.bySemanticsLabel(RegExp(r'^trades, 2 / ')), findsOneWidget);
    });
  }, variant: ios);

  testWidgets(
    'Windows is always wide: side rail, docked doji rail, no bottom bar',
    (tester) async {
      await withClock(_morning, () async {
        final h = await AppHarness.pump(
          tester,
          at: Routes.home,
          seed: seedProfile(),
          size: const Size(1280, 800),
        );
        expect(find.byType(DojiNavRail), findsOneWidget);
        expect(find.byType(DojiBottomBar), findsNothing);
        expect(find.byType(DojiRailPanel), findsOneWidget);
        expect(find.text('log emotion'), findsOneWidget);
        // The rail reads the same brief as Markets 1b (no strategy: "your rules").
        final brief = await h.container.read(pairBriefProvider('XAUUSD').future);
        final all = brief.metCount == brief.conditions.length;
        expect(find.text('conditions met'), all ? findsOneWidget : findsNothing);
        expect(
          find.textContaining('your rules · ${brief.metCount}/${brief.conditions.length}'),
          findsOneWidget,
        );

        await h.tapText('log emotion');
        expect(find.text('how did that trade feel?'), findsOneWidget);
        await h.tapText('save');
        expect(find.textContaining('logged: after the trade · 6/10'), findsOneWidget);
      });
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    "the side rail's items reach screen readers (the branch page doesn't hide them)",
    (tester) async {
      await withClock(_morning, () async {
        await AppHarness.pump(tester, at: Routes.home, seed: seedProfile(), size: const Size(1280, 800));
        for (final tab in ['home', 'markets', 'coach', 'journal', 'me']) {
          expect(find.bySemanticsLabel(tab), findsOneWidget, reason: tab);
        }
      });
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('Windows stays wide even in a narrow window', (tester) async {
    await withClock(_morning, () async {
      await AppHarness.pump(tester, at: Routes.home, seed: seedProfile(), size: const Size(700, 800));
      expect(find.byType(DojiNavRail), findsOneWidget);
      expect(find.byType(DojiBottomBar), findsNothing);
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('other platforms go wide from 900 logical pixels', (tester) async {
    await withClock(_morning, () async {
      await AppHarness.pump(tester, at: Routes.home, seed: seedProfile(), size: const Size(1024, 768));
      expect(find.byType(DojiNavRail), findsOneWidget);
      expect(find.byType(DojiBottomBar), findsNothing);
    });
  }, variant: ios);

  testWidgets(
    'the rail collapses to mini and closes; show rail brings it back',
    (tester) async {
      await withClock(_morning, () async {
        final h = await AppHarness.pump(
          tester,
          at: Routes.home,
          seed: seedProfile(),
          size: const Size(1280, 800),
        );
        await h.tap(find.bySemanticsLabel('collapse'));
        expect(find.text('log emotion'), findsNothing);
        expect(find.text('log ↵'), findsOneWidget);

        await h.tap(find.bySemanticsLabel('close rail'));
        expect(find.byType(DojiRailPanel), findsNothing);
        await h.tapText('show rail');
        expect(find.byType(DojiRailPanel), findsOneWidget);
      });
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('RuleMeter turns orange from 60% of the limit and says so', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Column(
            children: [
              RuleMeter(label: 'trades', used: 1, limit: 3),
              RuleMeter(label: 'daily loss', used: 1.4, limit: 2, unit: '%'),
            ],
          ),
        ),
      ),
    );
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('trades, 1 / 3'), findsOneWidget);
    expect(find.bySemanticsLabel('daily loss, 1.4% / 2%, near the limit'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('accessibility: labelled 44pt targets, no clipping at 200% text', (tester) async {
    final handle = tester.ensureSemantics();
    await withClock(_morning, () async {
      await AppHarness.pump(tester, at: Routes.home, seed: seedProfile(), textScale: 2);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
    handle.dispose();
  }, variant: ios);

  testWidgets('day zero at 200% text scales without overflow', (tester) async {
    await withClock(_morning, () async {
      await AppHarness.pump(tester, at: Routes.home, seed: _dayZeroSeed(), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }, variant: ios);
}
