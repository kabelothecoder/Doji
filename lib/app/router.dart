import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/motion.dart';
import '../features/auth/presentation/save_your_setup_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/home/presentation/home_placeholder_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/splash/presentation/intro_screen.dart';
import 'routes.dart';

/// Cross-fade pages. The 250ms fade out of the intro is K5: the wordmark Hero
/// flies to the header while the destination fades in. Reduce motion: 200ms
/// linear, "cross-fades only".
Page<void> _fade(BuildContext context, GoRouterState state, Widget child) {
  final reduced = DojiMotion.reduced(context);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: reduced ? DojiMotion.reducedCrossFade : DojiMotion.introGlide,
    reverseTransitionDuration: DojiMotion.reducedCrossFade,
    transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
      opacity: reduced ? animation : CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

GoRouter buildRouter({String initialLocation = Routes.intro}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: Routes.intro, pageBuilder: (c, s) => _fade(c, s, const IntroScreen())),
    GoRoute(path: Routes.onboarding, pageBuilder: (c, s) => _fade(c, s, const OnboardingScreen())),
    GoRoute(path: Routes.save, pageBuilder: (c, s) => _fade(c, s, const SaveYourSetupScreen())),
    GoRoute(path: Routes.signIn, builder: (c, s) => const SignInScreen()),
    GoRoute(path: Routes.home, pageBuilder: (c, s) => _fade(c, s, const HomePlaceholderScreen())),
  ],
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
