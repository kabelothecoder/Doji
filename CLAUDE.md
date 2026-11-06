# doji — CLAUDE.md

Trading-discipline app. **Not** a signals app. One Flutter codebase for
**iOS, Android and Windows**. Dark first. Local-first onboarding; Supabase
later.

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
                  data/ fake_market_data (SAMPLE prices) · sample_news_calendar · fake_brief · fake_brief_chat ·
                  brief_allowance_repository · presentation/ markets_screen (list) · market_search_screen ·
                  pair_detail_screen (1b) · markets_controller · brief_chat_sheet · widgets/
    settings/     account settings · sign-out sheet · delete account flow (A11–A12)
    accounts/     domain/ trading_account.dart (freezed: TradingAccount, StrategyCondition) · condition_eval.dart
                  (defaultConditions, measureConditions) · presentation/ accounts_controller · accounts_screen ·
                  account_editor_screen
    plans/        domain/plans.dart (catalogue, prices, recommendPlan) · data/billing_repository.dart (FAKE store)
                  presentation/ plans · compare · success/failed · manage subscription · upsell_sheet · widgets/
    home/         domain/home_models.dart (HomeSnapshot.fromJournal; score, grid, brief still SAMPLE) · presentation/
                  home_screen · open_screen · close_day_screen · post_trade_sheet · home_controller (in-memory) · widgets/
    journal/      domain/ trade · trade_math · journal_stats · process_grade · trade_filter · formatting
                  data/journal_repository.dart (shared_preferences) · presentation/ journal · trades · manual_trade ·
                  trade_detail · review_sheet · filters_sheet · journal_controller · widgets/
    coach/        domain/ coach.dart (Coach interface, CoachContext, CoachVoice) · coach_session.dart
                  data/ fake_coach.dart (FAKE coach) · coach_session_repository.dart (shared_preferences)
                  presentation/ coach_screen (1c) · coach_controller · save_session_sheet · widgets/
app/shell/        AppShell (StatefulShellRoute): DojiBottomBar on phones, DojiNavRail when wide. main_tab.dart = the 5 items,
                  MainTab.branches = the 4 shell branches (the coach is a cover, not a branch);
                  me is a TabPlaceholderScreen until its brief
test/  (unit, widget, a11y, goldens; helpers/app_harness.dart pumps the real app)   integration_test/   tool/ (asset export)
design/  handoff/ · system/ · brand/ · SOURCE.md       supabase/migrations/
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

## Auth (fake backend for now)

Source: `design/handoff/Doji Auth Screen iOS.dc.html` + `Doji Sign-in iOS.dc.html`.
Built: A1–A4e, A9, A10, A8 app lock, A11–A12. **Not built yet:** A5 (signed up
with another method), A6 (merge setups), A7 (18+ and consent).

- `FakeAuthRepository` is the only backend. Swap `authRepositoryProvider` for a
  Supabase implementation; the UI only sees `AuthRepository`.
- Fake email codes: any 6 digits work, `111111` = wrong (5 tries → 15-min lock),
  `000000` = expired. Apple/Google return sample `@example.com` identities.
- Method order is Apple, Google, email on **every** platform; screens look the
  same on iOS, Android and Windows (owner decision 2026-10-07). Planned real
  channels: iOS native; Android Google via Credential Manager + Apple via web
  OAuth; Windows both via system-browser OAuth with a deep-link return.
- Which setup wins: "welcome back" → the account's; "save your setup" → this
  device's (A6's default, applied silently until A6 exists).
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
  uses it too). Home's account comes from the journal (`accountStateFrom`: the starting size plus closed trades, so equity = balance and both trailing
  bases read the same); TODO(next-slice): balance, equity and their highs from the broker.
  Not modelled: trailing that locks at the starting balance.
