# Phase 1 · slice 04 — doji's own chart, drawing tools and the co-pilot

Paste everything below the line into `claude` at the repo root. Run it after slices 02 and 03.

---

You are working on doji, a Flutter trading-discipline app (iOS, Android, Windows). Read
`CLAUDE.md` and `design/SOURCE.md` first and follow them exactly, above all the product rule:
never buy/sell calls, signals, win rates, profit promises or where price will go, in copy, AI
prompts or AI output. Price is always neutral grey.

## The trader's problem

The owner analyses on TradingView and MT5, breaks their own rules, overtrades after losses, and
has no record of *why* they took a trade. They want to analyse inside doji instead. When they mark
a chart, doji should make them say why and hold the reason up against their own written strategy.

## Step 0

Run `git status`. If anything is uncommitted, list it and ask me before you start.

## Goal

1. **One chart, built in Flutter.** Grow `PairChart` (CustomPainter, neutral grey candles) into
   doji's chart: pan, pinch/scroll zoom, timeframes, crosshair, on the `MarketData` feed from
   slice 02. No third-party chart licence. The same widget is reused later by backtest replay and
   the gym, so keep the bar source behind an interface (live feed now, replay later).
2. **Drawing tools**: rectangle/zone, horizontal level, trend line, and a position box (entry,
   stop, target; shows R and the money at risk from `RiskSizing` for the active account; it
   records the trader's plan, it is never a suggestion). Select, move, resize, delete, undo.
   Keyboard on Windows, touch on Android. Drawings are saved per account and instrument.
3. **The co-pilot.** When a drawing is finished, doji asks "what is this?" (text, or voice where
   the plan allows, like the coach). The trader answers in their own words ("order block on the
   15m"). The answer is sent with the drawing, the active account's strategy words and conditions,
   and the measured facts to a new `ai-copilot` edge function (Gemini, same guard and copy check
   as slice 03). It replies with one short reflective question or a reminder of the trader's own
   rule ("your rules take order blocks only after a london sweep. was there one?"). It never
   rates the trade's odds.
4. **Pre-trade check.** Drawing a position box opens a checklist from the account's conditions
   plus today's limits (trades vs max, daily loss, tilt). If a limit is hit, say so plainly and
   offer the coach, never block the trader's own broker.
5. **Data collection.** Every drawing, its reason, the co-pilot exchange and the checklist answers
   are stored (`ChartNote`, linked to the account, instrument, timeframe and time, and to the trade
   if one is logged after it). Local first like the journal; leave a sync TODO matching
   `journal_repository.dart`. Trade detail shows the notes that led to it.

## Rules

- No design file exists: build from `core/widgets/` and note it in `design/SOURCE.md` › Missing.
- Plan first: files, the `ai-copilot` request/response and prompt in full, every test it breaks.
  Wait for my OK.
- Accessibility: every tool has a labelled button and a keyboard path; drawings are listed in an
  accessible side list (name, price levels, reason) so the chart is not the only way in.
- Tests: hit-testing and drawing edits as unit tests, the co-pilot flow with a fake, copy scan on
  every new string and fallback, goldens for the chart with each tool. Pin dates with `withClock`.
- Done = `flutter analyze` zero issues, `dart format .`, `flutter test` green, CLAUDE.md updated.
  Do not deploy, commit or push unless I ask.
