# Backtesting phase 0 + 1 plan

Source: `reports/Backtesting whitespace Reddit pains.md` › roadmap. Fits the UI-first phase: everything stays
on the device, no new Supabase tables or functions; each backend hook gets `// TODO(backend):`.

Goal: doji tests the trader against their own words, and shows nothing it can't stand behind.
Phase 0 removes the complaints that sink competitors' reviews. Phase 1 ships the four "honest foundations".

## Phase 0 — trust fixes

### 0.1 Migrations instead of the version-bump wipe
- Today: stored data older than `kOnboardingVersion` (4, `onboarding/domain/profile_doji.dart`) is dropped.
- Change: `ProfileMigrator` (`onboarding/data/profile_migrations.dart`): a list of `Map → Map` steps
  keyed by version (4 → 5, …). Load = run steps up to `kOnboardingVersion`; a step that throws keeps the raw
  JSON under `doji.profile.backup.v<n>` and starts over (never silently).
- Journal, chart notes, backtests, gym, coach, reviews keep their own `*.v1` keys and are **never** cleared by a
  profile reset. Rule added to CLAUDE.md: bump a version = write a step + a test.
- Tests: fixture JSON for v4 → current; a broken step keeps the backup.

### 0.2 "written on this device" label on AI fallback
- Each `Supabase*` client already falls back to its fake on `AiFailure`. Return the source with the text:
  `AiText { String text; AiSource source }` (`model | device`) in `core/ai/`.
- UI: a tertiary line under the reply ("written on this device · doji's ai is offline") in the coach, the brief
  chat, the analyst sheet, the co-pilot, the brief (01/02/04). Without Supabase (local runs) everything is `device`,
  so the label is visible in dev too — that is intended.
- Copy scan tests pick up the new strings.

### 0.3 Visible AI allowances
- `AiAllowance` (`core/ai/ai_allowance.dart`): per feature, today's used / cap from the local count
  (co-pilot 80, free brief 1, …) and the server's 429/402 as the truth when it answers.
- Shown before use: the co-pilot sheet ("62 replies left today"), 1b's ask bar on free ("1 brief a day · used").
- `// TODO(backend):` read the remaining count from the function response headers.

### 0.4 Data source and range on every backtest
- `BacktestResult` gets `DataStamp { sourceLabel, from, to, bars, timeframe }` from `HistoryService.ensure`.
- Shown at the top of the result and on compare: "deriv ticks · 3 mar–14 nov · 18,400 bars · m5".
  Sample prices say "sample prices · not real history" and the result is marked practice-only.
- Chart: when bars come from a different feed than the account's broker link, the source label says so.

### 0.5 Cancel path
- Plans › manage: one button to `openStoreSubscriptions`, with price and renewal date stated. Store call stays
  a TODO(backend) until billing is real; the button and copy ship now.

## Phase 1 — honest foundations

### 1.1 Read-back contract
- `StrategyCondition` read state: `measurable | onYourChart | unclear` (`ConditionKind.manual` = `onYourChart`;
  new `unclear` carries the trader's phrase and one question back).
- Every parsed condition keeps `sourcePhrase` (the trader's words it came from). Fake reader: the matched keywords;
  `ai-strategy` spec: add `sourcePhrase` + `unclear` to the schema (TODO(backend): deploy).
- Proposal card shows three groups: "doji can measure", "check on your chart", "unclear — tell doji more".
  Answering an unclear one re-reads just that sentence.
- **Gate:** a backtest won't run while any condition is `unclear` ("answer 2 questions first"); onYourChart ones
  run as today ("not tested, needs replay").
- Freezed edit → build_runner. Nullable fields only: no version bump.

### 1.2 Blind replay with decisions before reveal
- Gym replay gets `blind: true`: symbol shown as "instrument a", date hidden, price axis relative (no levels that
  give the day away). Revealed on finish.
- Decision points: at each bar the trader can mark "my setup" (and place the box) or keep stepping; at the bars
  where the engine's measurable conditions fire, a prompt asks "setup or not?" + optional sure-ness 50 / 70 / 90.
  The answer is stored **before** the next bar is revealed (`ReplayDecision { barIndex, call, sure, at }` in
  `BacktestSession`).
- Grade: against the trader's own conditions (`scorePractice` extended), never the outcome. Result card:
  "spotted 6 of 8 of your setups · 2 taken that weren't your setup · when you said 90% sure you were right 7 of 9".
  Calibration is about recognising the trader's own setup only; copy passes `ratesOdds`.
- Desktop first (keys: S = setup, X = not, 1/2/3 = sure). Phone works with buttons.

### 1.3 Live drift card
- `DriftSplit.of(version, liveTrades, backtestSession)` (`analyst/domain/drift.dart`, pure):
  plan kept n of m (from `PlanKept`), backtest setups on traded days the trader skipped, trades taken the
  backtest would not have, and R of kept trades vs backtest R on the same dates.
- Shown in the account editor under the version and as an analyst card once the version has ≥ 10 live trades;
  below 30: "too few to judge, keep going".
- Words: "you didn't follow it" vs "it behaved differently" — never which to change.

### 1.4 One sample verdict everywhere
- `SampleVerdict.of(n)` (`core/domain/sample.dart`): `< 30` "too few to judge · keep going (n of 30)",
  `30–99` "early read", `100+` "fair sample". Plus an expectancy range (mean R ± 1.96·sd/√n) shown as
  "between −0.2R and +0.6R a trade in this sample" from 30 up.
- Replaces `smallSampleLine`, `kSmallSample` uses, the analyst's "small sample" notes and the journal's insight
  lock line, so every screen says the same thing.

## Order and size

| # | Slice | Size | Depends on |
|---|---|---|---|
| 1 | 0.1 migrations | M | — |
| 2 | 1.4 sample verdict | S | — |
| 3 | 0.4 data stamp | S | — |
| 4 | 0.2 fallback label + 0.3 allowances | M | — |
| 5 | 1.1 read-back | L | freezed edit |
| 6 | 1.2 blind replay | L | 1.4 |
| 7 | 1.3 drift card | M | 1.4 |
| 8 | 0.5 cancel path | S | — |

1–4 and 8 are independent; 5–7 touch separate features (accounts, replay/gym, analyst).

## Done means
- `flutter analyze` clean, `dart format .`, `flutter test` green incl. copy scans of every new string,
  a11y at 1x/2x, goldens updated only for intended changes (backtest result, gym result, proposal card).
- No new Supabase tables; every backend hook marked `// TODO(backend):`.
- CLAUDE.md updated per slice (Practice, AI functions, Accounts sections).

## Open questions for the owner
1. Blind replay: hide the instrument too, or only the date? (Hiding both is purer; hiding the date only keeps
   instrument-specific skills.)
2. Sure-ness levels: 50/70/90, or just "sure / not sure"?
3. Drift card threshold: show from 10 live trades on a version, or wait for 30?
