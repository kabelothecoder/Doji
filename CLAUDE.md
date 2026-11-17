# doji — CLAUDE.md

Trading-discipline app. **Not** a signals app. One Flutter codebase for
**iOS, Android and Windows**. Dark first. Local-first onboarding; Supabase
later.

## Phase: UI first (owner decision 2026-11-11)

All designed UI is built before any more backend work. While this phase lasts:

- Data stays on the device or in fakes behind the existing interfaces (shared_preferences, `Fake*`).
  No new Supabase tables, migrations or functions. Mark each spot the backend will plug in with
  `// TODO(backend):`.
- Order: auth A5–A7 (done) → panic flow (done) → Me (profile, grid, badges, share card done) → coach
  states (summary, saved, distress, transcript, voice minutes) + mood (check-in, emotion tracker,
  trends) (done) → mind toolkit (scorecard, prompts, affirmations, reading) (done) → journal (insights feed,
  imported trade).
- Sync each slice's design file into `design/handoff/` when the slice starts (see
  `design/SOURCE.md` › Not synced yet), read-only.
- Backend work (sync, deploys, real billing, real sign-in, `delete-account`) starts after this list.

## Stack

- Flutter 3.38 stable · Dart 3.10 · null-safe
- State: **Riverpod 3** (`flutter_riverpod`, no codegen) · Routing: **go_router 17**
- Models: **freezed 3** + `json_serializable` (run build_runner after edits)
- Local persistence: `shared_preferences` (pre-account answers survive restarts)
- Backend: `supabase_flutter` (optional at runtime; keys via `--dart-define` or `assets/env/.env`)
- Platform services, each behind an interface: `speech_to_text` (`VoiceInput`),
  `permission_handler` 12.x (`NotificationPermission`), `flutter_timezone`
  (`TimeZoneService`), `connectivity_plus` (`isOnlineProvider`), `local_auth` 3.x
  (`BiometricAuth`), `flutter_local_notifications` 22.x (`Reminders`, core/platform);
  `clock` for testable countdowns
- Fonts: Geist + Geist Mono, **bundled** in `assets/fonts/` (OFL)
- App id: `com.doji.app` (Android + iOS); Windows exe `doji.exe`

## Folder structure

```
lib/
  app/            app.dart · router.dart · routes.dart · bootstrap.dart
  core/
    theme/        tokens.dart · doji_theme.dart · typography.dart · motion.dart
    widgets/      design-system components (barrel: widgets.dart)
    haptics/  a11y/  platform/  env/
  features/
    splash/       domain/launch_destination.dart · presentation/intro_screen.dart
    onboarding/
      domain/     onboarding_step.dart (engine model) · onboarding_catalog.dart (the script)
                  profile_doji.dart (freezed) · config_lines.dart · rules.dart · risk.dart · sessions.dart
      data/       onboarding_repository.dart · mock_strategy_parser.dart · voice_input.dart · device_services.dart
      presentation/ onboarding_controller.dart · onboarding_screen.dart · step_drafts.dart · steps/
    auth/         domain/auth_repository.dart · data/fake_auth_repository.dart (FAKE backend)
                  presentation/ auth_controller.dart · A1 sign_in · A2 save · A3 email · A4 code · A9 success
    app_lock/     BiometricAuth (local_auth) · AppLockGate wraps the router · A8a setup screen
    markets/      domain/ instrument.dart · instrument_catalog.dart · market_hours.dart · risk_sizing.dart ·
                  candle · market_data · news · market_status · strategy_reading · pair_brief · brief_allowance ·
                  strategy_state
                  data/ routed_market_data (marketDataProvider) · deriv_market_data · mt5_market_data · mt5_api ·
                  live_rate_source · fake_market_data (SAMPLE prices) · sample_news_calendar · fake_brief ·
                  fake_brief_chat · brief_allowance_repository · presentation/ markets_screen (list) · market_search_screen ·
                  pair_detail_screen (1b) · markets_controller · brief_chat_sheet · widgets/
    chart/        domain/ drawing · chart_viewport · hit_test · drawing_editor · drawing_drafts · position_math ·
                  chart_note · copilot · bar_source · data/ chart_note_repository · copilot_service (FAKE + Supabase)
                  presentation/ chart_screen · chart_controller · what_is_this_sheet · pre_trade_check_sheet · widgets/
    settings/     account settings · sign-out sheet · delete account flow (A11–A12)
    accounts/     domain/ trading_account.dart (freezed: TradingAccount, BrokerLink, StrategyCondition) ·
                  condition_eval.dart (defaultConditions, measureConditions) · data/ broker_link_repository ·
                  presentation/ accounts_controller · accounts_screen · account_editor_screen · broker_link_section
    plans/        domain/plans.dart (catalogue, prices, recommendPlan) · data/billing_repository.dart (FAKE store)
                  presentation/ plans · compare · success/failed · manage subscription · upsell_sheet · widgets/
    home/         domain/home_models.dart (HomeSnapshot.fromJournal; score, grid, brief still SAMPLE) · presentation/
                  home_screen · open_screen · close_day_screen · post_trade_sheet · home_controller (in-memory) · widgets/
    journal/      domain/ trade · trade_math · journal_stats · process_grade · trade_filter · formatting
                  data/journal_repository.dart (shared_preferences) · presentation/ journal · trades · manual_trade ·
                  trade_detail · review_sheet · filters_sheet · journal_controller · widgets/
    history/      history.dart: HistoryRange · HistoryRepository (doji.history.v1.<SYM>.<TF>) · HistoryService.ensure
    backtest/     domain/ backtest (engine, stats) · fills (same bar = stop) · limits_check · refine (drafts, versions)
                  data/ backtest_repository (BacktestSession, doji.backtest.v1) · presentation/ practice_screen (me tab) ·
                  backtest_screen · compare_screen (refine) · backtest_controller · widgets/practice_widgets
    replay/       domain/replay.dart (ReplayBarSource, PositionTrack) · presentation/ replay_controller · replay_screen ·
                  replay_pick_screen
    gym/          domain/gym.dart (scorePractice, drills, streak) · data/gym_repository (doji.gym.v1) ·
                  presentation/ gym_screen · drills_screen
    coach/        domain/ coach.dart (Coach interface, CoachContext, CoachVoice) · coach_session.dart
                  data/ fake_coach.dart (FAKE coach) · coach_session_repository.dart (shared_preferences)
                  voice_minutes_repository.dart (doji.voice_minutes.v1) · domain/session_summary.dart (summary, isDistress)
                  presentation/ coach_screen (1c) · coach_controller · save_session_sheet · session_summary_view ·
                  coach_history_screen (+ transcript) · widgets/ (distress_card)
    mind/         domain/ mind_catalog (prompts, affirmations, reading) · scorecard · data/mind_repository (doji.mind.v1) ·
                  presentation/mind_screens (hub, scorecard, prompts, affirmations, reading, article)
    mood/         domain/mood.dart (MoodEntry, MoodTrends) · data/mood_repository.dart (doji.mood.v1) ·
                  presentation/mood_screen.dart (check-in, trends, tracker)
    analyst/      domain/ aggregates (AnalystFacts) · analyst (Analyst, WeeklyReview, AccountSource, focusRuleFor)
                  data/ fake_analyst (FAKE) · analyst_repository (doji.review.v1, doji.sources.v1)
                  presentation/ analyst_controller · weekly_review_card (+ ask sheet, FocusRuleLine) · sources_section
app/shell/        AppShell (StatefulShellRoute): DojiBottomBar on phones, DojiNavRail when wide. main_tab.dart = the 5 items,
                  MainTab.branches = the 4 shell branches (the coach is a cover, not a branch);
                  me = MeScreen (profile; practice at /me/practice)
test/  (unit, widget, a11y, goldens; helpers/app_harness.dart pumps the real app)   integration_test/   tool/ (asset export)
design/  handoff/ · system/ · brand/ · SOURCE.md       supabase/ migrations/ · functions/mt5 (+ _shared/mrpc.ts)
```

## The onboarding engine

Data-driven: **add or change a step in `onboarding_catalog.dart`, not in the UI.**
Each `OnboardingStep` has `id`, `prompt`, `input` (single | multi | text |
voiceOrText | stepper | slider | time | info | custom), `options`,
`validate`, `skippable`, `reply(answer)` (shown above the *next* question),
and `condition` (conditional steps are follow-ups of the step before them;
e.g. the parsed-strategy review only shows when there is a strategy).
`OnboardingController` persists after every change; `profile.doji` lines come
from `config_lines.dart` and each line knows which step edits it.

