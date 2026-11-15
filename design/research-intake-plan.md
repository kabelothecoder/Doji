# Research intake plan (2026-11-15)

What outside material (YouTube transcripts, one book) suggests for doji, checked against what is
already built. Nothing here is built yet. Every idea keeps the product rules: no calls, no win rates,
no profit promises, measured facts only, strategies stay personal.

## Sources

| # | Source | Topic |
|---|---|---|
| S1 | YouTube, Mark (Falcon) | hybrid trading: strategy must fit your life, not your personality |
| S2 | Book, Aziz & Baehr, *Mastering Trading Psychology* (Bear Bull Traders, 2020) | resilience, hazards, process, walk-away rules, lifestyle |
| S3 | YouTube, Trading Fanatic | how to backtest, 10 data points, forward testing |
| S4 | YouTube, Forex Tester 5 sponsor video | backtest process, confidence from reps |
| S5 | YouTube, Brad (Market Mechanics) | small accounts blowing up; 5 rules; sells Edgeflow (competitor) |

## Shortlist (proposed slices, in order)

### 1. Availability profile + fit check (S1) — step, profile field and editor fit line built 2026-11-15

- **Onboarding step** (catalog only, `onboarding_catalog.dart`): chart access during work hours and
  after: `not_flexible | semi_flexible | fully_flexible` (semi = 2–3 short checks a day). Stored on
  the profile (one person, not per account).
- **Fit check**: compare the active account's sessions / strategy timeframe with availability. Shown
  in the account editor and as a line in the brief: "you're not flexible during london; set entries as
  limit orders or use h4/daily." Measured, never a verdict on the strategy.
- **Re-check every 90 days** or when availability changes ("does this strategy still fit your week?").
- **Strategy-hopping guard**: several `StrategyVersion`s or account strategies adopted in a short
  window → "3 changes in 6 weeks; each version has too few trades to judge." Analyst + coach fact.
- Later: evening "orders for tomorrow" plan on close-your-day (entry, stop, target R) for busy traders.

### 2. Rules slice: walk-away rules + guardrail flags (S2, S5)

New optional `TradingRules` fields, measured from the journal, shown on Home, the rail meters, the
analyst and `PayoutReadiness`-style lines:

- **Daily gain cap**: stop after +X% today.
- **Give-back stop**: stop after giving back X% of today's peak.
- **One-and-done**: stop after the first trade that reaches its target.
- **No-trade windows** inside a session (e.g. not before 09:35, not after 11:30).

Guardrail flags on journal save (feed the process grade):

- **No stop recorded.**
- **Risk above plan**: `riskMoney` larger than the account's risk %.
- **Opened in the news window** (`kNewsBufferMinutes`).

All nullable → no `kOnboardingVersion` bump.

### 3. Backtest from replay + room-to-run + streak context (S3, S4)

- **Replay sample**: pool every replay `BacktestSession` for an account + strategy version into the
  same stats view the engine uses. Fixes today's hole: strategies without `rangeBreak` get no
  automatic setups, so they have no backtest at all.
- **Room the trade had (MFE)**: per backtest / replay trade, the furthest R reached before exit. Stats:
  "target 2R; median room 3.1R." Refine may offer the target change as one draft change.
- **Usual stop**: median stop size from backtest + journal; pre-trade check flags "stop is 2.3× your
  usual" (fact, never a block).
- **Streak in context**: on a live losing streak, coach and Home say "4 in a row; your backtest had
  a run of 7."
- **More breakdowns**: by weekday, hour, most trades in a day, most losses in a day, all with the
  small-sample tag. Reuse the journal's weekday filter and the analyst's `byHour`.
