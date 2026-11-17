/// Route paths. Keep in sync with router.dart.
abstract final class Routes {
  static const intro = '/';
  static const onboarding = '/onboarding';

  // Main tabs (bottom bar on phones, side rail on wide screens).
  static const home = '/home';
  static const markets = '/markets';
  static const journal = '/journal';
  static const me = '/me';

  // Coach (design: Doji Hero Screens 1c): the centre tab opens a full-screen
  // cover, not a branch. A long-press on the orb opens it listening.
  static const coach = '/coach';
  static const coachListening = '/coach?listen=1';

  // Panic flow (design: Doji Panic Phone): a full-screen cover.
  static const panic = '/panic';

  // Journal (design: Doji Trade Journal Phone.dc.html). The trades list lives in
  // the journal tab (bar stays); adding and reading one trade are full screen.
  static const trades = '/journal/trades';

  /// Mood: check-in, tracker, trends (journal tab, bar stays).
  static const mood = '/journal/mood';
  static const addTrade = '/journal/add';
  static const tradeDetailPattern = '/journal/trade/:id';

  /// [review] opens the review sheet as soon as the trade shows (right after saving it).
  static String tradeDetail(String id, {bool review = false}) =>
      '/journal/trade/${Uri.encodeComponent(id)}${review ? '?review=1' : ''}';

  // Markets list (design: Doji Core Tabs › 01): search keeps the tab bar.
  static const marketSearch = '/markets/search';

  // Markets (design: Doji Hero Screens 1b): one instrument's chart and brief,
  // full screen with the floating ask bar instead of the tab bar.
  static const pairDetailPattern = '/markets/pair/:symbol';
  static String pairDetail(String symbol) => '/markets/pair/${Uri.encodeComponent(symbol)}';

  // The full chart with drawing tools and the co-pilot (no design file).
  static const chartPattern = '/markets/chart/:symbol';
  static String chart(String symbol) => '/markets/chart/${Uri.encodeComponent(symbol)}';

  // Practice (me tab, no design file): backtest, refine, replay, gym. The
  // lists keep the tab bar; a replay and the drills are full screen.
  static const mePractice = '/me/practice';
  static const meBadges = '/me/badges';

  /// Mind toolkit (design: Doji Me Phone › toolkit): hub and its four tools, bar stays.
  static const mind = '/me/mind';
  static const mindScorecard = '/me/mind/scorecard';
  static const mindPrompts = '/me/mind/prompts';
  static const mindAffirmations = '/me/mind/affirmations';
  static const mindReading = '/me/mind/reading';
  static String mindArticle(String id) => '$mindReading/${Uri.encodeComponent(id)}';

  /// Saved coach sessions and one transcript (me tab, bar stays).
  static const coachHistory = '/me/coach-history';
  static String coachTranscript(String id) => '$coachHistory/$id';

  /// Share your grid (design: Doji Me Phone › share + Doji Share Card): full screen.
  static const shareCard = '/share';
  static const meBacktest = '/me/backtest';
  static const meCompare = '/me/backtest/compare';
  static const meReplays = '/me/replays';
  static const meGym = '/me/gym';
  static const replayPattern = '/replay/:symbol';

  /// A replay of [symbol] on [day] (UTC date); [gym] = a scored practice on a
  /// random past session when [day] is null.
  static String replay(String symbol, {DateTime? day, bool gym = false}) {
    final q = [if (day != null) 'day=${day.toIso8601String().substring(0, 10)}', if (gym) 'gym=1'];
    return '/replay/${Uri.encodeComponent(symbol)}${q.isEmpty ? '' : '?${q.join('&')}'}';
  }

  static const drills = '/drills';

  // Daily loop (design: Doji Home.dc.html › 02): full screen, no tab bar.
  static const open = '/open';
  static const closeDay = '/close-day';

  // Auth (design/handoff/Doji Auth Screen iOS.dc.html)
  static const save = '/auth/save';
  static const signIn = '/auth/sign-in';
  static const email = '/auth/email';
  static const code = '/auth/code';
  static const authenticated = '/auth/authenticated';
  static const authExists = '/auth/exists'; // A5
  static const merge = '/auth/merge'; // A6
  static const consent = '/auth/consent'; // A7

  // Settings, app lock and account deletion
  static const settings = '/settings';
  static const appLock = '/settings/app-lock';
  static const deleteAccount = '/settings/delete';

  /// Trading accounts and their strategies (not the sign-in account).
  static const accounts = '/settings/accounts';
  static const accountEditorPattern = '/settings/accounts/:id';

  /// [strategy] scrolls the editor to the strategy (from MEASURED AGAINST).
  static String accountEditor(String id, {bool strategy = false}) =>
      '/settings/accounts/${Uri.encodeComponent(id)}${strategy ? '?section=strategy' : ''}';
  static const deleteConfirm = '/settings/delete/confirm';
  static const accountDeleted = '/account-deleted';

  // Plans (design/handoff/Doji Plans.dc.html)
  static const plans = '/plans';
  static const planCompare = '/plans/compare';
  static const planSuccess = '/plans/success';
  static const planFailed = '/plans/failed';
  static const subscription = '/settings/subscription';
}