## Auth (Supabase email code, else fake)

Source: `design/handoff/Doji Auth Screen iOS.dc.html` + `Doji Sign-in iOS.dc.html`.
Built: A1–A4e, A5–A7, A9, A10, A8 app lock, A11–A12.

- **A5** (`/auth/exists`, `LinkedMethodScreen`): `sendCode` first asks `AuthRepository.lookUpEmail`; an
  Apple / Google account gets one button for that method and no code is sent. Supabase answers null
  until Apple / Google exist (TODO(backend)).
- **A6** (`/auth/merge`, `KeepSetupScreen`): "save your setup" into an account that already has a
  finished setup. This device is preselected (the most recent); `resolveMerge` keeps one, the other
  is removed. No back.
- **A7** (`/auth/consent`, `ConsentScreen`): new accounts only, before anything is applied
  (`AuthFlowState.pending`). Both boxes required. `ConsentRepository` (`doji.consent.v1`, versioned
  by `kConsentVersion`: bump it when the terms change) marks a new account pending, so launch
  (`decideLaunchRoute(needsConsent:)`) brings A7 back until it is agreed. Terms / privacy open a
  sheet saying they are published before launch; the "withdraw anytime in settings" row is not
  built. Consent is device-only (TODO(backend): store it on the account).
- After any sign-in, screens go to `AuthFlowState.next` (A7, A6 or A9), never straight to A9.

- `authRepositoryProvider` picks `SupabaseAuthRepository` when Supabase started
  (`supabaseClientProvider`, set in bootstrap), else `FakeAuthRepository` (local runs, tests).
  Supabase: email code only (`signInWithOtp` + `verifyOTP`; the email template must send
  `{{ .Token }}`); Apple/Google answer "use your email for now". Delete removes the profile row
  and unlinks brokers; erasing the auth user needs a `delete-account` function (not built).
- Fake email codes (FakeAuthRepository): any 6 digits work, `111111` = wrong (5 tries → 15-min lock),
  `000000` = expired. Apple/Google return sample `@example.com` identities. An email with `+apple` /
  `+google` before the `@` (or a stored Apple / Google account's email) shows A5. Every new fake
  account (including the samples on a fresh device) goes through A7.
- Method order is Apple, Google, email on **every** platform; screens look the
  same on iOS, Android and Windows (owner decision 2026-10-07). Planned real
  channels: iOS native; Android Google via Credential Manager + Apple via web
  OAuth; Windows both via system-browser OAuth with a deep-link return.
- Which setup wins: "welcome back" → the account's; "save your setup" → this
  device's, unless the account has its own: then A6 asks (this device preselected).
- Sign out and delete wipe local data (`AccountActions`). App lock is
  device-only and offered once, on the second Home visit.

## Plans (fake store for now)

Source: `Doji Plans.dc.html` + `Doji Plans Phone.dc.html`. `BillingRepository` is the store
boundary (StoreKit / Play Billing / Microsoft Store); `FakeBillingRepository` is the only
implementation (`next` forces cancelled/failed). Prices are placeholders, annual = 10x monthly.
Recommended plan comes from `recommendPlan(profile)`. Upsells call `showUpsellSheet`; its
CTA opens `/plans?plan=<id>`. `includesVoiceCoach(plan)` (pro, elite) decides voice vs text on
the coach and the brief chat. The free plan's "1 ai brief a day" is enforced on Markets 1b
(`BriefAllowance`, see Markets 1b). **Not wired yet:** auto-showing plans after onboarding, the
other upsell triggers (once per trigger per day), counting pro's 60 voice minutes,
terms/privacy links, a real `openStoreSubscriptions`.

## Markets and prop rules (market-neutral)

Nothing in the app assumes forex. An **instrument** (`features/markets/domain/`) has a symbol, asset
class (forex, cfd, futures, crypto, stock, synthetic), a group for the UI, `MarketHours`, and
optional `tickSize` / `tickValue` / `contractSize`. Sizing fields are null where the broker feed
must supply them (Deriv synthetics): `RiskSizing` then returns null instead of guessing.

- **Catalogue** (`instrument_catalog.dart`) is the one list. Shown in the UI: forex, CFDs (metals,
  indices, oil), crypto, Deriv synthetics (Volatility 10–100, Boom/Crash 300/500/1000). Futures and
  stocks are in the model but hidden: `AssetClass.shownInUi`. Synthetic symbols are Deriv's own
  (`R_75`, `BOOM1000`); the chip label is `Instrument.label`. Specs are typical, not broker-exact.
- **Profile**: instruments (symbols; custom ones allowed), `PropRules` (firm, dailyLossLimitPct,
  maxDrawdownPct, profitTargetPct, all optional) and the starting size live on the active
  `TradingAccount` (see Accounts and strategies); `ProfileDoji.instruments` / `.prop` read it.
  Risk stays a **percent**; lots/contracts only appear through `RiskSizing`.
- **Time zones are real** (`timezone` package, `markets/domain/time_zones.dart`, loaded lazily).
  `MarketHours` (always open, or weekly windows in the exchange's IANA zone) lives on the
  instrument: the FX week is Sunday 17:00 to Friday 17:00 New York, Globex Sunday 17:00 to Friday
  16:00 Chicago, US stocks 09:30–16:00 New York, so daylight saving moves them in UTC. Not
  modelled: exchange holidays and a broker's own daily breaks.
- **Sessions** (`onboarding/domain/sessions.dart`): `TradingSession` is the trader's own "when I
  trade" preference: Sydney 07:00–16:00, Tokyo 09:00–18:00, London 08:00–17:00, New York
  08:00–17:00, weekdays, each in its city's zone (`isOpenAt`, `closeInstant`, `nextOpenAfter`).
  `UserZone` is the trader's zone (device IANA id, else the manual UTC offset, which stays fixed).
  Open times are worked out for *today* (`clock.now()`), so they change when the clocks do. The
  Open reminder is stored as a fixed `HH:mm`: after a clock change it is an hour off the open.
  TODO(next-slice): store it as "30m before london" and recompute.
- **Drawdown** (`prop_drawdown.dart`): `PropRules.drawdownType` is static (`fixed`: equity below the
  starting balance) or trailing, and trailing follows the highest `balance` or `equity`
  (`trailingBasis`, default equity). `PropDrawdown.evaluate` has one branch per type; the Home
  meter and its label ("prop trailing equity drawdown") come from it, so a warning always uses the
  type chosen. Percentages are of `TradingAccount.startingSize`, the only size (Home's loss %
  uses it too). Home's account: with a broker link and a fresh figure (≤ `kBrokerFreshFor`,
  2 min), the broker's balance and equity (`brokerReadingProvider`, polled every 60s while watched)
  with highs tracked on the device (`BrokerReading.track`, `doji.broker.v1`); loss % = day-start
  balance − equity. Otherwise the journal (`accountStateFrom`: starting size plus closed trades,
  equity = balance). An old broker figure is never shown as current: Home uses the journal and the
  rules card says so (`HomeSnapshot.accountNote`). Shortcut: the day-start balance is the first one
  seen that day (losses closed before it are missed) until the function reads today's deals.
  Not modelled: trailing that locks at the starting balance.
- **Account currency** (USD, ZAR, EUR, GBP): `TradingAccount.accountCurrency`, set on the risk step
  for the first account and in the editor after.
  `RiskSizing.contractsForRisk` converts the loss per contract from the instrument's quote
  currency into it with a `RateSource`. `rateSourceProvider` = `LiveRateSource`: the broker's FX
  quotes through the `mt5` function (active account if linked, else any linked one), cached with
  the fetch time; older than 5 min = null, so `RiskSizing` / `TradeMath` refuse to size and the
  journal asks for the broker's figure. No link = same-currency only. `PlaceholderRateSource` is
  for tests only.
- **No migration**: stored data has `onboardingVersion`; anything older than `kOnboardingVersion`
  is dropped and the user starts over. Bump it when the stored shape changes without a migration.
- Home shows the stricter of the user's and the prop firm's daily loss limit, plus the drawdown
  meter. Not modelled yet: minimum trading days, consistency rules, firm presets.
- **Tests and the calendar**: anything that follows daylight saving, or renders Home (its grid,
  evening mode and market hours read `clock`, even blurred behind the app lock), must run on a
  fixed day: `withClock(summerDay, …)` from `test/helpers/clocks.dart` (the goldens do). Seed
  trades relative to that day: `sampleTrade(now: …)` from `test/journal/journal_fixtures.dart`.

## Home, shell and the rail (partly sample data)

Source: `Doji Home.dc.html` + `Doji Home Phone.dc.html` (home, the open, close your day, post-trade
sheet) and `Doji Rail.dc.html`. Home is derived, not stored: day zero = the profile was completed
today (checklist), evening = `eveningFromHour` (17:00) via `clock`, tilt = 2 losses in a row
today, day closed. Today's trades, loss, loss streak and the prop drawdown come from the journal
(`HomeSnapshot.fromJournal`). The AI brief card and the rail's strategy line read the same brief
as Markets 1b (`pairBriefProvider`); "open the brief" goes to 1b. The doji score (labelled
"sample data") and the rail's next news are still SAMPLE (the grid reads the journal and gym, see Me tab); TODOs mark each feed hookup.

- **Wide rule** (`core/platform/layout.dart › isWideLayout`): always wide on Windows, else from
  900px. Plans and the shell both use it. Wide = `DojiNavRail` + the docked `DojiRailPanel`
  (hidden when the content area is under 880px).
- `Doji Rail` is **not** a nav rail: it is an always-on-top companion panel (strategy state,
  rule meters, tilt, next news, log emotion; Ctrl+Shift+D). It is docked inside Home for now; a
  real always-on-top window needs `window_manager`. The nav rail has no artwork; it reuses the
  bottom bar's items. The branch area is wrapped in `Semantics(container: true)` so the rail stays
  visible to screen readers (see Gotchas).
- Not built: notification centre (bell is hidden), persistence of the open / reflection.

## Accounts and strategies (on this device)

No design file (design/SOURCE.md › Missing); built from `core/widgets/`. A trader has one or more
`TradingAccount`s in `ProfileDoji.accounts` (id, name, kind `deriv_synthetic | prop_challenge |
personal | demo`, currency, `startingSize`, instruments, `TradingRules`, optional `PropRules`, its
own `StrategyProfile`). One is active (`activeAccountId`, else the first). Getters on `ProfileDoji`
(`instruments`, `prop`, `rules`, `strategy`, `accountCurrency`, `startingSize`) read the active one,
so Home, the journal, 1b, the brief, the coach and the rail follow it; writes go through
`withActive` / `upsertAccount` / `switchAccount` / `removeAccount` (the last one stays).

- **Onboarding** makes the first account in `profile_mapper.dart` (`kFirstAccountId`): prop goal =
  prop challenge sized by the goal answer, only synthetics = deriv synthetics, else personal.
- **Strategy** = the trader's own words (`rawText`, typed or dictated with the onboarding
  `StrategyInput`) + `conditions`. A `StrategyCondition` is one of the kinds doji can measure today:
  `session`, `newsBuffer`, `tradesVsMax`, `dailyLossVsLimit`, `rangeBreak` (+ `closeBack`, the
  london break read from candles), or `manual` (shown "… · check on your chart", always waiting,
  never guessed). **No indicator kinds, now or as a fixed list** (owner decision 2026-11-02):
  strategies are personal. `defaultConditions(parsed)` gives a new account today's list;
  `measureConditions` evaluates them in order for the brief (a limit the account lacks is left out).
