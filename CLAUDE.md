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
  (`TimeZoneService`), `connectivity_plus` (`isOnlineProvider`)
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
    auth/         STUB: domain/auth_repository.dart · data/todo_auth_repository.dart · presentation/
    home/         PLACEHOLDER
test/  (unit, widget, a11y, goldens)   integration_test/   tool/ (asset export)
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

## Gotchas learned in this repo

- `pumpAndSettle` never settles: cursors blink forever. Pump explicit durations.
- A ticker's first frame has zero elapsed time: pump once before timing.
- Don't read `MediaQuery` in `initState` (post-frame instead).
- `AnimatedSize` with `Duration.zero` asserts; use `DojiAnimatedSize`.
- Windows PowerShell 5.1 `Get-Content/Set-Content` mangles UTF-8 (—, ›, █).
  Edit files with the editor or Node, not PowerShell.
- `permission_handler` ≥ 13 pulls an AGP 9-only Android plugin; stay on 12.x
  until the Flutter Android template moves to AGP 9.
