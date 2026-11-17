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
| `Doji Core Tabs.dc.html` | **Markets list (synced 2026-10-24, built 2026-10-25).** Canvas "markets, coach, journal, me": 01 markets (watchlist, search, pair detail, scoped follow-up, strategy manager, strategy editor in plain language / fields, ask doji), 01b pair states (loading, market closed, feed error, no strategy), 09 Android frames. Also holds coach (02), journal (03), mood (04), mind toolkit (05), me + grid + badges (06), share cards (06b), settings (07), the "i blew my account" panic flow (08), a11y rules (10), a Flutter component spec (11: `WatchlistRow`, `StrategyStateBadge`, `PairChart`, `ConditionChecklist`, `ScopedChat`, `StrategyCard`…) and research notes (12) |
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
| Markets list (the tab itself) | Synced 2026-10-24: `Doji Core Tabs` › 01 + `Doji Markets Phone` | **Built 2026-10-25** (`MarketsScreen`, `MarketSearchScreen`) on sample prices; decisions below are the owner's (2026-10-24) |
| Markets list: candle colours | Core Tabs › Markets Phone fills up-candles **green** (`#2FD67B`), down hollow grey; spec `PairChart` says "filled candle closes higher". 1b draws neutral greys (`#D9DADD` / `#5C5F66`) | **Owner: keep 1b's neutral greys** (product rule: price is never green). Not drawn on the list; 1b's chart is unchanged |
| Markets list: pair detail differs from 1b | Core Tabs redraws pair detail: back label "markets" (1b: "Back to watchlist"), unnumbered brief sections (1b: 01–05), a "sessions" shading toggle (1b: Asian range band + news line), green risk meter (1b: orange risk note), status footer "not financial advice" | **Owner: keep 1b as built and add the four states.** Built: loading (cursor lines), market closed (chart at 40% + "market closed · opens …"), feed error ("price feed not responding." + try again), no strategy yet (card in place of 01/02/04). **Not built:** the card's "build my strategy" button (no strategy editor after onboarding) and the closed brief's "last session" line (doji has no record of it) |
| Markets list: strategy state | Watchlist rows show **met / forming / waiting** (ring, half fill, full fill). The brief's conditions are met / not met / waiting (`EntryCondition`) | **Owner rule, built** (`StrategyState.of`, from the brief's conditions): met = all met; forming = at least half met, not all; waiting = fewer than half |
| Markets list: several strategies | "MEASURED AGAINST [strategy name] v3", a strategy manager (one active, "set active"), an editor with plain language / fields and version history (v1 "from onboarding") | **Owner (2026-11-02): one strategy per trading account, no versions.** "MEASURED AGAINST [setup]" now opens the active account's editor at its strategy. Core Tabs' strategy manager / editor are not followed |
| Practice: backtest, refine, replay, gym (slice 05) | No design file **synced**: the live project holds `Doji Replay & Edge Gym`, `Doji Replay Engine` and `Doji Replay Phone` (found 2026-11-11, not compared yet) | The me tab is "practice" (`PracticeScreen`, account and settings kept on it); backtest, refine (compare), replay picker and gym keep the tab bar, a replay and the drills are full screen. Built from `core/widgets/` and Home's card. The replay is slice 04's chart with its own bars and controls. Home's grid marks drill days with a dot, apart from the trading-day fill |
| Payout readiness, weekly review, ask the analyst, my sources | No design file. The journal's insights feed is a later slice in the UI-first order (CLAUDE.md) | Built from `core/widgets/` and Home's card: a PAYOUT RULES card on Home and in the account editor, a WEEKLY REVIEW card and an "ask the analyst" button in the journal (the brief chat's sheet), "my sources" in the account editor. Re-check against the insights design when it is synced |
| Strategy versions (slice 05) | Reverses the 2026-11-02 "no versions" row above | Adopting a backtest draft makes it the account's strategy and keeps the old one as a numbered `StrategyVersion`; the account editor shows "version N" and the list (read-only). Still one strategy per account |
| Accounts and the strategy editor | No design file for trading accounts (several accounts, each with its rules, prop rules and strategy) or for editing conditions | Built from design-system parts (`AuthScaffold`, `DojiTextField`, `DojiStepper`, `DojiChoiceChip`, `DojiButton`, `DojiAlert`, the onboarding `StrategyInput`). Needs a design pass in Claude Design |
| Markets list: news buffer | Conditions and rules say "no high-impact news within **30 min**" | **Owner: 30 min.** `kNewsBufferMinutes = 30` (was 15); tests, goldens and CLAUDE.md updated |
| Markets list: chat | Pair follow-up is an in-place thread under the chart with a **chart image** attachment; a separate general "ask doji" chat (general trading questions) opens from the watchlist | **Owner: later slice, not built.** The pair follow-up stays 1b's `showBriefChatSheet`, text only, no image attach; "ask doji" is hidden |
| Markets list: search classes | Asset class tabs: all · forex · metals · indices · crypto | **Owner: add synthetics. Built**: all · forex · metals · indices · crypto · synthetics. Oil has no tab (none drawn) and shows under all. Added markets are white fill + check, not the design's green (green never without a word) |
| Markets list: Android | Only two Android frames (watchlist, pair detail); no Windows / wide layout | **Owner: build it from design-system parts. Built:** wide (`isWideLayout`, ≥ 760px of content) = the list (380) beside 1b as a second pane, no back button; nothing opens until a row is picked, so the free plan's brief is never spent for the trader. Narrower windows push 1b like a phone |
| 1b timeframe tabs (32) and suggested questions (36) | Below doji's 44pt / 48dp minimum | Drawn at the minimum touch target; same look otherwise |
| 1b "Back to watchlist" | 1b is also reached from Home and the rail, not only the list | Spoken as "back"; Esc goes back on Windows. In the wide pane there is no back (the list is beside it) |
| Sample data | The handoff shows `[price]` placeholders | Prices, candles and news are sample data and the screen says "sample prices · not a live feed" |
| 1b on the free plan | Plans say "1 ai brief a day"; the handoff has no locked state | A locked card in place of 01, 02 and 04 with the existing `aiBrief` upsell copy; conditions, chart and 05 still show |
| 1b chart overlays for other strategies | The handoff draws the Asian range for a london break | Only a london break of the Asian range gets levels; other strategies get the news window only, and their entry shows "waiting" |
| A5, A6, A7 | In the handoff | **Built 2026-11-11** as drawn. A5's card shows no brand glyph (the design's "G" circle); the method name, email and "LAST USED" are there. A6's account row shows date and rank, not a line count (the account's setup has no answers to count). A7's terms / privacy links open a "published before launch" sheet until the pages exist |
| Chart, drawing tools and co-pilot (slice 04) | No design file for the full chart (`/markets/chart/:symbol`), its toolbar, the drawings list, the "what is this?" sheet, the pre-trade check or trade detail's "how you got here" | Built 2026-11-07 from `core/widgets/` (`DojiIconButton`, `DojiButton`, `DojiChoiceChip`, `DojiTextField`, `GlassSurface` sheets like the review sheet, `TerminalLine`) and 1b's neutral grey candles. Drawings are grey (white when selected); only a position's stop / target zones are orange / green, each labelled in words. 1b opens it by tapping its chart (no visible change to 1b). Needs a design pass in Claude Design |
| Coach states (synced 2026-11-17) | Doji Coach Phone draws a different 1c: a "coach" title, starter questions, a context row ("3 losses today"), a hold-to-talk bar, a transcript drawer and a voices sheet with previews | **Kept 1c's layout** (orb, transcript above it, save · push-to-talk · end) and added the states: text mode toggle (keyboard / voice icon, only when voice is possible), "pro · n min left this month", the no-minutes notice with "add minutes" (`showUpsellSheet(voice)`; the design's "switch to text" happens on its own), distress (calm card, still smaller orb), the summary after "end" (topics = the trader's own lines, one focus from what they raised), the saved line + done. Not built: starters, the context row, the voices sheet (1c's segmented picker stays), the transcript drawer (1c shows it inline) |
| Coach distress order | The design puts "take a minute with me" above the SADAG row | **SADAG first** (slice brief), then the panic flow, then "keep talking" |
| Coach history | "saved to coach → history"; no history screen is drawn | Me › coach history (`/me/coach-history`, list + transcript) from the me tab's parts |
| Mood: check-in, tracker, trends | Not in Doji Trade Journal Phone; Core Tabs › 04 embeds frames never synced | `/journal/mood` from design-system parts: feeling chips (The Open's moods + the journal's emotions), intensity slider, note; the logged list; counts per feeling (7 / 28 days, around losses) as neutral grey bars with the number in words. Needs a design pass |
| A standalone motion/haptics spec file | Not a separate file | Taken from the keyframe cards (ease + haptic per frame) and design system § Motion |