- **Trades** carry `accountId` (set on save). Home, the brief, its chat and the coach read
  `activeAccountTradesProvider`; the journal opens filtered to the active account
  (`FilterGroup.account`) and its stats follow that filter. Older trades with no `accountId` show
  under "all accounts" only (no migration).
- **Editor**: `/settings/accounts` (list, make active, add) and `/settings/accounts/:id` (name,
  kind, currency, starting size, risk / max trades / daily loss, prop rules, strategy text,
  conditions with up / down buttons, delete with a confirm; leaving with unsaved changes asks).
  Save stores the limits the steppers show (1% · 3 · 2% on a blank account), re-parses the strategy
  when its words changed (conditions kept; if the parser fails, `parsed` is cleared, the words are
  saved and the editor stays with "couldn't read your strategy, saved your words."), and is off
  while the starting size is not a number > 0. From settings and
  MEASURED AGAINST. Instruments are edited from markets search / 1b's bookmark (active account).
- Sign out and delete clear accounts with the profile (`clearAll`). `kOnboardingVersion` 4.
- **Strategy reader** (`accounts/data/strategy_reader.dart`): "read my words" under the strategy
  text asks `strategyReaderProvider` (Gemini via `ai-strategy` when Supabase runs, else
  `FakeStrategyReader` = keyword parser + `defaultConditions`). The proposal card offers "use these"
  (replaces the list), "add to mine" (appends new ones), "keep mine" (drops it); nothing is stored
  until save. Kinds are checked on the server and again on the device: anything else is `manual`.
  `SupabaseStrategyReader` is also the `StrategyParser` onboarding and save use.
- **Versions**: adopting a backtest draft keeps the old strategy as a numbered `StrategyVersion`
  (`TradingAccount.strategyVersions`, `strategyVersion` = current number). The editor shows them read-only.
  Still one strategy per account. `StrategyProfile.exits` (`ExitRules`: stop rule, buffer, target R, max bars)
  is what the backtest runs; null = doji's defaults, said on screen. `PropRules` gained `minTradingDays`
  and `consistencyPct` (backtest only). All nullable: no `kOnboardingVersion` bump.
- **Availability** (`onboarding/domain/availability.dart`, step after sessions): how often the trader can
  look at the charts in their hours (`not_flexible | semi_flexible | fully_flexible`), on `ProfileDoji`
  (profile-wide). `availabilityFit(availability, style)` says whether the style fits (scalping / day trading
  on a busy week does not); shown as the onboarding reply and under YOUR WEEK in the account editor
  (chips save at once). Plan: `design/research-intake-plan.md` › 1. The 90-day re-check and hopping guard
  are built too (`accounts/domain/strategy_checks.dart`): `hoppingLine` (2+ strategy changes in 42 days →
  "version n has x trades; under 30 is too few", in the editor) and `fitRecheckDue` (90 days after
  `availabilityCheckedAt` or `completedAt` → `FitRecheckCard` on Home: still fits / review it). 1b shows the fit
  line under YOUR ENTRY CONDITIONS when it does not fit.
- **Walk-away rules** (`accounts/domain/walk_away.dart`): optional `TradingRules` fields `dailyGainCap` (stop at
  +x% today), `giveBackPct` (stop after giving back x% of today's best running result) and `oneAndDone`.
  `WalkAway.of` measures today's closed trades (money over the starting size, else R × risk %, like
  `DaySummary.lossPercent`); the first rule reached shows as `WalkAwayCard` on Home and the rules list
  names the set ones. Edited under WALK AWAY in the account editor (off = null). Never blocks a trade.
  Not wired yet: the rail, the coach, the pre-trade check.
- **Trading window + guardrails** (`journal/domain/guardrails.dart`): `TradingRules.noTradesBefore` /
  `noTradesAfter` (local HH:mm, editor steppers in 15-min steps, off = null); Home shows "outside your
  trading window" in the walk-away card. `guardrailFlags` (worked out when shown, never stored, not part of
  the grade): no stop, risk over the account's risk % (10% tolerance, needs a starting size), opened within
  `kNewsBufferMinutes` of high-impact news (sample calendar), opened outside the window. Shown as GUARDRAILS
  on trade detail.
- **Plan per version** (slice 2b): `Trade.strategyVersion` is stamped on save from the account
  (`JournalController.add`); older trades have none. `versionOnNewWords`: saving new strategy words on a
  strategy that had words keeps the old one as a numbered version ("replaced by new words").
  `PlanKept.byVersion` (journal/domain/plan_kept.dart): plan kept on n of m reviewed trades per version
  (partly = not kept), shown under the strategy's versions in the editor. `StrategyProfile.wrongWhen` /
  `rightWhen` / `stayOutWhen`: the trader's own plan lines, edited under YOUR PLAN, IN YOUR WORDS. The Open
  has a plan step (mood → plan → pledge → line → done) showing the words, these lines and the conditions.
- Not built: reading the trader's sources (only their words); per-account sessions; per-account coach
  voice; syncing accounts; moving a trade to another account.

## Markets list

