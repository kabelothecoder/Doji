# Phase 1 · slice 07 — a plan for traders who trade the economy (news and fundamentals)

Paste everything below the line into `claude` at the repo root. Run it after slice 06.

---

You are working on doji, a Flutter trading-discipline app (iOS, Android, Windows). Read
`CLAUDE.md` and `design/SOURCE.md` first and follow them exactly, above all: no buy/sell calls,
signals, forecasts of a release or of price, win rates or profit promises.

## The trader's problem

Some traders trade the economy: rate decisions, CPI, NFP, GDP, central-bank speeches, their own
macro view of a currency. Today doji treats news only as something to stay away from
(`kNewsBufferMinutes` = 30). These traders need doji to hold *their* news plan instead: what they
trade, when they are allowed in, how much they risk on a volatile release, and when they stop.

## Step 0

Run `git status`. If anything is uncommitted, list it and ask me before you start.

## Goal

1. **A real calendar.** Replace `SampleNewsCalendar` with a real economic calendar behind the
   existing `NewsCalendar` boundary, fetched and cached by a Supabase edge function (read the
   provider's terms and docs first; propose 2 options with cost in the plan). Each event: time,
   currency, impact, previous, consensus, actual once out. Doji shows numbers as published,
   never its own forecast.
2. **Trading style on the account.** Onboarding and the account editor ask how the trader
   trades: technical, news / fundamentals, or both. Steps go in `onboarding_catalog.dart`.
   For news traders the news condition flips from "stay away" to the trader's own rules:
   - which events and currencies they trade (their list, not doji's),
   - entry rule in their words (e.g. "only after the first 5-minute candle closes"), as
     `manual` or measurable conditions,
   - risk for news trades (can be lower than normal), max news trades a day, spread / slippage
     note, and a stop-for-the-day rule after a news loss.
3. **The bias journal.** Before an event the trader writes their view and why (their macro
   reasons, in their words). After it, doji shows the actual vs consensus and asks them to review
   their view and their process: did they follow their news plan? Graded with
   `process_grade.dart`, never on whether the view was right.
4. **Home, 1b, coach, co-pilot**: show the next events the trader trades, the countdown, and
   their plan for it. The coach and co-pilot get the trader's news plan and bias in their context
   (same guards as slice 03).
5. **Backtest and gym** (slice 05): tag past events on the replay chart; backtest the trader's
   news plan over past releases of their chosen events; a gym drill that replays a release bar by
   bar and scores process.

## Rules

- Plan first: the calendar options and cost, data shapes, onboarding steps, every file and test
  it touches. Wait for my OK.
- Tests: calendar parsing on fixtures, the news-condition flip per trading style, bias-journal
  grading by process, copy scan on all new strings (no "will rise / will fall" anywhere).
- Done = `flutter analyze` zero issues, `dart format .`, `flutter test` green, CLAUDE.md updated.
  Do not deploy, commit or push unless I ask.