## Not synced yet (live project, listed 2026-11-11)

Sync each one into `design/handoff/` when its slice starts (CLAUDE.md › Phase: UI first), read-only.

| File | Slice | Status in the app |
|---|---|---|
| `Doji Panic Phone` | panic flow (breathe, ground, pause, talk, support, later) | synced 2026-11-17 into `handoff/`, built (`features/panic`) |
| `Doji Me Phone` | Me: profile + full grid, badges, share; mind toolkit; settings | synced 2026-11-17 (abridged; toolkit read in full with DesignSync 2026-11-17); profile, badges, share, mind toolkit built (scorecard is measured: the mindset slider, hand-counted breaks, AI recap and next week's focus are not built; books have no store link); in-tab settings not |
| `Doji Share Card` | share card, story 1080×1920 and post 1080×1080 | synced 2026-11-17, built (`/share`) |
| `Doji Coach Phone` | coach states: thinking, transcript, voices, text mode, summary, saved, voice minutes used, distress | synced 2026-11-17 into `handoff/` byte-for-byte (not abridged), built (see Missing › Coach states) |
| `Doji Trade Journal Phone` | journal states + mood (check-in, emotion tracker, trends) | synced 2026-11-17 into `handoff/` byte-for-byte (not abridged). It holds **no mood screens** (its screens: imported, review, home, trades, insights, weekly, prop, add / connect / csv / manual, empty, syncing, tooFew); mood built from design-system parts (see Missing › Mood). Insights feed, insight detail and the imported banner built 2026-11-18 (R only; "early signal" → "small sample"; see CLAUDE.md › Journal) |
| `Doji Insight Card` | insight card (full, hidden, compact) | synced 2026-11-18 into `handoff/` byte-for-byte; full + hidden built (journal insights); compact not built |
| `Doji Journal Phone`, `Doji Journal Engine`, `Doji Engine`, `Doji Engine Window` | insights / analyst | not built |
| `Doji Replay & Edge Gym`, `Doji Replay Engine`, `Doji Replay Phone` | practice (slice 05) | built without them |
| `Doji Home`, `Doji Home Phone`, `Doji Plans`, `Doji Plans Phone`, `Doji Rail`, `Doji Trade Journal` | built from (read live, never copied) | built |

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