Source: `design/handoff/Doji Core Tabs.dc.html` › 01, drawn in `Doji Markets Phone.dc.html`.
`MarketsScreen` is the markets tab (`/markets`); `MarketSearchScreen` (`/markets/search`) keeps
the tab bar. Owner decisions (2026-10-24) are in `design/SOURCE.md` › Missing or contradictory.

- **Watchlist** rows (`WatchlistRow`): symbol, name, session badge (`sessionBadgeText`), sample
  price, and `StrategyStateBadge` from the brief's own conditions (`StrategyState.of`): met = all
  met, forming = at least half met, waiting = fewer than half. A count of rules, never a call.
- "MEASURED AGAINST" shows the parsed setup, no version, and opens the active account's editor at
  its strategy (`Routes.accountEditor(id, strategy: true)`).
- **Search**: tabs all · forex · metals · indices · crypto · synthetics (`SearchClass`); oil shows
  under all. Add / remove saves profile.doji at once (`toggleWatchlist`, shared with 1b's
  bookmark; removing the last asks). Added = white fill + check, not green.
- **Wide** (`isWideLayout` and ≥ 760px of content): the list (380) beside 1b as a second pane
  (`PairDetailScreen(embedded: true)`: no back, no Esc). Nothing opens until a row is picked
  (`marketsSelectionProvider`), so the free plan's one brief a day is never spent for the trader.
  Narrower, a row pushes 1b as on phones.
- Not built (owner decision): ask doji, the chart image attach in the pair chat. Strategy versions now
  exist (slice 05, see Accounts and strategies); the markets list still shows no version.

## Markets 1b, pair detail

Source: `design/handoff/Doji Hero Screens.dc.html` › 1b, plus Doji Core Tabs › 01b's states.
`PairDetailScreen` at `/markets/pair/:symbol` (`Routes.pairDetail`), full screen with the floating
`BriefChatBar` instead of the tab bar; reached from the markets list, Home's brief card and the
rail. On wide screens it is the list's second pane.

- **States** (Core Tabs › 01b): loading (cursor lines on the chart and the brief), market closed
  (chart at 40% + "market closed · opens …"), feed error ("price feed not responding." + try
  again, which asks for the quote, bars and brief again), no strategy yet (a card in place of
  01/02/04; conditions and check-again still show). The design's "build my strategy" button is
  not built: a strategy can't be edited after onboarding yet.

