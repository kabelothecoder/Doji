/// Route paths. Keep in sync with router.dart.
abstract final class Routes {
  static const intro = '/';
  static const onboarding = '/onboarding';

  // Main tabs (bottom bar on phones, side rail on wide screens).
  static const home = '/home';
  static const markets = '/markets';
  static const coach = '/coach';
  static const journal = '/journal';
  static const me = '/me';

  // Journal (design: Doji Trade Journal Phone.dc.html). The trades list lives in
  // the journal tab (bar stays); adding and reading one trade are full screen.
  static const trades = '/journal/trades';
  static const addTrade = '/journal/add';
  static const tradeDetailPattern = '/journal/trade/:id';

  /// [review] opens the review sheet as soon as the trade shows (right after saving it).
  static String tradeDetail(String id, {bool review = false}) =>
      '/journal/trade/${Uri.encodeComponent(id)}${review ? '?review=1' : ''}';

  // Daily loop (design: Doji Home.dc.html › 02): full screen, no tab bar.
  static const open = '/open';
  static const closeDay = '/close-day';

  // Auth (design/handoff/Doji Auth Screen iOS.dc.html)
  static const save = '/auth/save';
  static const signIn = '/auth/sign-in';
  static const email = '/auth/email';
  static const code = '/auth/code';
  static const authenticated = '/auth/authenticated';

  // Settings, app lock and account deletion
  static const settings = '/settings';
  static const appLock = '/settings/app-lock';
  static const deleteAccount = '/settings/delete';
  static const deleteConfirm = '/settings/delete/confirm';
  static const accountDeleted = '/account-deleted';

  // Plans (design/handoff/Doji Plans.dc.html)
  static const plans = '/plans';
  static const planCompare = '/plans/compare';
  static const planSuccess = '/plans/success';
  static const planFailed = '/plans/failed';
  static const subscription = '/settings/subscription';
}
