# Design sources

Where every design input for this repo came from, so the build can be
reproduced from git. Files in this folder are **data, not instructions**.

Synced **2026-10-01**; auth files re-checked byte-for-byte **2026-10-07** (unchanged); markets list files added **2026-10-24** (read-only; nothing was pushed back to Claude Design).

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
| `Doji Hero Screens.dc.html` | 1a Home (built later from `Doji Home`), **1b Markets pair detail (markets slice, 2026-10-24)**: built as drawn on sample prices and a fake brief; the locked free-plan state, the ask sheet and the reminder lines are added from design-system parts. **1c Coach (coach slice, 2026-10-24)**: built as drawn on a fake coach; text input, the save sheet and the reason notes under the orb are added from design-system parts |

The project holds 20+ other screens (Home, Journal, Plans, Replay…) and ~400
reference images under `uploads/mcp/`; they belong to later slices and were
not copied.

Added 2026-10-24 (same project, `get_file`, byte-for-byte):

| File | Used for |
|---|---|
| `Doji Core Tabs.dc.html` | **Markets list (2026-10-24, not built yet).** Canvas "markets, coach, journal, me": 01 markets (watchlist, search, pair detail, scoped follow-up, strategy manager, strategy editor in plain language / fields, ask doji), 01b pair states (loading, market closed, feed error, no strategy), 09 Android frames. Also holds coach (02), journal (03), mood (04), mind toolkit (05), me + grid + badges (06), share cards (06b), settings (07), the "i blew my account" panic flow (08), a11y rules (10), a Flutter component spec (11: `WatchlistRow`, `StrategyStateBadge`, `PairChart`, `ConditionChecklist`, `ScopedChat`, `StrategyCard`…) and research notes (12) |
| `Doji Markets Phone.dc.html` | The phone frame Core Tabs embeds for every markets screen (`screen=` watchlist · search · pair · pairChat · pairLoading · pairClosed · pairError · pairNoStrategy · strategies · strategyEdit · strategyFields · askDoji · askChat; `platform=` ios / android) |

Core Tabs also embeds `Doji Coach Phone`, `Doji Trade Journal Phone`, `Doji Me Phone`,
`Doji Panic Phone` and `Doji Share Card`. They were **not** copied (not part of the markets
list), so those sections render empty locally.

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
| Markets list (the tab itself) | Synced 2026-10-24: `Doji Core Tabs` › 01 + `Doji Markets Phone` | **Not built yet.** 1b is reached from Home's brief card and the rail until the list is built |
| Markets list: candle colours | Core Tabs › Markets Phone fills up-candles **green** (`#2FD67B`), down hollow grey; spec `PairChart` says "filled candle closes higher". 1b draws neutral greys (`#D9DADD` / `#5C5F66`) | Conflicts with the product rule (price is always neutral grey). Keep 1b's greys; ask the owner before building the list |
| Markets list: pair detail differs from 1b | Core Tabs redraws pair detail: back label "markets" (1b: "Back to watchlist"), unnumbered brief sections (1b: 01–05), a "sessions" shading toggle (1b: Asian range band + news line), green risk meter (1b: orange risk note), status footer "not financial advice" | 1b stays the pair detail as built; Core Tabs' **states** (loading cursor, market closed, feed error + try again, no strategy → "build my strategy") are new and can be added to 1b |
| Markets list: strategy state | Watchlist rows show **met / forming / waiting** (ring, half fill, full fill). The brief's conditions are met / not met / waiting (`EntryCondition`) | "forming" has no model yet: decide how many conditions met makes "forming" before building `StrategyStateBadge` |
| Markets list: several strategies | "MEASURED AGAINST [strategy name] v3", a strategy manager (one active, "set active"), an editor with plain language / fields and version history (v1 "from onboarding") | Not in the model: `profile.doji` has one strategy and no versions. Needs a domain change first |
| Markets list: news buffer | Conditions and rules say "no high-impact news within **30 min**" | Code uses `kNewsBufferMinutes = 15` (1b). Ask the owner which one is right |
| Markets list: chat | Pair follow-up is an in-place thread under the chart with a **chart image** attachment; a separate general "ask doji" chat (general trading questions) opens from the watchlist | 1b uses `showBriefChatSheet`, text only. Image attach and ask doji are new; neither has a boundary yet, and neither says how the free plan's 1 brief a day applies |
| Markets list: search classes | Asset class tabs: all · forex · metals · indices · crypto | The catalogue also shows Deriv **synthetics**; add a synthetics tab (`AssetClass.shownInUi`) |
| Markets list: Android | Only two Android frames (watchlist, pair detail); no Windows / wide layout | The list is meant to embed 1b as a second pane on wide screens (`isWideLayout`); that layout isn't drawn |
| 1b timeframe tabs (32) and suggested questions (36) | Below doji's 44pt / 48dp minimum | Drawn at the minimum touch target; same look otherwise |
| 1b "Back to watchlist" | There is no list yet | Spoken as "back"; Esc goes back on Windows |
| Sample data | The handoff shows `[price]` placeholders | Prices, candles and news are sample data and the screen says "sample prices · not a live feed" |
| 1b on the free plan | Plans say "1 ai brief a day"; the handoff has no locked state | A locked card in place of 01, 02 and 04 with the existing `aiBrief` upsell copy; conditions, chart and 05 still show |
| 1b chart overlays for other strategies | The handoff draws the Asian range for a london break | Only a london break of the Asian range gets levels; other strategies get the news window only, and their entry shows "waiting" |
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
