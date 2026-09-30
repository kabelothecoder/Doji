# doji_

Trading discipline, not signals. The first slice: **splash + onboarding**,
built from the Claude Design handoff in `design/`.

Flutter for **iOS, Android and Windows** from one codebase. Dark first.

## What's in this slice

- **Native splash** (icon on `#050607`) → **1.5s animated intro**: a price
  candle wiggles green → orange, settles into a perfect doji, and becomes the
  "i" of `doji_`, which glides into the onboarding header (shared-element).
- **Onboarding as a terminal conversation**: doji types each question; answers
  land live in `profile.doji`, and tapping any line edits it.
  Boot · manifesto · identity · goal · struggles · strategy (typed or dictated,
  parsed into structured rules) · risk and limits · rules v1 · coach voice ·
  the Open ritual · compile · **hold-to-pledge** (lights the first Grid square)
  · save your setup.
- Local-first: every answer is saved as you go; kill the app and it resumes.
- Windows: centred 720px conversation with `profile.doji` as a side pane;
  keyboard-first (`1–9` pick, `↵` continue, `Esc` back, `Ctrl+E` edit a line).
- Auth is a **stub** ("continue without account" keeps the profile on device,
  flagged `pendingSync`). Home is a placeholder.

## Setup

Requirements: Flutter **3.38.x stable** (Dart 3.10). Windows builds need Visual
Studio (Build Tools) with the C++ desktop workload.

```bash
flutter pub get
```

### Environment (optional)

The app runs fully local with no config. To connect Supabase:

```bash
cp .env.example assets/env/.env      # then fill in the two values
```

or pass them at build time (these win over the file):

```bash
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_…
```

Never commit real keys. `assets/env/.env` and `.env` are gitignored.

### Database

`supabase/migrations/0001_profiles.sql` creates `profiles` (one row per user,
`profile_doji jsonb`, indexed `rank` / `doji_score` / `created_at`) with Row
Level Security: users read and write only their own row, and only the server
changes rank and score. **It has not been applied anywhere.** Apply it with
the Supabase CLI when ready: `supabase db push`.

## Run

```bash
flutter run -d windows
flutter run -d <android-emulator-id>
flutter run -d <ios-simulator-id>      # needs a Mac
```

Debug builds show a "reset onboarding (debug)" button on the Home placeholder.

### iOS without a Mac

`codemagic.yaml` has an **untested** starting workflow (`ios-unsigned`) that
builds the iOS app with no signing, plus a commented TestFlight workflow to
fill in once App Store Connect is set up. The Podfile already enables the
microphone, speech and notification permissions `permission_handler` needs.

## Test

```bash
flutter analyze                                  # zero issues
flutter test                                     # 74 tests: unit, widget, a11y, goldens
flutter test integration_test -d windows         # splash → onboarding → pledge → save → home
```

- **Goldens** (`test/goldens/`) cover boot, a question screen (risk), compile
  and pledge at 390×844 and 1440×900, plus the intro keyframes K1–K5. They are
  rendered on Windows; on macOS/Linux CI run `flutter test --exclude-tags golden`.
  After an intended visual change: `flutter test test/goldens --update-goldens`.
- **Accessibility** (`test/core/a11y_test.dart`): tap targets (44pt/48dp),
  labelled targets, text contrast, 200% text without overflow, keyboard-only flow.

## Brand assets

The app icon and symbol are **coded stand-ins** until the real SVGs arrive
(see `design/SOURCE.md`). To swap them:

```bash
# 1. replace assets/svg/doji-app-icon.svg (and doji-symbol.svg)
flutter test tool/export_brand_assets_test.dart   # → launcher + splash PNGs
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Project notes

- Conventions, tokens, the design-sync rule and the **no buy/sell language**
  rule: [`CLAUDE.md`](CLAUDE.md).
- Where the design came from and what was missing: [`design/SOURCE.md`](design/SOURCE.md).
- Fonts: Geist and Geist Mono (SIL OFL 1.1, `assets/fonts/OFL.txt`).
