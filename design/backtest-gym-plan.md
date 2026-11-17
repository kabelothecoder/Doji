# Slice 05 plan: history, backtest, replay, gym, strategy refine

Status: **built** (owner OK 2026-11-07, defaults: nullable exit rules, me tab keeps its name, 70/30 split).

Built differently from this plan:
- MT5: no function change. The `mt5` function's `bars` action already takes `from`/`to` (3,000 bars a call), so history is fetched in 2,500-bar windows.
- Replay keys: N = next bar, Space = play / pause. The arrow keys keep panning the chart (slice 04).
- Replay reuses `ChartScreen` with a `ChartKey` (symbol, replay id, timeframe) instead of a separate `ChartView`.
- Practice positions are sized from the account's risk %, so "size within risk" is kept by construction there; the size drill practises it.
- The account's max trades and daily loss limit always apply in the backtest, whether or not they are listed as conditions.

## Where it lives

The **me tab** (today `TabPlaceholderScreen`) becomes `PracticeScreen` at `/me`, titled "practice".
It has three entries: "backtest" (auto backtest and refine), "replay" (manual backtest) and
"gym" (practice and drills). Reasons: me is the only empty branch, and practice belongs to the
trader, not to a market. The tab label stays "me". Settings is unchanged.
Deep links: `/me/backtest`, `/me/backtest/compare`, `/me/replay/:symbol`, `/me/gym`,
`/me/gym/drill/:kind`. Markets 1b gets no new button in this slice.
No design file exists. `design/SOURCE.md` › Missing gets one row, and every screen is built
from `core/widgets/`.

## 1. History (`features/history/`)

- `HistoryRange { symbol, tf, from, to, candles }`.
- `HistoryRepository`: shared_preferences key `doji.history.v1.<symbol>.<tf>`. It keeps
  candles as compact lists `[t,o,h,l,c]`. One key per pair. Cap: 20k bars per key, oldest dropped.
- `HistoryService.ensure(symbol, tf, from, to)` fetches only the missing edges, through
  `MarketData.candlesBetween`, then merges and stores them. Returns the range actually covered.
- **Deriv**: `ticks_history` style candles already works. It pages back with `end` and `count` 5000.
- **MT5**: the `mt5` function's `/QuoteHistory/Bars` takes `fromTime` and `pageSize`, so history
  comes through the existing `bars` action, paged. Change: the function action accepts `from`/`to`.
  It is not deployed yet, so I write it and its Deno test.
- **Fake** (crypto, custom, tests): deterministic sample path. The UI says "sample prices · not a
  live feed" on every backtest built on it, and adds "results on sample prices are not your market."
- UI: "history: XAUUSD M15 · 2026-08-01 → 2026-11-06 · 6,420 bars" plus "fetch more".

## 2. Automatic backtest (`features/backtest/domain/`)

**Gap found:** stop and target are free text today (`ParsedStrategy.stop/target`). A backtest needs
them as rules. I add one small freezed model on `StrategyProfile`:

```dart
ExitRules { StopRule stop; double targetR; int? maxBarsOpen }
enum StopRule { rangeOpposite, brokenLevel }  // + bufferTicks
```

- Defaults: stop beyond the broken range level, 2R target, closed at the session end.
- Edited in the account editor's strategy section as "stop" and "target (R)".
- If it is missing, the backtest asks for it. It never guesses.
- This bumps `kOnboardingVersion` to 5. No migration: by the repo rule, stored data is dropped.
  **Alternative:** a nullable field with defaults, with no bump. I recommend this one; your call.

**Engine** `runBacktest(BacktestInput) -> BacktestResult`:
- Pure. The input is account rules, conditions, exit rules, candles per symbol, and a timezone.
- It walks each trading day. It builds `ConditionFacts` for that day from history:
  - session open from `TradingSession`.
  - `tradesToday` and `lossTodayPct` from the simulated trades of that day.
  - range break and close back from the same code 1b uses. `StrategyReading`'s range logic gets
    pulled into a pure `asianRange(candles, day)` both use.
  - news: `SampleNewsCalendar`, marked "sample calendar" in the result.
