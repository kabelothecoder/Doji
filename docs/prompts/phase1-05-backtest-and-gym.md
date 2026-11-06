# Phase 1 · slice 05 — backtesting and the gym

Paste everything below the line into `claude` at the repo root. Run it after slice 04.

---

You are working on doji, a Flutter trading-discipline app (iOS, Android, Windows). Read
`CLAUDE.md` and `design/SOURCE.md` first and follow them exactly (no buy/sell language, no win
rates or profit promises, price always neutral grey, accessibility).

## The trader's problem

The owner is unsure their strategy works, has too little data on it, and only practises with real
money. They need a safe place to test the strategy on history and to practise following it.

## Step 0

Run `git status`. If anything is uncommitted, list it and ask me before you start.

## Goal

1. **History.** Fetch and cache candles per instrument and timeframe from the slice 02 feeds
   (Deriv `ticks_history`; MetaRPC where it offers history, otherwise say so). Cache on device with
   the date range covered.
2. **Automatic backtest.** Run an account's *measurable* conditions (`measureConditions`, the
   london range break) over cached history. List every `manual` condition as "not tested, needs
   replay". Results: number of setups, R per setup with the account's stop/target rules, max
   losing streak, drawdown in R, by session and instrument. Present them as what happened in this
   sample, with its size, never as a forecast; a sample under 30 setups says so.
3. **Replay (manual backtest).** The slice 04 chart, fed bar by bar from history, with the future
   hidden: next bar, play/pause, speed, jump to session. The trader draws and places position
   boxes as in slice 04 (co-pilot included); doji fills them on the hidden bars and logs each one
   to a `BacktestSession` per account and strategy.
4. **The gym.**
   - *Replay practice*: a random past session for the trader's instruments; they take or skip
     setups by their rules and are scored on **process** (rule kept, stop placed, size within risk,
     no trades past the max), reusing `process_grade.dart`, not on profit.
   - *Daily drills* (2–5 minutes): spot your setup (yes/no on a frozen chart), place the stop,
     size the trade for the active account, and "after two losses" scenarios that rehearse the
     account's own stop-for-the-day rule. A drill streak feeds Home's grid as practice, kept
     separate from real trading days.
5. **Data.** Backtest sessions, gym scores and drill answers are stored like the journal (local,
   sync TODO) so slice 06's AI analyst can read them.

## Rules

- Where to put it: gym and backtest live in the **me** tab (today a placeholder) unless the plan
  shows a better home; say which in the plan. Build from `core/widgets/`; note the missing design
  in `design/SOURCE.md`.
- Plan first: files, data shapes, how fills are decided on hidden bars (stop vs target on the same
  bar = stop first, say so in the UI), every test it breaks. Wait for my OK.
- Tests: backtest engine on fixed candle fixtures (known answers), replay never reveals future
  bars, gym scoring by process, copy scan on all new strings, a11y.
- Done = `flutter analyze` zero issues, `dart format .`, `flutter test` green, CLAUDE.md updated.
  Do not commit or push unless I ask.
