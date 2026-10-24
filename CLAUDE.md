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
  (`BiometricAuth`); `clock` for testable countdowns
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
    markets/      domain/ instrument.dart · instrument_catalog.dart · market_hours.dart · risk_sizing.dart
    settings/     account settings · sign-out sheet · delete account flow (A11–A12)
    plans/        domain/plans.dart (catalogue, prices, recommendPlan) · data/billing_repository.dart (FAKE store)
                  presentation/ plans · compare · success/failed · manage subscription · upsell_sheet · widgets/
    home/         domain/home_models.dart (HomeSnapshot.fromJournal; score, grid, brief still SAMPLE) · presentation/
                  home_screen · open_screen · close_day_screen · post_trade_sheet · home_controller (in-memory) · widgets/
    journal/      domain/ trade · trade_math · journal_stats · process_grade · trade_filter · formatting
                  data/journal_repository.dart (shared_preferences) · presentation/ journal · trades · manual_trade ·
                  trade_detail · review_sheet · filters_sheet · journal_controller · widgets/
app/shell/        AppShell (StatefulShellRoute): DojiBottomBar on phones, DojiNavRail when wide. main_tab.dart = the 5 tabs;
                  markets/coach/me are TabPlaceholderScreens until their briefs
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
CTA opens `/plans?plan=<id>`. **Not wired yet:** auto-showing plans after onboarding, upsell
triggers (once per trigger per day), terms/privacy links, a real `openStoreSubscriptions`.

## Markets and prop rules (market-neutral)

Nothing in the app assumes forex. An **instrument** (`features/markets/domain/`) has a symbol, asset
class (forex, cfd, futures, crypto, stock, synthetic), a group for the UI, `MarketHours`, and
optional `tickSize` / `tickValue` / `contractSize`. Sizing fields are null where the broker feed
must supply them (Deriv synthetics): `RiskSizing` then returns null instead of guessing.

- **Catalogue** (`instrument_catalog.dart`) is the one list. Shown in the UI: forex, CFDs (metals,
  indices, oil), crypto, Deriv synthetics (Volatility 10–100, Boom/Crash 300/500/1000). Futures and
  stocks are in the model but hidden: `AssetClass.shownInUi`. Synthetic symbols are Deriv's own
  (`R_75`, `BOOM1000`); the chip label is `Instrument.label`. Specs are typical, not broker-exact.
- **Profile**: `ProfileDoji.instruments` (symbols; custom ones allowed) and `ProfileDoji.prop`
  (`PropRules`: firm, accountSize, dailyLossLimitPct, maxDrawdownPct, profitTargetPct, all optional).
  Risk stays a **percent**; lots/contracts only appear through `RiskSizing`.
- **Time zones are real** (`timezone` package, `markets/domain/time_zones.dart`, loaded lazily).
  `MarketHours` (always open, or weekly windows in the exchange's IANA zone) lives on the
  instrument: the FX week is Sunday 17:00 to Friday 17:00 New York, Globex Sunday 17:00 to Friday
  16:00 Chicago, US stocks 09:30–16:00 New York, so daylight saving moves them in UTC. Not
  modelled: exchange holidays and a broker's own daily breaks.
- **Sessions** (`onboarding/domain/sessions.dart`): `TradingSession` is the trader's own "when I
  trade" preference: Sydney 07:00, Tokyo 09:00, London 08:00, New York 08:00, each in its city's zone.
  `UserZone` is the trader's zone (device IANA id, else the manual UTC offset, which stays fixed).
  Open times are worked out for *today* (`clock.now()`), so they change when the clocks do. The
  Open reminder is stored as a fixed `HH:mm`: after a clock change it is an hour off the open.
  TODO(next-slice): store it as "30m before london" and recompute.
- **Drawdown** (`prop_drawdown.dart`): `PropRules.drawdownType` is static (`fixed`: equity below the
  starting balance) or trailing, and trailing follows the highest `balance` or `equity`
  (`trailingBasis`, default equity). `PropDrawdown.evaluate` has one branch per type; the Home
  meter and its label ("prop trailing equity drawdown") come from it, so a warning always uses the
  type chosen. Percentages are of the starting account size. Home's account comes from the journal
  (`accountStateFrom`: the starting size plus closed trades, so equity = balance and both trailing
  bases read the same); TODO(next-slice): balance, equity and their highs from the broker.
  Not modelled: trailing that locks at the starting balance.
- **Account currency** (USD, ZAR, EUR, GBP): `ProfileDoji.accountCurrency`, set on the risk step.
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
(`HomeSnapshot.fromJournal`). The doji score (labelled "sample data"), the grid, the AI brief's
conditions and the next news are still SAMPLE; TODOs mark each feed hookup.

- **Wide rule** (`core/platform/layout.dart › isWideLayout`): always wide on Windows, else from
  900px. Plans and the shell both use it. Wide = `DojiNavRail` + the docked `DojiRailPanel`
  (hidden when the content area is under 880px).
- `Doji Rail` is **not** a nav rail: it is an always-on-top companion panel (strategy state,
  rule meters, tilt, next news, log emotion; Ctrl+Shift+D). It is docked inside Home for now; a
  real always-on-top window needs `window_manager`. The nav rail has no artwork; it reuses the
  bottom bar's items.
- Not built: notification centre (bell is hidden), persistence of the open / reflection,
  coach long-press voice, the markets, coach and me tabs.

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