- **Boundaries**: `MarketData` is real per instrument (see Feeds); `FakeMarketData` (a smooth,
  deterministic sample path, bars only while the market is open, null for custom symbols) answers
  the rest. `NewsCalendar` (`SampleNewsCalendar`: fixed weekly releases in
  each currency's zone; synthetics have none), `BriefSource` (`FakeBrief`), `BriefChat`
  (`FakeBriefChat`). Every price says where it is from: `MarketData.sourceOf(symbol).label`
  ("live prices · deriv", "live prices · <broker server>", or "sample prices · not a live feed");
  the UI never asks which feed it is. A feed that fails throws `FeedUnavailable` → the feed error state.
- **The brief is measured, then written.** Conditions (`EntryCondition`, met | notMet | waiting) come
  from the session clock, the journal (`CoachContext`: trades vs max, the stricter loss limit), the
  news window (`kNewsBufferMinutes` = 30 either side) and, for a london break of the Asian range
  (`StrategyReading`), the candles: the range (Tokyo open → London open), the break, the first
  close back beyond the broken level. Any other strategy's entry stays "waiting" and the brief says
  to check it on the trader's own chart. 01/02/04/05 are written from those facts; it never says
  where price will go. `brief_test` scans everything it and its chat say for the copy rules.
- **Chart** (`PairChart`, CustomPainter): neutral grey candles, the strategy's levels as a green
  dashed band (ASIA HI / LO), the news window as an orange dashed line, last price tagged.
- **Free plan**: `BriefAllowance` (`doji.brief.v1`): the first instrument opened each local day
  gets its written brief and chat; others show it locked (conditions, chart and check-again still
  show) and the ask bar opens the `aiBrief` upsell. Paid plans are open. Home's card shows
  conditions only, so it is never gated. Sign out and delete clear it.
- **Ask about this brief**: `showBriefChatSheet` (iOS glass detented sheet; Android/Windows a
  Material sheet, title left). Suggested questions send straight away. Voice follows the coach's
  rule (pro/elite + device dictation), otherwise typed with the reason shown.
- **Remind me**: `Reminders` (`core/platform/reminders.dart`, flutter_local_notifications, inexact
  on Android, permission asked on first use) at the check-again time. Android needs core library
  desugaring and the two scheduled-notification receivers (in the manifest).
- **Watchlist** = the active account's instruments: the bookmark adds/removes and saves at once
  (removing the last one asks); Home and the journal re-read the profile.
- **AI** (with Supabase, see AI functions): `SupabaseBrief` runs `FakeBrief` first (conditions,
  levels, check-again stay measured on the device), then `ai-brief` writes 01, 02, 04 and the
  follow-ups. A null field, a copy-rule break or any failure keeps the device's own text, so the brief
  works offline. `SupabaseBriefChat` (`ai-brief-chat`) falls back to `FakeBriefChat`. The free brief
  is counted on the server too (`brief_days`, the trader's local day): a 402 saves today as used and
  bumps `briefUsedSignalProvider`, which locks 1b like the local allowance.
- Not built: streamed quotes (1b reads on open / check again), a real calendar, persisting reminders
  across launches (the button forgets; the OS keeps the notification), the rail's news.

## Chart and co-pilot (slice 04)

No design file (design/SOURCE.md › Missing). `ChartScreen` at `/markets/chart/:symbol` (`Routes.chart`),
opened by tapping 1b's chart (`_OpenChart`, nothing drawn at rest, so 1b's goldens don't move).
`PairChart` on 1b is unchanged.

- **Chart** (`features/chart/`): `DojiChart` + `ChartPainter` (CustomPainter, neutral grey candles, no
  third-party chart). Bars come from `BarSource` (`LiveBarSource` = slice 02's `MarketData`, 300 bars;
  backtest replay / the gym give their own). `ChartViewport` (start, count; 12–400 bars, 16 empty slots
  on the right) and `ChartGeometry` (pixels ↔ bar index ↔ time ↔ price; gaps take no room) are pure.
  Drag pans, pinch / Ctrl+wheel zooms, wheel pans, hover / long-press = crosshair. Not built: loading
  older bars past 300, streamed bars (try again reloads).
- **Drawings**: `Drawing` (zone, level, trend line, position) anchored to time + price, never pixels.
  `DrawingEditor` is immutable (one gesture = one undo step, 50 kept). `hitTest` (12px, selected
  drawing's handles first, later drawings on top). A tap draws a default-sized drawing
  (`draftDrawing`), a drag sizes it; then the tool goes back to select. Keys (Windows): V R H T P,
  arrows pan or move the selected drawing (a bar / a tick), + −, Delete, Ctrl+Z / Ctrl+Y, Enter =
  reason, Esc. Keys are ignored while a text field has focus.
- **Position box** records the trader's plan, never a suggestion: R, money at risk (starting size ×
  risk %) and size from `RiskSizing` (`PositionFigures`; null size = "size: broker figure needed").
  It names no side (copy rules ban the words): "stop below entry" / "stop above entry".
- **Accessible list** (`DrawingList`): beside the chart when wide (≥ 760px), a sheet on phones. Each
  drawing's name, prices, reason and the co-pilot's line; select / reason / delete; "add by price"
  for every tool, so the chart is never the only way in.
- **Co-pilot**: after a drawing, "what is this?" (`showWhatIsThis`: typed, or dictated on pro/elite,
  same rule as the coach; skip = no reason, no call). The reason is saved before the call.
  `Copilot` boundary: `SupabaseCopilot` (`ai-copilot` via `AiFunctions`) when Supabase started, else
  `FakeCopilot` (limits first, then the trader's own strategy sentence that matches, then a waiting
  condition, else a question). Replies that break the copy rules or `ratesOdds` fall back to the
  fake; 429 says "you've used today's co-pilot replies." `ratesOdds` (Dart and `_shared/guard.ts`)
  catches odds words; plain percentages of the trader's own limits are allowed.
- **Pre-trade check** (`showPreTradeCheck`): a new position box lists the account's conditions (1b's
  measured `pairBriefProvider` conditions) and today's limits from `CoachContext`. A limit reached is
  said plainly with "talk to the coach"; "continue" always works (doji never blocks the broker).
- **ChartNote** (`doji.chartnotes.v1`, `ChartNotesController`): drawing, reason, co-pilot turns,
  checklist, account, symbol, timeframe, time, `tradeId`. Deleted drawings stay as `deleted` notes so
  undo restores them with their reason. `JournalController.add` links notes on the same account +
  symbol from the 24 h before the trade opened (`notesLeadingTo`, shortcut). Trade detail shows them
  under "HOW YOU GOT HERE". Sign out / delete clear them. Sync TODO in `chart_note_repository.dart`.
- `ai-copilot` (`supabase/functions/ai-copilot/`, contract and prompt in `spec.ts`, 80 a day, 8 a
  minute): `supabase functions deploy ai-copilot` (not deployed). `deno test supabase/functions/ai-copilot/spec_test.ts`.
- Tests: `test/chart/` (domain, co-pilot + copy scan of every string in `lib/features/chart`, flow,
  a11y), `test/goldens/chart_golden_test.dart` (one per tool + Windows).

## Practice: backtest, replay, gym (slice 05)

Plan: `design/backtest-gym-plan.md`. No design file (design/SOURCE.md › Missing). Practice is
`PracticeScreen` (`/me/practice`, from the me tab's menu); `/me/backtest`, `/me/backtest/compare`,
`/me/replays`, `/me/gym` keep the tab bar; `/replay/:symbol?day=&gym=1` and `/drills` are full screen.

- **History** (`features/history/`): `HistoryService.ensure(symbol, tf, from, to)` fetches only the missing
  edges through `MarketData.candlesBetween` (Deriv `ticks_history`; MT5 via the `mt5` function's paged
  `bars`, which already took from/to; sample prices otherwise) in 2,500-bar windows, merges, keeps 20,000
  bars per instrument + timeframe on the device with the range covered. Never synced (re-fetchable).
- **Engine** (`runBacktest`, pure): per Tokyo open, `LondonBreak.measure` (shared with `FakeBrief`, so
  brief and backtest agree), entry = next bar's open (after the close back when asked), then
  `measureConditions` at the entry bar; manual conditions are listed "not tested, needs replay"; no
  `rangeBreak` = no measurable entry = no automatic setups (said plainly). The account's max trades and
  stricter daily loss always apply. Stop from `ExitRules`, target in R. **Fills (`fillOn`): a gap past
  the stop fills at the open (loss can pass 1R); stop and target in one bar = the stop** (`kSameBarRule`,
  shown in the UI); closed at the London close or after `maxBarsOpen`. No spread or costs (said).
  News = the sample calendar (said). Results: setups, R total/average, longest losing streak, drawdown in
  R, by session and instrument. Never a hit rate; "in this sample: n setups, dates"; under 30 =
  "small sample". `LimitsCheck` replays prop rules (daily loss, static/trailing drawdown via
  `PropDrawdown`, min days, consistency) or a personal account's own limits, closed trades only.
- **Refine** (`compare_screen`, `StrategyDraft`): one change at a time (session, stop rule, target,
  a condition on/off, max trades); others wait until the run. Tuning period = first 70% of the cached
  range; the held-back 30% can be used once per draft. `fitWarnings`: small sample, several changes on
  one period. Both columns look the same; doji never picks. Adopt = `adoptDraft` (versions above).
- **Replay**: `ChartScreen` with `replayId` / `replayBars` / `footer`; `ChartKey(symbol, replayId,
  timeframe)` keys `chartControllerProvider`. Replay notes are saved under
  `replay:<account>:<id>` so they never show on the live chart nor link to journal trades; a replay
  reads no live brief or quote (never spends the free brief). `ReplayBarSource` never returns a bar past
  the cursor. `PositionTrack.reveal` fills a box only on bars revealed after it was placed (entry when
  a bar trades through it, then `fillOn`; a moved stop is recorded). `chartFactsProvider` gives the
  pre-trade check and co-pilot the replayed day's conditions and limits. Keys: N next bar, Space play
  (not under reduce motion), the chart's own keys stay. Saved as `BacktestSession` (kind replay | gym).
- **Gym**: replay practice = a random past weekday (45 days) of an account instrument, "finish practice"
  scores it with `scorePractice` → `ProcessGrade` (setup there ±3 bars, stop not moved, max trades);
  skipped setups are shown, never graded. Drills (`buildDrills`, 3–5 a day, seeded by date): spot your
  setup (yes before an entry, no while the Asian range forms), place the stop (± a quarter of 1R), size
  the trade (`RiskSizing`, ±5%; skipped when sizing is null), after-losses (the account's max trades and
  stricter daily limit). A finished set = a practice day: `drillStreakProvider`, Home's grid dot
  (`MiniGrid.practice`), never a trading day.
- **Data**: `doji.backtest.v1`, `doji.gym.v1`, `doji.history.v1.*`; a record that fails to parse is
  skipped; `toAnalystJson` for slice 06; sync TODOs in the repositories; sign out / delete clear all three.
- Tests: `test/backtest/` (engine fixtures with known answers, history, refine + limits, copy scan of every
  string in the four features, flow + a11y), `test/replay/`, `test/gym/`, `test/goldens/practice_golden_test.dart`.
- Not built: spread/costs, partial exits, trailing stops in the engine, other measurable entries than the
  london break, real news history, intraday equity in the limits check, the markets list's version label.

## Feeds (live prices, broker equity, rates)

- **Deriv synthetics** (`R_*`, `BOOM*`, `CRASH*`): `DerivMarketData`, Deriv's public websocket
  `wss://api.derivws.com/trading/v1/options/ws/public` (no auth; `ticks_history` style ticks / candles).
  One socket, `ping` every 30s; a drop fails pending requests and reconnects with backoff 1s → 30s,
  failing fast meanwhile. `DERIV_APP_ID` is optional (sent as `app_id` when set).
- **MT5 via MetaRPC** (forex, metals, indices, oil): only through `supabase/functions/mt5`, called with
  the user's Supabase session. The MetaRPC key is a function secret; the terminal id and the investor
  password (Supabase Vault) live in `broker_links` (migration 0002), never on the device. The app keeps
  `TradingAccount.brokerLink` (server, login), edited in the account editor's "broker" section (links
  at once, apart from save). MetaRPC calls used: ConnectEx, Disconnect, AccountSummary, SymbolInfoTick,
  QuoteHistory/Bars. Symbols are sent as in the catalogue (no broker suffix map yet).
- **Routing**: `RoutedMarketData` (`marketDataProvider`): synthetic → Deriv; forex/metals/indices/oil →
  the active account's MT5 link if any; everything else (crypto, custom) → `FakeMarketData`.
- **Tests** never touch the network: `fakes.dart` overrides `marketDataProvider` (FakeMarketData) and
  `rateSourceProvider` (PlaceholderRateSource); `supabaseClientProvider` is null. Feed tests use an
  in-memory `DerivSocket` and `Mt5Api` (`deriv_market_data_test`, `feeds_test`, `broker_account_test`).
- **Run with the keys**:

  ```bash
  supabase db push                                  # migrations 0001, 0002 (Vault must be enabled)
  supabase secrets set MRPC_API_KEY=<key from mrpc.pro/my>
  supabase functions deploy mt5
  flutter run -d windows --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=… [--dart-define=DERIV_APP_ID=…]
  ```

  Sign in with the email code, then link the account under settings › accounts › broker.

## AI functions (Gemini behind Supabase)

Plan and reasoning: `design/ai-slice-plan.md`. The app never holds a model key.

- `supabase/functions/ai-coach | ai-brief | ai-brief-chat | ai-strategy`: each is `spec.ts` (contract,
  prompt, schema, guard) + `index.ts`, run by `_shared/ai.ts › handle`: session (401) → body (400) →
  crisis check in code, **before** the model (SADAG line, `_shared/guard.ts`) → free-brief claim (402)
  → rate limit (`ai_take`, 429) → Gemini → every string through `breaksCopyRules` (a failing field
  becomes the fallback and logs `COPY_RULE`) → JSON. Gemini failure = 502 `AI_UNAVAILABLE`. Logs carry
  only the function, the user id and an error code.
- Gemini: Interactions API (`_shared/gemini.ts`), model `gemini-3.8-flash` (override: `GEMINI_MODEL`),
  JSON via `response_format`. The system prompt is the start of `input`. Prompts: `_shared/voice.ts`
  (shared preamble) + each `spec.ts`. Facts only: `CoachContext`, the measured conditions, the active
  account's rules, today's journal, the trader's own words (fenced as TRADER WORDS).
- No streaming: the guard sees the whole reply first; the app types it out.
- The plan: `AI_TRUST_CLIENT_PLAN=true` trusts the plan the app sends (phase 1); otherwise the server
  treats everyone as free. Switch to a server-owned plan when billing is real.
- **Copy rules, one list**: `_shared/copy_rules.json` = `lib/core/copy_rules.dart › kBannedPhrases`
  (`test/core/copy_rules_test.dart` fails if they drift; it also scans guard.ts's fixed lines). The
  Supabase* clients check replies again on the device.
- **App side**: `aiFunctionsProvider` (`core/ai/ai_functions.dart`) is null without Supabase, so the
  fakes answer (local runs, tests). With it, every AI client falls back to its fake on any
  `AiFailure` (not signed in, offline, rate limit, 5xx): the screens have no AI error state.
- Tests: `deno test --allow-env --allow-read` in `supabase/functions` (stub `Deps`, no network:
  copy-rule break, crisis, 401/400/429/402/502). `real_deps.ts` is only imported by `index.ts`.
- **Run**: migration `0003_ai_usage.sql` (`ai_usage` + `ai_take`, `brief_days` + `ai_claim_brief`,
  RLS on, service role only), then:

  ```bash
  supabase secrets set GEMINI_API_KEY=<key from aistudio.google.com/apikey>
  supabase secrets set AI_TRUST_CLIENT_PLAN=true        # phase 1 only
  supabase db push
  supabase functions deploy ai-coach ai-brief ai-brief-chat ai-strategy
  ```

## Coach (Gemini with Supabase, else the fake coach)

Source: `design/handoff/Doji Hero Screens.dc.html` › 1c, orb from the design system's `VoiceOrb`.
The coach is a **full-screen cover** at `/coach` (`MaterialPage(fullscreenDialog)`, cross-fade
under reduce motion), not a shell branch: tapping the orb (bar or rail) pushes it over the current
tab, long-pressing pushes `/coach?listen=1`, which opens the mic straight away. Home's "talk to
coach" pushes it too.

- `Coach` is the boundary (`opener`, `reply`). With Supabase, `SupabaseCoach` (`ai-coach`, see AI
  functions) answers and falls back to `FakeCoach` on any failure. `FakeCoach`: keyword
  intents (crisis first, then call, done, revenge, sizing, stop, hesitation, urge, feeling,
  another) answered from `CoachContext` (profile.doji + today's journal: entry rule, risk, max
  trades, the stricter daily limit, loss streak, today's loss). It never says what the market will
  do; asked for a call, it declines. Crisis words get the SADAG line before anything else. Its
  replies are checked against the copy rules in `coach_domain_test`.
- **Voice or text**: push-to-talk (`VoiceInput`, the same speech_to_text wrapper as onboarding)
  when the plan includes the voice coach and the device has dictation; otherwise a text field in
  its place, with the reason under the orb (plan → "see pro trader", Windows, microphone refused).
  Push-to-talk: hold and release to send, or tap to open and tap to send; a speech pause sends
  too. Screen readers and the keyboard get the tap version. Haptic tick on press and release.
- The orb's states: idle, listening (breathes), speaking (rings; = the reply typing out until real
  audio). "THINKING…" while a reply is on its way. Reduce motion: still orb, opacity only.
- Voice picker writes `profile.doji › coach.voice`. A reply ticks Home's "try the coach" task.
- **Saving**: `CoachSessionRepository` (`doji.coach.v1`, shared_preferences); "save" keeps the
  transcript, saving again replaces it. Close, end, back and (iOS) pull-down ask before dropping
  unsaved words. Sign out and delete clear saved sessions.
- **States** (`Doji Coach Phone`, synced 2026-11-17; 1c's layout kept, see SOURCE.md): thinking
  ("THINKING…"), the inline transcript, voices (1c picker), text mode (keyboard / voice toggle in the top
  bar, only when voice is possible: `toggleMode`, `canSwitchToVoice`).
- **End → summary** (`SessionSummaryView`, `SessionSummary.of`): "end" with words said shows "what we
  talked about" (the trader's own lines, 3 at most), ONE FOCUS (`SessionSummary.focusFor`, by the first
  `CoachIntent` raised), "save to history" → "saved to coach history." + done, or "not now". Close / back
  still ask with the save sheet. Nothing said = straight out.
- **Distress** (`isDistress`, `domain/session_summary.dart`): crisis words plus "lost everything",
  "can't do this anymore", "blew my account", "hopeless"… set `CoachState.distress`: the orb goes still
  and smaller, `DistressCard` replaces the input row: SADAG first (tel:, else the number), "take a minute
  with me" (`/panic`), "keep talking" (`keepTalking`).
- **Voice minutes** (`data/voice_minutes_repository.dart`, `doji.voice_minutes.v1`): pro = 60 a month
  (`kProVoiceMinutes`), counted on the device as mic-open time (`_countVoice` on release / end); elite is
  fair use and free / basic have no voice, so `voiceMinutesLeft` is null for them. "pro · n min left this
  month" under the top bar. At 0: text mode (`TextReason.minutes`), the reason with the reset date
  (`voiceMinutesResetOn`, the 1st) and "add minutes"; `showUpsellSheet(voice)` opens when it runs out
  and from that button. TODO(backend): server metering in `ai-coach`.
- **Coach history** (me › coach history): `/me/coach-history` (`CoachHistoryScreen`, newest first) and
  `/me/coach-history/:id` (`CoachTranscriptScreen`), both from `savedCoachSessionsProvider`
  (`doji.coach.v1`; `save` invalidates it). Sign out / delete clear sessions and the minutes.
- Tests: `test/coach/` (domain + summary, distress, minutes, copy scan of `lib/features/mood` and the
  new coach files; screen flows for every state), `test/mood/mood_a11y_test.dart` (history 1x/2x),
  `test/goldens/mood_golden_test.dart` (history, transcript).
- Not built: streaming the coach (the guard needs the whole reply first), text-to-speech in the
  chosen voice (only mic time is metered), the design's starters / context row / voices sheet /
  transcript drawer, Windows dictation, and a tappable / region-specific helpline (SADAG is South African).

## Mood (on this device)

No drawn screens (`Doji Trade Journal Phone`, synced 2026-11-17, has none; SOURCE.md › Missing). `MoodScreen`
at `/journal/mood` (journal tab, bar stays; "mood · check in and trends" on the journal): check-in (feeling
chips, intensity 1–10, note, "log it"), trends, and the logged list (an entry on a trade opens it).

- **Model** (`features/mood/domain/mood.dart`): `MoodEntry` (id, feeling, intensity (null when nothing asked),
  note, time, accountId, optional tradeId, `MoodMoment` checkIn | open | beforeTrade | afterTrade).
  `kMoodFeelings` = The Open's moods + the journal's emotions. `MoodRepository` (`doji.mood.v1`, newest
  first, a broken record is skipped), `moodControllerProvider.log` stamps the active account.
  `activeMoodProvider` = the active account's entries (+ ones without an account). TODO(backend) for sync.
- **Logged from**: the check-in; The Open's mood step on continue (moment open, no intensity); the
  post-trade sheet / the rail's "log emotion" (a feeling is now required; after = against
  `latestTradeToday`, the active account's newest trade opened today (shortcut), before = no trade).
- **Trends** (`MoodTrends.of`): counts per feeling over 7 and 28 days, and in the 28 days: before a loss
  (logged in the hour before a losing trade opened) vs after (the hour after one closed). Under
  `kMoodSmallSample` (5) entries a list says "small sample". Bars are neutral grey with the count as a
  number; no green / orange, no price colours.
- Sign out / delete clear it. Tests: `test/mood/` (model, repository, trends on fixtures, flows: check-in,
  the open, post-trade against a trade, sign out; a11y 1x/2x), `test/goldens/mood_golden_test.dart`.
- Not built: mood on Home or the rail, the coach reading mood, editing / deleting an entry.

## Panic flow (on this device)

Source: `design/handoff/Doji Panic Phone.dc.html` (synced 2026-11-17). `PanicScreen` at `/panic` (`_cover`),
opened from Home's tilt banner ("i need a minute"). Six steps: breathe (`BreathingOrb`, 4-7-8, phase and
countdown as text, still under reduce motion), ground (two tickable lines), pause (`marketPauseProvider`,
`doji.panic.v1.pausedUntil`: 24 h with no written brief on 1b, optional reminder when it ends), talk (pushes the
coach), support (SADAG, `tel:` via url_launcher; a device that can't call shows the number), later (schedules a
09:00 check-in tomorrow). Sign out / delete clear the pause.

- Not built: the coach's calm mode (copy says "at your pace", not "calm mode"), the trusted contact row,
  Guard (locking trading), the pledge backdrop, the pause on Home's brief card and the rail.

## Me tab (on this device)

Source: `design/handoff/Doji Me Phone.dc.html` (synced 2026-11-17, **abridged**: a summary of every screen;
fetch the original with DesignSync for pixel work). `MeScreen` at `/me`: name + `RankPill`, doji score
(812, "sample data") + streak, the year grid (two halves of 27 weeks from 1 jan; cells from `dayCell`, the same
`keptDaysProvider` + `practiceDaysProvider` as Home's MiniGrid: kept L4, broken L1, no reviewed trades L0, drill day = dot),
rank ladder (`kRanks`, current = `ProfileDoji.rank`), what moves the score, menu (badges, mind toolkit, coach history,
practice, settings) and "i blew my account" → `/panic`. `BadgesScreen` at `/me/badges`.

- **Kept days** (`features/me/domain/me.dart`): a local date with reviewed trades, all graded A or B.
  Unreviewed trades don't count; days without trades never break a streak. Streak = kept days in a row from
  the newest; the 7 / 30-day badges use the best run ever; first clean week = a Monday-start week with
  reviewed trades and no break. Founding is locked until accounts sync (TODO(backend)).
- **Badges** (`earnedBadgeIds` → `badgesFor`): 7 / 30-day streak, first clean week (journal), first practice day,
  10 practice days (gym drill sets). Earned ids are stored with the date in `doji.badges.v1`
  (`BadgeRepository`, `earnedBadgesProvider`), so a badge stays earned if trades are later deleted. Sign out / delete
  clear it. TODO(backend): for sync. Tests: `test/me/` (rules on fixtures, flow, a11y 1x/2x, copy scan of
  `lib/features/me`), `test/goldens/me_golden_test.dart`.
- **Share card** (`/share`, `ShareCardScreen`; design `Doji Share Card`, synced 2026-11-17 byte-for-byte): story
  1080×1920 or post 1080×1080 (`ShareCard`, laid out at full size, `FittedBox` preview, text never scaled), logo,
  name (no handle yet), grid, rank, streak; never money. `RepaintBoundary.toImage` → PNG → `ImageOut`
  (`imageOutProvider`: `FilePicker.saveFile` for "save image", share_plus for "share"; tests override it via
  `AppHarness.pump(overrides:)`).
- Not built: handle and founding number, mood,
  the design's in-tab settings (the existing `/settings` is used), a real score.

## Mind toolkit (on this device)

Source: `Doji Me Phone` › toolkit, scorecard, prompts, affirmations, reading (full file read with DesignSync
2026-11-17; the handoff copy stays abridged). `features/mind/`. Routes keep the tab bar: `/me/mind` (hub, from
the me menu), `/me/mind/scorecard | prompts | affirmations | reading`, `/me/mind/reading/:id` (one short read).

- **Scorecard** (`domain/scorecard.dart`, `Scorecard.of`): this week (Monday local → now) on the active account.
  Lines, each "kept of sample + what it counts": plan kept (`PlanKept.byVersion`), process grade A or B,
  no guardrail flags (`guardrailFlags` without news: shortcut, news shows on trade detail), walked away when a
  walk-away rule was reached (`walkAwayDays`: per day, the first close that reaches a rule, kept when nothing
  opened after it; no rule set says so), kept days (`keptDays`), mood check-in days (`MoodMoment.checkIn`).
  Never money, never a rate. The design's mindset slider, hand-counted rule breaks, AI recap and "next
  week's focus" are not built (measured lines replace them; the focus rule lives in the weekly review).
- **Catalogue** (`domain/mind_catalog.dart`, like the onboarding catalogue): `kMindPrompts`, `kAffirmations`,
  `kReading` (short reads with paragraphs + books, no store links). Design copy is marked. Affirmation of the
  day and the first prompt card are seeded by the local date. `// TODO(backend): content feed`.
- **Store** (`data/mind_repository.dart`, `doji.mind.v1`): favourite ids, own affirmations (add / delete),
  read reading ids (opening a short read marks it), prompt answers. Bad records are skipped.
  `mindControllerProvider`. Sign out / delete clear it. TODO(backend) for sync.
- Tests: `test/mind/` (scorecard on fixtures, seeding, store, flow + sign out, a11y 1x/2x, copy scan of every
  string and catalogue entry), `test/goldens/mind_golden_test.dart`.

## Journal (on this device)

Source: Claude Design's `Doji Trade Journal` (journal home, trades, manual add, review sheet,
trade detail, filters). `JournalRepository` is the boundary; `PrefsJournalRepository`
(shared_preferences, key `doji.journal.v1`) is the only implementation, and a record that fails
to parse is skipped, not fatal. Home (and the rail docked in it) reads the same
`journalControllerProvider`.

- **Results are fixed at save**: `TradeMath` works out `pnl` and `riskMoney` in the account
  currency from the instrument and the `RateSource`, once, so a later rate never rewrites history.
  Where it cannot (Deriv synthetics, custom symbols, no rate) it returns null and the trader types
  the broker's figure. Trades without a risk are left out of R stats, and the count says so.
- **Process grade A–F** (`process_grade.dart`) grades how the plan was followed, never the
  outcome: a losing trade that kept the plan can be an A. It comes from the review's tags.
- Stats and the equity curve in R or money (`ResultUnit`) per calendar period; insights stay
  locked under `kInsightsFromTrades` (20). The view (period, unit, filters) is in memory.
- Sign out and delete clear the journal along with the profile (`auth_controller.dart`).
- Not built: Supabase sync (the plan is in the TODO in `journal_repository.dart`), broker / CSV
  import, insights beyond the analyst, the Windows workspace, the replay chart (a placeholder on
  trade detail), and saving the rail's emotion log or the post-trade sheet against a trade.

## Payout readiness and the analyst (on this device, fake analyst)

No design file (design/SOURCE.md › Missing). Backend spec, not built: `design/analyst-plan.md`
(`ai-analyst` contract, the full prompt, the guard order, Storage `sources` RLS policies).

- **Payout readiness** (`accounts/domain/payout_readiness.dart`): `PayoutReadiness.of` returns one
  `RuleDistance` per rule (trading days, consistency, daily loss, drawdown), each with a code-written
  line and a standing (`kept | close | broken | notSet`, shown as a word). Trading days = local
  dates with a closed trade. Consistency = largest positive day ÷ net total of all days, measured
  only when the total is above 0 (`bestDayShare`, shared with `LimitsCheck`). Daily loss and the
  drawdown are Home's own figures. Close = 80% of a limit (`kCloseShare`). Short of the minimum days
  is "close", never broken. Copy: "best day is 48% of total gains" ("profit" is a banned word).
  Shown on Home (`PayoutCard`, prop accounts only, `HomeSnapshot.payout`) and in the account
  editor (rules as saved + that account's journal). Firm presets stay out.
- **Aggregates** (`AnalystFacts.from`, pure): breaks by tag, after a loss (opened ≤ 60 min after a
  losing close, same local day) vs the rest, by local open hour, by session (first of the trader's
  sessions open at entry), by instrument, grade counts per ISO week (8), days past max trades with
  the extra trade's time, chart-note reasons matching the trader's written rules
  (`FakeCopilot.ruleMatching`) vs not, the newest auto backtest vs live trades on its instruments and
  dates (no gap under 10 each), gym over 28 days, and the payout lines. Buckets under 5 trades are
  `smallSample`. R counts only trades with a risk.
- **Analyst** boundary: `Analyst` (`weeklyReview`, `reply`). `FakeAnalyst` writes only from the
  facts (keyword intents; asked where price goes, it declines with `kAnalystNoCalls`; crisis words
  get the coach's SADAG line). Every line passes `breaksCopyRules` and `ratesOdds`, otherwise
  `kAnalystFallback`. TODO(backend): `SupabaseAnalyst`.
- **Weekly review** (journal, `WeeklyReviewCard`): once the active account has
  `kInsightsFromTrades` (20) trades, last week's review is written on first show and stored
  (`doji.review.v1`): kept, broke, and one focus rule (`focusRuleFor`: the most used tag, or max
  trades when more days broke it). "focus on this rule" accepts it. For the week after, it shows
  on Home (`FocusRuleLine`) and in the rail (`DojiRailPanel.focusRule`). Under 20 the insights card
  says why and how many the account has.
- **Ask the analyst**: `showAnalystChatSheet` uses the brief chat's `ChatSheet` with
  `AnalystChatController` (`ChatController` is the shared base: voice, mic, send).
- **My sources** (account editor, `SourcesSection`): notes (text) and PDFs (file name only;
  `file_picker` via `pickPdfProvider`), `doji.sources.v1`, saved at once. Note text joins the
  strategy words for the analyst and the co-pilot (`strategyWordsWithSources`). PDFs are read once
  sync is on. Sign out and delete clear reviews and sources.
- Tests: `test/accounts/payout_readiness_test.dart`, `test/analyst/` (aggregates on fixtures,
  analyst text + copy scan of every string in the slice, flow, a11y at 1x and 2x),
  `test/goldens/analyst_golden_test.dart`. The Deno test (a model reply that predicts price is
  replaced) comes with the function.

## Design tokens (mirror of `Doji Design System.dc.html`)

| Token | Value |
|---|---|
| bg | `#050607` |
| elevated-1 / elevated-2 | `#0F1113` / `#17191C` |
| separator | `#26292E` · inner divider `#1C1E22` |
| text primary / secondary / tertiary | `#F5F5F7` / `#A1A1A6` / `#6E6E73` (tertiary: 20pt+ only) |
| doji-green | `#2FD67B` (rule kept, primary action) |
| tilt-orange | `#FF9F0A` (risk, rule broken) |
| grid L0–L4 | `#101A14 → #16391F → #1E6B3E → #27A35C → #2FD67B` |
| bone (light mode, stub) | `#F3F1EA` |
| radii | chip 10 · card 16 · sheet 24 · pill full |
| spacing | 4pt grid: 4 8 12 16 20 24 32 48 · margins 20 (Android 22) |
| touch targets | ≥ 44pt iOS/desktop, ≥ 48dp Android (`DojiTokens.minTarget`) |
| glass | elevated-1 @ 60% · blur 24–30 · saturate 1.4 · 1px white @ 8% |
| motion | spring.standard 380/34 · spring.sheet 260/30 · grid.fill 360ms, 4ms stagger · cursor 1.1s step |

**Differences from the brief's table: none.** The design system *adds*
`bone`, the `#1C1E22` divider, the type scale (`DojiType`) and motion specs.
Access colours via `DojiTokens.of(context)` (ThemeExtension) or `DojiColors`.

## Design-sync rule

- Claude Design's Doji design system (`Doji Design System.dc.html` in project
  `057f3c25-7d60-4039-8d1e-6ceac0713cc9`) is the **source of truth** for
  tokens and components.
- To change a token: **change it in Claude Design, then re-sync** into
  `design/system/` and mirror it in `tokens.dart`. Never hand-edit a token
  only in Flutter.
- Every widget in `core/widgets/` names its design-system counterpart in its
  doc comment ("Design system: `DojiButton` …"). Keep it that way.
- Sync is read-only unless the owner asks for a push. See `design/SOURCE.md`.

## Naming rules

- Widgets: `Doji*` for primitives (`DojiButton`, `DojiStepper`); design-system
  names verbatim otherwise (`TerminalLine`, `ConfigPanel`, `GridCell`, `RankPill`).
- Answer values and profile.doji keys: `snake_case` (`day_trader`, `prop_challenge`).
- Step ids: `StepIds.*` camelCase constants; never raw strings in UI code.
- Files: `snake_case.dart`, one public widget per file in `core/widgets/`.
- Copy: lowercase, calm, honest. Brand buttons keep official casing ("Continue with Apple").

## Product rule: no buy/sell language

**Never** write buy/sell calls, "signals", "guaranteed", win rates or profit
promises — in UI copy, notifications, AI prompts, or sample data. Price is
always neutral grey, never green or orange. Green/orange never appear without
a text label. No invented stats or testimonials. A test (`copy rules`) scans
the onboarding script; extend it when adding copy.

## Accessibility (non-negotiable)

Text scaling to 200% without clipping (scroll, don't clip; `DojiApp` clamps at
2.0) · targets ≥ 44pt/48dp · contrast ≥ 4.5:1 · `Semantics` labels on icon
buttons · colour never the only signal (checks, labels) · reduce motion
(`DojiMotion.reduced`) → cross-fades only, instant typing, no `AnimatedSize`
(use `DojiAnimatedSize`). `test/core/a11y_test.dart` enforces these.

## Run

```bash
flutter pub get
flutter run -d windows            # or an Android emulator / iOS simulator
flutter run -d windows --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…
```

## Test

```bash
flutter analyze                    # must be zero issues
dart format .
flutter test                       # unit + widget + a11y + goldens (goldens are Windows-rendered)
flutter test --exclude-tags golden # on macOS/Linux CI
flutter test test/goldens --update-goldens   # only after an intended visual change
flutter test integration_test -d windows     # full flow, real app
dart run build_runner build --delete-conflicting-outputs   # after editing freezed models
```

## Regenerate icons and splash

```bash
flutter test tool/export_brand_assets_test.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Working rules for Claude

- **Never run `git checkout`, `git restore`, `git reset`, `git stash` or `git clean` on this
  repo's files without asking first.** The working tree holds a lot of uncommitted work; these
  commands silently discard it. To undo your own edit, re-edit the file by hand.

## Gotchas learned in this repo

- `test/flutter_test_config.dart` loads the bundled Geist fonts. Never create or overwrite a file
  with that name (without it every golden renders in the Ahem block font and text-width tests break).

- `pumpAndSettle` never settles: cursors blink forever. Pump explicit durations.
- A ticker's first frame has zero elapsed time: pump once before timing.
- Don't read `MediaQuery` in `initState` (post-frame instead).
- `AnimatedSize` with `Duration.zero` asserts; use `DojiAnimatedSize`.
- Windows PowerShell 5.1 `Get-Content/Set-Content` mangles UTF-8 (—, ›, █).
  Edit files with the editor or Node, not PowerShell.
- Reduce motion makes `AnimationController` run at 5% speed. Timers that pace
  a hand-off (A9's 3.6s) need `animationBehavior: AnimationBehavior.preserve`.
- `debugDefaultTargetPlatformOverride` reset in `addTearDown` is too late for
  Flutter's invariant check. Use `variant: ios` / `TargetPlatformVariant`.
- go_router: `currentConfiguration.uri` ignores `push`; read
  `currentConfiguration.last.matchedLocation` for the top route.
- `local_auth` on Android needs `FlutterFragmentActivity`, `USE_BIOMETRIC` and
  AppCompat launch themes (Android ≤ 8 crashes otherwise). Keep them.
- A `Column` inside `Scaffold.bottomNavigationBar` / a `Row(crossAxisAlignment: end)` gets loose
  height: without `mainAxisSize: min` it grows to the full screen and the body collapses to 0.
- `tester.ensureVisible` (and so `h.tap`) scrolls the target to the *top* of a list; scroll back up
  before asserting on cards above it. Lazy list items below the fold don't exist: use
  `scrollUntilVisible` first.
- `permission_handler` ≥ 13 pulls an AGP 9-only Android plugin; stay on 12.x
  until the Flutter Android template moves to AGP 9.
- A route's modal barrier carries `BlockSemantics`, which hides every node painted *before* it in
  the same semantics container. A nested navigator (the shell's branches) next to other UI hides
  that UI from screen readers unless the navigator is wrapped in `Semantics(container: true)`.
- riverpod 3.3 pauses providers watched only by hidden screens (TickerMode: other shell tabs, Home
  and markets under settings) and resumes them *while a frame builds*. A paused provider left only
  "may have changed" is rebuilt by its dependent's flush and notifies it, and riverpod then schedules
  a refresh mid-build: "markNeedsBuild() called during build". When account data changes, call
  `invalidateAccountReaders` (accounts_controller.dart): it marks every account-derived provider
  for recompute at once, so those notifications return early. Add new account readers to its list;
  `select` where only one field matters. Fixed upstream in riverpod 3.4.1 (needs Dart 3.12).
- In widget tests `clock.now()` advances with `pump` (hold durations work), but `withClock(fixed)`
  freezes it. The harness's reduce-motion flag is cleared only at teardown: test motion on and off
  in separate `testWidgets`, not in one loop.
