import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/presentation/account_editor_screen.dart';
import '../features/accounts/presentation/accounts_screen.dart';

import '../core/theme/motion.dart';
import '../features/app_lock/presentation/app_lock_setup_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/auth_success_screen.dart';
import '../features/auth/presentation/code_entry_screen.dart';
import '../features/auth/presentation/consent_screen.dart';
import '../features/auth/presentation/keep_setup_screen.dart';
import '../features/auth/presentation/linked_method_screen.dart';
import '../features/auth/presentation/email_entry_screen.dart';
import '../features/auth/presentation/save_your_setup_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/backtest/presentation/backtest_screen.dart';
import '../features/backtest/presentation/compare_screen.dart';
import '../features/backtest/presentation/practice_screen.dart';
import '../features/chart/presentation/chart_screen.dart';
import '../features/gym/presentation/drills_screen.dart';
import '../features/gym/presentation/gym_screen.dart';
import '../features/replay/presentation/replay_pick_screen.dart';
import '../features/replay/presentation/replay_screen.dart';
import '../features/coach/presentation/coach_history_screen.dart';
import '../features/coach/presentation/coach_screen.dart';
import '../features/mood/presentation/mood_screen.dart';
import '../features/home/presentation/close_day_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/open_screen.dart';
import '../features/journal/presentation/journal_screen.dart';
import '../features/journal/presentation/manual_trade_screen.dart';
import '../features/journal/presentation/trade_detail_screen.dart';
import '../features/journal/presentation/trades_screen.dart';
import '../features/markets/presentation/market_search_screen.dart';
import '../features/markets/presentation/markets_screen.dart';
import '../features/markets/presentation/pair_detail_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/plans/domain/plans.dart';
import '../features/plans/presentation/compare_plans_screen.dart';
import '../features/plans/presentation/manage_subscription_screen.dart';
import '../features/plans/presentation/plans_screen.dart';
import '../features/plans/presentation/purchase_result_screens.dart';
import '../features/settings/presentation/delete_account_screens.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/intro_screen.dart';
import '../features/panic/presentation/panic_screen.dart';
import '../features/me/presentation/me_screen.dart';
import '../features/me/presentation/share_card_screen.dart';
import 'routes.dart';
import '../features/mind/presentation/mind_screens.dart';
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
    GoRoute(path: Routes.authExists, builder: (c, s) => const LinkedMethodScreen()),
    GoRoute(path: Routes.merge, pageBuilder: (c, s) => _fade(c, s, const KeepSetupScreen())),
    GoRoute(path: Routes.consent, pageBuilder: (c, s) => _fade(c, s, const ConsentScreen())),
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
                    MainTab.markets => const MarketsScreen(),
                    MainTab.me => const MeScreen(),
                    _ => TabPlaceholderScreen(tab: tab),
                  },
                ),
                // The trades list and market search keep the tab bar (as drawn).
                routes: [
                  if (tab == MainTab.journal) ...[
                    GoRoute(path: 'trades', builder: (c, s) => const TradesScreen()),
                    GoRoute(path: 'mood', builder: (c, s) => const MoodScreen()),
                  ],
                  if (tab == MainTab.markets)
                    GoRoute(path: 'search', builder: (c, s) => const MarketSearchScreen()),
                  if (tab == MainTab.me) ...[
                    GoRoute(path: 'practice', builder: (c, s) => const PracticeScreen()),
                    GoRoute(path: 'badges', builder: (c, s) => const BadgesScreen()),
                    GoRoute(
                      path: 'mind',
                      builder: (c, s) => const MindToolkitScreen(),
                      routes: [
                        GoRoute(path: 'scorecard', builder: (c, s) => const ScorecardScreen()),
                        GoRoute(path: 'prompts', builder: (c, s) => const PromptsScreen()),
                        GoRoute(path: 'affirmations', builder: (c, s) => const AffirmationsScreen()),
                        GoRoute(
                          path: 'reading',
                          builder: (c, s) => const ReadingScreen(),
                          routes: [
                            GoRoute(
                              path: ':id',
                              builder: (c, s) => ReadingArticleScreen(id: s.pathParameters['id'] ?? ''),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'coach-history',
                      builder: (c, s) => const CoachHistoryScreen(),
                      routes: [
                        GoRoute(
                          path: ':id',
                          builder: (c, s) => CoachTranscriptScreen(sessionId: s.pathParameters['id'] ?? ''),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'backtest',
                      builder: (c, s) => const BacktestScreen(),
                      routes: [GoRoute(path: 'compare', builder: (c, s) => const CompareScreen())],
                    ),
                    GoRoute(path: 'replays', builder: (c, s) => const ReplayPickScreen()),
                    GoRoute(path: 'gym', builder: (c, s) => const GymScreen()),
                  ],
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
    GoRoute(path: Routes.shareCard, builder: (c, s) => const ShareCardScreen()),
    GoRoute(path: Routes.panic, pageBuilder: (c, s) => _cover(c, s, const PanicScreen())),
    GoRoute(path: Routes.addTrade, builder: (c, s) => const ManualTradeScreen()),
    GoRoute(
      path: Routes.tradeDetailPattern,
      builder: (c, s) => TradeDetailScreen(
        tradeId: s.pathParameters['id'] ?? '',
        openReview: s.uri.queryParameters['review'] == '1',
      ),
    ),
    GoRoute(
      path: Routes.pairDetailPattern,
      builder: (c, s) => PairDetailScreen(symbol: s.pathParameters['symbol'] ?? ''),
    ),
    GoRoute(
      path: Routes.chartPattern,
      builder: (c, s) => ChartScreen(symbol: s.pathParameters['symbol'] ?? ''),
    ),
    GoRoute(
      path: Routes.replayPattern,
      builder: (c, s) => ReplayScreen(
        symbol: s.pathParameters['symbol'] ?? '',
        day: DateTime.tryParse('${s.uri.queryParameters['day']}T00:00:00Z'),
        gym: s.uri.queryParameters['gym'] == '1',
      ),
    ),
    GoRoute(path: Routes.drills, builder: (c, s) => const DrillsScreen()),
    GoRoute(path: Routes.open, builder: (c, s) => const OpenScreen()),
    GoRoute(path: Routes.closeDay, builder: (c, s) => const CloseDayScreen()),
    GoRoute(path: Routes.settings, builder: (c, s) => const SettingsScreen()),
    GoRoute(path: Routes.appLock, builder: (c, s) => const AppLockSetupScreen()),
    GoRoute(path: Routes.accounts, builder: (c, s) => const AccountsScreen()),
    GoRoute(
      path: Routes.accountEditorPattern,
      builder: (c, s) => AccountEditorScreen(
        accountId: s.pathParameters['id']!,
        scrollToStrategy: s.uri.queryParameters['section'] == 'strategy',
      ),
    ),
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