- **Own tags on replay trades** (trader's words, e.g. "asian high taken") → stats split by tag. No
  fixed indicator list.
- **Small-live step**: suggest a small live account at tiny risk between backtest and full size.

### 4. Coach states: hot streak + after a blow-up (S2, S5)

Fits the planned UI-first coach slice.

- **Hot-streak check**: fast equity jump → calm line: "big run. your risk per trade is still 1%."
  A win does not raise the next trade's risk.
- **After a blown account / limit breach**: guided reflection (risk, plan, emotion), saved to the
  journal, then offers the gym. Suggest N practice days before live again (suggestion, never a lock).
- **Learning account** flag on small personal accounts: judged by process grade, never balance.

### 5. Smaller items (no slice yet)

- Review sheet questions: "would I take this trade again?" and, for an open trade, "if I had no
  position, would I want it?" (S2)
- **Body check-in** at the open: sleep hours, caffeine, exercise → analyst compares rule breaks on short
  sleep vs the rest. Belongs with the mood check-in slice. No medical or diet advice. (S2)
- **Playbook**: pin your own grade-A trades as examples of each setup (chart notes already hold the
  data). (S2)
- **Plan for both ways** in the pre-trade check: one line "if it goes against me, I…" saved in the
  chart note. (S2)

## AI knowledge (coach, analyst, co-pilot prompts)

For `_shared/voice.ts` and each `spec.ts` when backend work resumes. Every line passes the copy rules.

- Rule breaks inside a narrow session window: ask whether the window fits the trader's day before
  blaming discipline. (S1)
- All-or-nothing effort leads to burnout and strategy hopping; one timeframe at a time. (S1)
- Losing in an unsuited market phase is not proof the edge is broken; check the backtest by period
  before rewriting. (S1)
- Hazards to name calmly: averaging down, letting a small loss grow, revenge trading, overconfidence
  after wins. (S2, S5)
- Reframes: the last trade has no bearing on the next; you are not your last trade; get out of the
  mistake, don't trade out of it. (S2)
- Ask the trader's own reason for trading (away from pain / toward a goal); store it and reflect it
  back in tilt moments. (S2)
- Ask about sleep when rules break; never give medical or diet advice. (S2)
- Strategy hopping usually means too short a test: "how many trades has this version had?" (S3)
- A practice-vs-live gap points at execution or psychology, not the edge. (S3, S4)
- A loss only teaches when it is reviewed; nudge to the review sheet after losses. (S5)
- Greed and fear show up as broken rules: name the emotion, then point at the rule. (S5)
- A small account is tuition, not a lottery ticket. (S5)

## Rejected (and why)

| Idea | Source | Why |
|---|---|---|
| "20–30% a year", payout records, "$500 → $9,000", "set for life" | S1, S5 | outcome / profit claims |
| Win rate goals, "40% win rate", "68% return" | S2, S3 | win rates are banned |
| "After 5 wins expect a loss" | S3 | gambler's fallacy; contradicts S2 |
| "Skip Thursdays because I lost there" as advice | S3 | overfitting a small sample; show the split, never recommend |
| "Lost in backtest → bin the strategy" | S3 | verdict; doji says "in this sample" |
| Market-regime detection | S1 | borders on calls; revisit only if measurable and neutral |
| "Follow the banks", structural flips, float filters, HH/LL entries | S1, S2 | strategy content; strategies are personal |
| "Background position hedges your losses" | S1 | unsupported claim |
| Diet chapter (plant-based, processed meat) | S2 | medical opinion, out of scope |
| Course, platform and affiliate pitches (Falcon, FX Replay, Forex Tester, Notion, Edgeflow) | all | promotion |

## Competitor note

Edgeflow (S5): forex "trading super app" with plan, journal and guardrails against blowing accounts.
Overlaps doji's core. Doji's difference: rules measured on the trader's own words, practice (gym),
prop payout tracking, coach.

## Phase fit

UI-first phase (CLAUDE.md): slices 1, 2, 4 and the smaller items are UI + device data and fit now.
Slice 3 is device-side too (replay, history are local). AI prompt changes wait for backend work.