- Then it calls `measureConditions`. All measurable met = a setup. Entry is at the next bar's open.
- `manual` conditions are listed as "not tested, needs replay". A strategy whose entry is manual
  gives 0 automatic setups and says so.
- **Fills on hidden bars:** after entry, each bar checks stop and target.
  - **Both inside one bar: stop first.** The UI says it in words.
  - A gap past the stop fills at the bar's open, so the loss can go past -1R.
  - Unfilled at `maxBarsOpen` or at the session end: closed at that close.
  - No spread or commission. Results say "no spread or costs counted".
- Output per setup: day, symbol, session, entry, stop, target, exit, R.
- Aggregates: count, total and average R, max losing streak, max drawdown in R. Split by session
  and by instrument.
- Copy is fixed: "in this sample: 23 setups, 2026-08-01 → 2026-11-06". Under 30 setups:
  "small sample: 23 setups. this shows what happened, not what will." No hit rate shown.
  (Win rates are banned; R and counts only.)

## 3. Replay (`features/replay/`)

- `ReplayBarSource implements BarSource`. It holds the full history plus a `cursor`.
  `bars()` returns only candles `<= cursor`. **The future is never in the list given to the chart.**
  A test asserts this.
- `ReplayController`: next bar, play/pause, speed (1, 2, 4, 8 bars/s; reduce motion = step only),
  jump to the next session open.
- The chart is slice 04's `ChartScreen` body, extracted to `ChartView(source:, onPosition:)`.
  `ChartScreen` keeps using it with `LiveBarSource`, with no visual change (goldens hold).
- Co-pilot and drawings are reused as-is. Notes made in replay are tagged `replay: true` and
  never linked to journal trades.
- When a position box is placed, the fill engine (§2, the same function) runs on the hidden bars
  as the cursor advances. Result: open, stop, target or closed.
- `BacktestSession` (freezed): id, accountId, strategyVersion, symbol, tf, from/to, kind
  (`auto | replay | gym`), trades `[BacktestTrade]`, createdAt.
  Store: `doji.backtest.v1`. Sync TODO in the repo, like the journal.

## 4. Gym (`features/gym/`)

**Replay practice:**
- A random past session (seeded) for one of the account's instruments, 1 session long.
- The trader takes or skips. The engine knows where the rule-measured setups were.
- Score `GymScore` reuses `ProcessGrade.of`, mapping checks to tags:
  - took with no setup = `no setup`.
  - skipped a setup = a missed note, not a grade hit.
  - no stop = `against plan`.
  - size over risk = `oversized` (via `RiskSizing`).
  - trades past max = `overtrading`.
- Outcome R is shown but never scored.

**Daily drills** (2–5 min, 5 items, `DrillKind`):
- `spotSetup`: frozen chart, yes/no.
- `placeStop`: tap the price; the answer is the rule's stop, within a tolerance in ticks.
- `sizeTrade`: type the lots/contracts; checked by `RiskSizing` for the active account. Null
  sizing (synthetics) = "your broker's figure needed", skipped.
- `afterTwoLosses`: a scenario that shows 2 losses today, then asks "next setup appears. take it?".
  The right answer follows the account's own max trades and daily loss.

**Storage and Home:**
- Store: `doji.gym.v1` (scores and answers).
- `drillStreak` = consecutive local days with a finished drill set.
- **Home grid:** practice days get a distinct outlined-dot cell plus the label "practice" in the
  grid's semantics. They never change real trading-day fill. (`GridCellState.practice`, new. Home
  goldens change: 2 files.)

## 5. Refine the strategy (`features/backtest/presentation/compare_screen`)

- `StrategyDraft` = copy of the account's `StrategyProfile` + `ExitRules` + rules.
- One change at a time: session, stop rule, target R, a condition on/off, max trades.
  The UI disables the others until rerun, and shows the diff line ("changed: target 2R → 3R").
