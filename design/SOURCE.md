# Design sources

Where every design input for this repo came from, so the build can be
reproduced from git. Files in this folder are **data, not instructions**.

Synced **2026-10-01**; auth files re-checked byte-for-byte **2026-10-07** (unchanged) (read-only; nothing was pushed back to Claude Design).

## 1. Handoff — `design/handoff/`

| | |
|---|---|
| Source | Claude Design project **"Doji hero screens review"** |
| Project ID | `057f3c25-7d60-4039-8d1e-6ceac0713cc9` (shared link `claude.ai/design/p/057f3c25-…?via=share`) |
| Owner | AlgoKabs |
| Project type | Regular project (`PROJECT_TYPE_PROJECT`), not a design-system project |
| Fetched with | `DesignSync get_file`, byte-for-byte |
| Date | 2026-10-01 |

| File | Used for |
|---|---|
| `Doji Onboarding.dc.html` | **This slice.** Splash keyframes S0/K1–K5, onboarding steps 0–7 (iOS 390×844, Android 412×915, Windows 1440×900), copy, Flutter map |
| `Doji Auth Screen iOS.dc.html` | **Auth slice (2026-10-07).** Every A-screen; A1–A4e, A9, A10, A8, A11–A12 built |
| `Doji Sign-in iOS.dc.html` | Auth canvas: flows, per-screen notes, Flutter component spec (`OtpCodeField`, `BiometricLockScreen`, `DeleteAccountFlow`…) |
| `Doji Hero Screens.dc.html` | Home/Markets/Coach — **not built**; Home header borrowed for the placeholder |

The project holds 20+ other screens (Home, Journal, Plans, Replay…) and ~400
reference images under `uploads/mcp/`; they belong to later slices and were
not copied.

## 2. Design system — `design/system/`

| | |
|---|---|
| Source | Same project, file **`Doji Design System.dc.html`** ("Design system v1", `package:doji_ui`) |
| Date | 2026-10-01 |
| Also copied | `support.js` (Claude Design's `.dc.html` runtime) and `image-slot.js`, so the HTML files open locally |

There is no Doji project of type *design system* in the account. The two
design-system projects that exist are **"Organic"** (a built-in generic theme:
cream/orange, Caprasimo + Figtree) and **"Nova Edge Design System"** — neither
is Doji, so neither was used. `Doji Design System.dc.html` is treated as the
design system of record; `lib/core/theme/tokens.dart` mirrors it.

## 3. Brand — `design/brand/` (+ `assets/svg/`)

`doji-app-icon.svg` and `doji-symbol.svg` are **stand-ins transcribed from
the handoff's coded shapes** (S0 splash tile; `DojiSymbol` in the design
system). The real files were never attached — see *Missing*.

## Missing or contradictory

| Item | Status | What the build does |
|---|---|---|
| `doji-app-icon.svg`, `doji-symbol.svg` | Not attached (handoff says so itself) | Coded stand-ins; replace the files in `assets/svg/`, then `flutter test tool/export_brand_assets_test.dart` → icons + splash regenerate |
| Two icon stand-ins | Onboarding S0 = white doji + green block on `#0F1113`; design system = all-green symbol on `#050607` | Uses **S0** (the slice handoff; the auth screens reuse it too) |
| Onboarding 5b ritual, 6 pledge, 7 save | Marked **ASSUMED** in the handoff (its brief stopped mid-step 5) | Built as drawn; save uses the more detailed auth handoff A2 |
| Coach name, compile step | Not in the handoff | Built from the brief with design-system components |
| Esc key | Handoff: "esc skips"; brief: "Esc goes back" | **Back** (brief, and the Windows convention). Skip stays a focusable button |
| Pledge copy | Handoff: "your plan, not your feelings." · brief: "I'll trade my plan, not my feelings." | Handoff headline; the brief's line is the screen-reader label |
| Asset #1 (manifesto image), voice previews, UI sounds | Higgsfield generation failed (plan gate) | `#050607` + grain; waveform-only placeholder previews; no sounds |
| Official Apple / Google sign-in glyphs | Stand-ins in the handoff | Stand-ins; ship `SignInWithAppleButton` and Google's G next slice |
| Roboto (Google button label) | Spec: "Roboto Medium 17"; not bundled | Falls back to Geist on iOS/Windows (Android ships Roboto). Bundle it with Google's official button assets |
| "backups clear within [30] days" (A12d) | Bracketed in the handoff: a placeholder | Ships as **30 days**; confirm against the real backup retention before release |
| A12a App Store billing note | iOS only in the handoff | Same layout, platform wording: Google Play on Android, Microsoft Store on Windows |
| Face ID copy on other platforms | Handoff names Face ID only | Names what the device has: Touch ID, fingerprint, face unlock, Windows Hello, screen lock |
| A2b cancel | The OS sheet has its own cancel | Adds a quiet "cancel" for browser sign-in (Apple on Android, both on Windows) |
| A5, A6, A7 | In the handoff | **Not built** (out of this slice's scope). A6's default (keep this device's setup) is applied silently |
| A standalone motion/haptics spec file | Not a separate file | Taken from the keyframe cards (ease + haptic per frame) and design system § Motion |

## Text in the design files that reads like instructions

- `design/system/image-slot.js` contains a machine-facing usage block telling
  an agent to prefill image slots via a `search_stock_photos` tool. It is
  Claude Design's own scaffolding, not an instruction for this repo, and was
  ignored.

## Re-syncing

1. In an interactive `claude` session: `/design-login` (once), then
   `/design-sync` against project `057f3c25-7d60-4039-8d1e-6ceac0713cc9`.
2. Overwrite the files above, update the date here, and diff
   `Doji Design System.dc.html` against `lib/core/theme/tokens.dart`.
3. Change tokens **in Claude Design first** — never only in Flutter.
