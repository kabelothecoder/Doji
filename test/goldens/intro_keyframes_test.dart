// The splash intro at the handoff's keyframes (K1–K5), plus its haptics.
// Compare with design/handoff/Doji Onboarding.dc.html › Splash.
@Tags(['golden'])
library;

import 'package:doji_app/core/haptics/doji_haptics.dart';
import 'package:doji_app/core/theme/doji_theme.dart';
import 'package:doji_app/core/widgets/widgets.dart';
import 'package:doji_app/features/splash/domain/launch_destination.dart';
import 'package:doji_app/features/splash/presentation/intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('intro keyframes K1–K5 and haptic points', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final haptics = RecordingHaptics();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const IntroScreen()),
        GoRoute(
          path: '/onboarding',
          pageBuilder: (_, s) => CustomTransitionPage<void>(
            key: s.pageKey,
            transitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
            child: const Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Align(alignment: Alignment.topLeft, child: _Header()),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          launchRouteProvider.overrideWithValue('/onboarding'),
          hapticsProvider.overrideWithValue(haptics),
        ],
        child: MaterialApp.router(
          theme: dojiDarkTheme(),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    // The intro starts on the frame after the first (post-frame callback),
    // and a ticker's first frame has zero elapsed time.
    await tester.pump();
    await tester.pump();
    var t = 0;
    Future<void> at(int ms, String name) async {
      while (t < ms) {
        final step = (ms - t).clamp(0, 16);
        await tester.pump(Duration(milliseconds: step));
        t += step;
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('intro_$name.png'));
    }

    await at(240, 'k1_candle_rises'); // green body up, wick extended
    await at(400, 'k2_wiggle_down'); // tilt-orange, low
    await at(790, 'k3_perfect_doji'); // 5px white bar
    expect(haptics.events, ['light'], reason: 'light impact on settle');
    await at(1000, 'k4_cursor_blink'); // candle is the i, cursor blinking
    await at(1245, 'k4_typed'); // d-o-j typed
    expect(haptics.events, ['light', 'tick', 'tick', 'tick'], reason: 'selection tick per char');
    await at(1250 + 120, 'k5_glide'); // Hero mid-flight to the header
    await at(1250 + 400, 'k5_landed');
  });
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 44,
    child: Align(
      alignment: Alignment.centerLeft,
      child: WordmarkHero(child: DojiWordmark(size: 18)),
    ),
  );
}
