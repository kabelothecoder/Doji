import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/motion.dart';
import '../features/app_lock/presentation/app_lock_setup_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/auth_success_screen.dart';
import '../features/auth/presentation/code_entry_screen.dart';
import '../features/auth/presentation/email_entry_screen.dart';
import '../features/auth/presentation/save_your_setup_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/coach/presentation/coach_screen.dart';
import '../features/home/presentation/close_day_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/open_screen.dart';
import '../features/journal/presentation/journal_screen.dart';
import '../features/journal/presentation/manual_trade_screen.dart';
import '../features/journal/presentation/trade_detail_screen.dart';
import '../features/journal/presentation/trades_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/plans/domain/plans.dart';
import '../features/plans/presentation/compare_plans_screen.dart';
import '../features/plans/presentation/manage_subscription_screen.dart';
import '../features/plans/presentation/plans_screen.dart';
import '../features/plans/presentation/purchase_result_screens.dart';
import '../features/settings/presentation/delete_account_screens.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/intro_screen.dart';
import 'routes.dart';
import 'shell/app_shell.dart';
import 'shell/main_tab.dart';
import 'shell/tab_placeholder_screen.dart';

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

/// A full-screen cover (handoff 1c): slides up on iOS, the platform's
/// full-screen route on Android and Windows. Reduce motion: the cross-fade.
Page<void> _cover(BuildContext context, GoRouterState state, Widget child) => DojiMotion.reduced(context)
    ? _fade(context, state, child)
    : MaterialPage<void>(key: state.pageKey, fullscreenDialog: true, child: child);

GoRouter buildRouter({String initialLocation = Routes.intro}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: Routes.intro, pageBuilder: (c, s) => _fade(c, s, const IntroScreen())),
    GoRoute(path: Routes.onboarding, pageBuilder: (c, s) => _fade(c, s, const OnboardingScreen())),
    GoRoute(path: Routes.save, pageBuilder: (c, s) => _fade(c, s, const SaveYourSetupScreen())),
    GoRoute(path: Routes.signIn, builder: (c, s) => const SignInScreen()),
    GoRoute(
      path: Routes.email,
      builder: (c, s) => EmailEntryScreen(
        intent: s.uri.queryParameters['intent'] == AuthIntent.save.name ? AuthIntent.save : AuthIntent.signIn,
      ),
    ),
    GoRoute(path: Routes.code, builder: (c, s) => const CodeEntryScreen()),
    GoRoute(path: Routes.authenticated, pageBuilder: (c, s) => _fade(c, s, const AuthSuccessScreen())),
    // Five tabs in one shell: bottom bar on phones, side rail on wide screens.
    // The coach is the centre item but not a branch: it is the cover below.
    StatefulShellRoute.indexedStack(
      pageBuilder: (c, s, shell) => _fade(c, s, AppShell(shell: shell)),
      branches: [
        for (final tab in MainTab.branches)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: tab.route,
                pageBuilder: (c, s) => NoTransitionPage<void>(
                  key: s.pageKey,
                  child: switch (tab) {
                    MainTab.home => const HomeScreen(),
                    MainTab.journal => const JournalScreen(),
                    _ => TabPlaceholderScreen(tab: tab),
                  },
                ),
                // The trades list keeps the tab bar (design: trades shows the tabs).
                routes: [
                  if (tab == MainTab.journal)
                    GoRoute(path: 'trades', builder: (c, s) => const TradesScreen()),
                ],
              ),
            ],
          ),
      ],
    ),
    GoRoute(
      path: Routes.coach,
      pageBuilder: (c, s) => _cover(c, s, CoachScreen(listen: s.uri.queryParameters['listen'] == '1')),
    ),
    GoRoute(path: Routes.addTrade, builder: (c, s) => const ManualTradeScreen()),
    GoRoute(
      path: Routes.tradeDetailPattern,
      builder: (c, s) => TradeDetailScreen(
        tradeId: s.pathParameters['id'] ?? '',
        openReview: s.uri.queryParameters['review'] == '1',
      ),
    ),
    GoRoute(path: Routes.open, builder: (c, s) => const OpenScreen()),
    GoRoute(path: Routes.closeDay, builder: (c, s) => const CloseDayScreen()),
    GoRoute(path: Routes.settings, builder: (c, s) => const SettingsScreen()),
    GoRoute(path: Routes.appLock, builder: (c, s) => const AppLockSetupScreen()),
    GoRoute(path: Routes.deleteAccount, builder: (c, s) => const DeleteExplainScreen()),
    GoRoute(path: Routes.deleteConfirm, builder: (c, s) => const DeleteConfirmScreen()),
    GoRoute(
      path: Routes.plans,
      builder: (c, s) => PlansScreen(preselect: PlanId.values.asNameMap()[s.uri.queryParameters['plan']]),
    ),
    GoRoute(path: Routes.planCompare, builder: (c, s) => const ComparePlansScreen()),
    GoRoute(path: Routes.planSuccess, pageBuilder: (c, s) => _fade(c, s, const PurchaseSuccessScreen())),
    GoRoute(path: Routes.planFailed, builder: (c, s) => const PurchaseFailedScreen()),
    GoRoute(path: Routes.subscription, builder: (c, s) => const ManageSubscriptionScreen()),
    GoRoute(path: Routes.accountDeleted, pageBuilder: (c, s) => _fade(c, s, const AccountDeletedScreen())),
  ],
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