- **Account currency** (USD, ZAR, EUR, GBP): `TradingAccount.accountCurrency`, set on the risk step
  for the first account and in the editor after.
  `RiskSizing.contractsForRisk` converts the loss per contract from the instrument's quote
  currency into it with a `RateSource`. The only source is `PlaceholderRateSource` (fixed rough
  rates, NOT for real sizing). TODO(next-slice): live rates via a Supabase edge function, cached
  with a timestamp, and refuse to size on a stale rate.
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
"sample data"), the grid and the rail's next news are still SAMPLE; TODOs mark each feed hookup.

- **Wide rule** (`core/platform/layout.dart › isWideLayout`): always wide on Windows, else from
  900px. Plans and the shell both use it. Wide = `DojiNavRail` + the docked `DojiRailPanel`
  (hidden when the content area is under 880px).
- `Doji Rail` is **not** a nav rail: it is an always-on-top companion panel (strategy state,
  rule meters, tilt, next news, log emotion; Ctrl+Shift+D). It is docked inside Home for now; a
  real always-on-top window needs `window_manager`. The nav rail has no artwork; it reuses the
  bottom bar's items. The branch area is wrapped in `Semantics(container: true)` so the rail stays
  visible to screen readers (see Gotchas).
- Not built: notification centre (bell is hidden), persistence of the open / reflection,
  and the me tab.

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
- Not built: the AI (Gemini, behind Supabase) reading the strategy text and the trader's sources
  and proposing conditions; per-account sessions; per-account coach
  voice; syncing accounts; moving a trade to another account.

## Markets list (sample prices for now)

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
- Not built (owner decision): ask doji, strategy versions, the chart image attach in the pair chat.

## Markets 1b, pair detail (sample prices for now)

Source: `design/handoff/Doji Hero Screens.dc.html` › 1b, plus Doji Core Tabs › 01b's states.
`PairDetailScreen` at `/markets/pair/:symbol` (`Routes.pairDetail`), full screen with the floating
`BriefChatBar` instead of the tab bar; reached from the markets list, Home's brief card and the
rail. On wide screens it is the list's second pane.

- **States** (Core Tabs › 01b): loading (cursor lines on the chart and the brief), market closed
  (chart at 40% + "market closed · opens …"), feed error ("price feed not responding." + try
  again, which asks for the quote, bars and brief again), no strategy yet (a card in place of
  01/02/04; conditions and check-again still show). The design's "build my strategy" button is
  not built: a strategy can't be edited after onboarding yet.

- **Boundaries**, each with one FAKE implementation: `MarketData` (`FakeMarketData`: a smooth,
  deterministic sample path per instrument, so timeframes agree; bars only while the market is
  open; null for custom symbols), `NewsCalendar` (`SampleNewsCalendar`: fixed weekly releases in
  each currency's zone; synthetics have none), `BriefSource` (`FakeBrief`), `BriefChat`
  (`FakeBriefChat`). Every price on screen says "sample prices · not a live feed".
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
- Not built: live prices (TODOs in `MarketData`), a real calendar, `SupabaseBrief` /
  the `ai-brief` edge function, server-side metering of the free brief, persisting reminders
  across launches (the button forgets; the OS keeps the notification), the rail's news.

## Coach (fake coach for now)

Source: `design/handoff/Doji Hero Screens.dc.html` › 1c, orb from the design system's `VoiceOrb`.
The coach is a **full-screen cover** at `/coach` (`MaterialPage(fullscreenDialog)`, cross-fade
under reduce motion), not a shell branch: tapping the orb (bar or rail) pushes it over the current
tab, long-pressing pushes `/coach?listen=1`, which opens the mic straight away. Home's "talk to
coach" pushes it too.

- `Coach` is the boundary (`opener`, `reply`); `FakeCoach` is the only implementation: keyword
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
- Not built: the real coach (`SupabaseCoach` + an Edge Function, streamed), text-to-speech in the
  chosen voice, voice-minute metering, a place to read saved sessions, Windows dictation, and a
  tappable / region-specific helpline (SADAG is South African).

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
  import, insights, the weekly review, the Windows workspace, the replay chart (a placeholder on
  trade detail), and saving the rail's emotion log or the post-trade sheet against a trade.

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