- Rerun on the same cached history. Side by side: setups, total R, average R, max losing streak,
  drawdown in R.
- **Prop accounts:** `PropReplay` walks each simulated day against `PropRules`. It checks the daily
  loss, and max drawdown fixed/trailing (reuses `PropDrawdown.evaluate`). It lists the days that
  would have broken a rule.
  Consistency and minimum days: not in `PropRules` today and slice 06's payout rules are not built.
  I add two optional fields to `PropRules`: `minTradingDays`, `consistencyPct` (best day ≤ x% of
  total). Shown "not set" when null.
- **Personal accounts:** judged against their own daily loss and max trades.
- Never picks a winner: no highlight, no "better". Both columns are the same colour.
- **Fit warnings:**
  - under 30 setups in either column.
  - a draft changed more than once on the same period.
  - "check it on a held-back period": the cached range splits by default 70/30 by date. The
    trader tunes on the first part and presses "check on held-back" to run both on the rest.
    The held-back period can only be revealed once per draft, then it shows "seen".
- **Adopt:**
  - The draft becomes the account's strategy.
  - The old one is kept in `TradingAccount.strategyVersions: List<StrategyVersion>`
    (n, savedAt, profile, exits).
  - The editor shows "version 3 · from backtest" and a read-only list.
  - This reverses the 2026-11-02 "no versions" decision (SOURCE.md updated).

## 6. Data for slice 06

`BacktestRepository`, `GymRepository`: shared_preferences, a record that fails to parse is
skipped, and both are cleared by sign out / delete (`clearAll`). A sync TODO matches
`journal_repository.dart`. Each has a `toAnalystJson()` summary for the AI analyst.

## Tests

- `backtest_engine_test`: hand-built candle fixtures with known answers:
  - one clean target, one clean stop.
  - stop and target in the same bar = stop.
  - a gap past the stop.
  - a time exit.
  - max trades cap.
  - daily-loss stop for the day.
  - streak and drawdown math.
  - by-session split.
  - <30 warning.
  - manual-only = 0 with "needs replay".
- `history_test`: merges edges, no duplicates, the cap, the range reported. Deriv paging uses the
  in-memory socket.
- `replay_test`: `ReplayBarSource` never returns `t > cursor` (property test over random cursors).
  Fills only resolve after the cursor passes them. Speed and pause.
- `gym_test`: scoring by process (a losing trade that kept rules = A; a winning no-setup trade = F).
  Drill answers and streak.
- `refine_test`: one-change rule, adopt keeps the old version, prop day breaches (fixed and
  trailing), held-back is revealed once.
- Copy scan: every string literal in `lib/features/{history,backtest,replay,gym}` through
  `breaksCopyRules`, plus a ban on "win rate", "best", "recommended" in compare.
- a11y: the practice, backtest, compare, drill and gym screens at 200% text, targets, labels.
  Controls are keyboard-reachable on Windows (space = play/pause, → = next bar).
- Goldens: compare (phone + Windows), drill (phone).

## Tests this breaks (expected, will fix)

- Tests and goldens that render the me tab placeholder (`shell` / nav tests looking for the
  placeholder text).
- Home goldens: only if a practice cell is drawn. Fixtures have no gym data, so none should change.
- `account_editor_test`: the new stop/target fields and versions list (positions shift).
- Chart tests: `ChartScreen` extracted to `ChartView`, so finders by type may need updating.
- `copy_rules_test`: the new directories are added to the scan.
- If you choose the version bump: tests that seed `onboardingVersion: 4`.

## Not in this slice

Spread and commission, partial exits, trailing stops in the engine, multi-timeframe strategies,
indicator conditions (owner rule), syncing, AI reading of backtests (slice 06), real news history.

## Open decisions for the owner

1. Exit rules: a nullable field with defaults and no data wipe (recommended), or a bump to v5.
2. The me tab name: keep "me" with "practice" inside (recommended), or rename it to "practice".
3. Held-back split 70/30 by default: OK?
