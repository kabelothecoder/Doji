# Slice 04 plan: chart, drawing tools, co-pilot, pre-trade check, chart notes (for owner OK)

Status 2026-11-06. Nothing built. Untracked before start: `design/ai-slice-plan.md` (left as is).

## 0. What exists and is reused

- `PairChart` (`markets/presentation/widgets/pair_chart.dart`): StatelessWidget + `_ChartPainter`,
  fixed 36 candles, no interaction. 1b and its goldens use it.
- `MarketData.candles / candlesBetween` (slice 02, routed per instrument), `Timeframe` (M5…D1),
  `TimeframeTabs` widget.
- `RiskSizing.contractsForRisk` + `rateSourceProvider` (refuses to size when unknown / stale).
- `CoachContext` (trades vs max, stricter loss limit, loss streak, today's loss) → tilt = 2 losses.
- AI server side: `_shared/ai.ts` (`handle(req, spec, deps)`: session, body, crisis, rate limit,
  Gemini, guard), `guard.ts`, `voice.ts` (`PREAMBLE`, `factLines`, `traderWords`),
  `copy_rules.json`. Dart side has **no** AI client yet (coach/brief still fakes); the only
  `functions.invoke` is `mt5_api.dart`, which the new client copies.
- Voice input: `VoiceInput` + `includesVoiceCoach(plan)` rule, same as the coach.
- Journal storage pattern: `PrefsJournalRepository` (`doji.journal.v1`, skip bad records, sync TODO).

## 1. Chart (`lib/features/chart/`)

New feature folder; 1b keeps working on the same widget.

| file | does |
|---|---|
| `domain/bar_source.dart` | `abstract interface class BarSource { Future<List<Candle>> bars(Timeframe tf, {required DateTime from, required DateTime to}); Candle? get forming; FeedSource get source; }` |
| `data/live_bar_source.dart` | `LiveBarSource(MarketData, symbol)`: `candlesBetween`, refreshed on check-again / every 60s while visible. Replay later = another `BarSource`. |
| `domain/chart_viewport.dart` | pure: `ChartViewport(startIndex, barsVisible, priceLo, priceHi, size)`, `xOf(i)`, `iOf(x)`, `yOf(p)`, `pOf(y)`, `pan(dx)`, `zoom(factor, anchorX)`, `autoFitPrice(bars)`. Clamped: 12–400 bars. |
| `presentation/doji_chart.dart` | `DojiChart` (stateful): `BarSource`, timeframe, drawings, tool, callbacks. Gestures: drag = pan, pinch / Ctrl+wheel = zoom, wheel = pan, long-press / hover = crosshair (time · price readout, neutral grey). Keyboard: ←/→ pan, +/- zoom, Esc cancel, Del delete, Ctrl+Z / Ctrl+Y undo/redo, H/R/T/P/V pick tool. Loads older bars when panned to the left edge. |
| `presentation/chart_painter.dart` | the old `_ChartPainter` moved here and driven by the viewport; adds drawings, selection handles, crosshair. Candles stay `#D9DADD` / `#5C5F66`. |

`PairChart` becomes a thin wrapper over the painter with a fixed viewport, so 1b and its goldens
don't change (no interaction on 1b). 1b gets an "open chart" button → `/markets/chart/:symbol`
(`Routes.chart`), full screen, keeps the timeframe.

## 2. Drawings (`chart/domain/drawing.dart`, freezed)

```dart
enum DrawingKind { zone, level, trendLine, position }
@freezed class ChartPoint { DateTime at; double price; }        // anchored to time+price, not pixels
@freezed class Drawing {
  String id; DrawingKind kind; List<ChartPoint> points;          // zone 2, level 1, trend 2, position 1
  PositionPlan? position;                                        // kind == position only
}
@freezed class PositionPlan { TradeDirection direction; double entry; double stop; double target; }
```

- `position_math.dart`: `rMultiple = |target-entry| / |entry-stop|`; `moneyAtRisk` =
  `account.startingSize × rules.riskPct / 100` (what the plan risks) and `size` from
  `RiskSizing.contractsForRisk` (null → "size unknown: broker figure needed", never guessed).
  Labels: "plan · 1 : 2.4 R · risk R 500 (1%) · 0.42 lots". Direction is only which side the stop
  is on; the box is grey with a green-outlined target zone and orange-outlined stop zone, each
  **with a text label** ("target", "stop"): colour never alone, and it reads as the trader's plan.
- `hit_test.dart` (pure): `hitTest(drawings, viewport, offset, tolerance: 12)` → `Hit(drawingId,
  handle?)`; handles = endpoints / box edges; body hit for move.
- `drawing_editor.dart` (pure, unit-tested): `DrawingEditor` holds `List<Drawing>` + undo/redo
  stacks (cap 50): `add`, `move(id, dTime, dPrice)`, `moveHandle`, `delete`, `undo`, `redo`.
  Keyboard nudge on the selected drawing: arrows move by one bar / one tick (`Instrument.tickSize`,
  else 0.1% of the visible range).
- Toolbar (`chart_toolbar.dart`): `DojiIconButton`s with labels + tooltips: select, zone, level,
  trend line, position, undo, redo, delete. ≥ 44/48 targets.
- **Accessible list** (`drawing_list.dart`): beside the chart when wide, a sheet ("drawings (3)")
  on phones. Row = name ("zone 1", "level 1.08420"), prices, reason, co-pilot reply; actions:
  select, edit reason, delete. Screen readers + keyboard can add a level/zone/position by typing
  prices there ("add by price" form), so the chart is never the only way in.

Storage: drawings belong to a `ChartNote` (below), so "saved per account and instrument" =
notes filtered by `accountId + symbol`; the chart loads them on open.

## 3. Co-pilot

Flow after a drawing is finished (pointer up / "add" in the form):
1. Sheet "what is this?" (`what_is_this_sheet.dart`): text field, or push-to-talk when
   `includesVoiceCoach(plan)` and dictation is available (same reason line as the coach
   otherwise). "skip" saves the drawing with no reason and no AI call.
2. On send: note saved locally first (reason kept even if the call fails), then
   `Copilot.reflect(CopilotRequest)` → reply shown under the drawing and in the list.

Boundary: `chart/domain/copilot.dart` `abstract interface class Copilot { Future<CopilotReply> reflect(CopilotRequest r); }`
- `FakeCopilot` (tests, no Supabase): keyword rules over the strategy words + facts (mentions a
  condition not met → "your rules say <condition>. was it there?"; else "what in your plan does
  this mark?"). Its replies are scanned by the copy test.
- `SupabaseCopilot`: `functions.invoke('ai-copilot')`, picked by `copilotProvider` when
  `supabaseClientProvider` is non-null (like `authRepositoryProvider`). Errors →
  `CopilotReply.fallback` (local line, below); 429 → "you've used today's co-pilot replies.
  your reason is saved."

### `ai-copilot` contract

```
POST {
  symbol: string (≤ 20), timeframe: "M5"|"M15"|"H1"|"H4"|"D1",
  drawing: { kind: "zone"|"level"|"trendLine"|"position",
             prices: number[] (≤ 4), times: string[] (ISO, ≤ 2),
             position?: { entry, stop, target, r } },          // never sent with a direction word
  reason: string (1–500),                                       // the trader's words
  strategy: { words: string (≤ 2000), conditions: [{ text (≤ 200), status: "met"|"notMet"|"waiting" }] (≤ 12) },
  facts: { session, tradesToday, maxTrades?, lossTodayPct, dailyLimitPct?, lossStreak,
           nextNewsMinutes?, rangeHigh?, rangeLow?, lastPrice? }   // capped at 4000 chars
}
200 { reply: string, kind: "question"|"rule", crisis: boolean }
401 NO_SESSION · 400 BAD_REQUEST · 429 RATE_LIMITED · 502 AI_UNAVAILABLE
```
Rate: 80 a day, 8 a minute. Crisis check on `reason` first (same `CRISIS_REPLY`).
Model JSON schema: `{reply: string, kind: enum[question, rule]}`. `finish`: `reply` through
`guarded(..., COPILOT_FALLBACK, breaksCopyRules)` **and** a second check `ratesOdds()` (regex:
`\b(\d+\s?%|likely|probab\w*|odds|chance|high[- ]quality|good setup|bad setup|will (go|hit|reach|break|reverse))\b`)
→ fallback. `COPILOT_FALLBACK` = "what in your written rules does this mark?"

Files: `supabase/functions/ai-copilot/{index.ts, spec.ts, spec_test.ts}`, add `COPILOT_FALLBACK`
+ `ratesOdds` to `_shared/guard.ts`. Not deployed.

### Prompt (spec.ts), sent after `PREAMBLE`

```
You are doji's chart co-pilot. The trader just marked their chart and said, in their own words,
what the mark is. Your job is to hold that reason up against THEIR written strategy.

Reply with exactly one short line (under 30 words), lowercase:
- If the reason matches a rule in STRATEGY WORDS or CONDITIONS that has a requirement the trader
  has not mentioned, remind them of that rule in their own terms and ask if it was there
  ("your rules take order blocks only after a london sweep. was there one?"). kind = "rule".
- If a condition is notMet or waiting, you may name it as a fact from CONDITIONS. kind = "rule".
- If FACTS show a limit reached (tradesToday ≥ maxTrades, lossTodayPct ≥ dailyLimitPct,
  lossStreak ≥ 2), say that plainly first. kind = "rule".
- Otherwise ask one reflective question about why this mark matters to their plan. kind = "question".

Never: rate the setup, say it is good or bad, give odds, percentages of success or likelihood,
say where price will go or whether it will reach the mark, or tell them to enter or exit.
If the drawing is a position, talk only about whether it follows their plan (risk, R, rules),
never whether it will work.
If the strategy words are empty, ask what rule in their plan this mark belongs to.
Return JSON: {"reply": string, "kind": "question" | "rule"}.
```
followed by `FACTS:\n${factLines(facts)}`, `DRAWING:\n${kind} on ${timeframe} at prices …`,
`STRATEGY WORDS: <<<…>>>` (fenced like `traderWords`), `CONDITIONS:\n- text: status`,
`traderWords(reason)`.

## 4. Pre-trade check (position box)

Finishing a position box opens `pre_trade_check_sheet.dart` before "what is this?":
- One row per active-account condition from `measureConditions` (met / not met / waiting, text
  label + icon; `manual` = "check on your chart" with a yes / no / unsure toggle the trader taps).
- Limits from `CoachContext`: trades today vs max, loss today vs the stricter limit, tilt
  (2 losses in a row). Hit → plain line: "you've hit your daily loss limit (2%)." + "talk to the
  coach" button (pushes `/coach`). Never blocks: "continue" always works; doji has no hook into the
  broker anyway.
- Answers saved on the note (`checklist`).

## 5. Data: `ChartNote` (`chart/domain/chart_note.dart`, freezed)

```dart
@freezed class ChartNote {
  String id; String accountId; String symbol; Timeframe timeframe;
  DateTime createdAt; DateTime updatedAt;
  Drawing drawing;
  String? reason;                       // trader's words; null = skipped
  List<CopilotTurn> copilot;            // {fromYou, text, at}
  List<ChecklistAnswer>? checklist;     // {label, status, answer?} position only
  String? tradeId;                      // linked trade
}
```
- `ChartNoteRepository` (interface) + `PrefsChartNoteRepository` (`doji.chartnotes.v1`, bad
  records skipped) with a `TODO(next-slice): Supabase sync` matching `journal_repository.dart`.
- `chartNotesProvider` (Notifier) per account + symbol; add to `invalidateAccountReaders`.
- **Linking**: on trade save, notes for the same account + symbol created in the 24 h before
  `openedAt` with no `tradeId` get the trade's id (position notes first; others too). Done in
  `JournalController.save`. shortcut: time-window linking, upgrade when trades are opened from the
  position box.
- Trade detail: new "how you got here" section: each linked note's drawing summary, reason,
  co-pilot reply, checklist. Empty → hidden.
- Sign out / delete: `clearAll` also clears `doji.chartnotes.v1`.

## 6. Copy

New strings in `chart/presentation/chart_copy.dart` (one place) so the copy test scans them all,
plus `FakeCopilot` replies, `COPILOT_FALLBACK`, the 429 / offline lines. `copy_rules_test` and a new
`chart_copy_test` run every one through `copy_rules.dart` + the odds regex.
Note the banned list has " buy " / " sell ": the position box says "long/short"? **No** — "go long"
is banned too, so the box shows "stop below entry" / "stop above entry" only.

## 7. Tests (new)

- `test/chart/viewport_test.dart`: xOf/iOf round-trip, pan clamps, zoom keeps the anchor bar.
- `test/chart/hit_test_test.dart`: each kind, handles vs body, tolerance, overlap picks top-most.
- `test/chart/drawing_editor_test.dart`: add/move/resize/delete, undo/redo, cap 50, nudge by tick.
- `test/chart/position_math_test.dart`: R, money at risk, size null when the rate is stale.
- `test/chart/chart_note_repository_test.dart`: round-trip, bad record skipped, link on trade save.
- `test/chart/copilot_flow_test.dart` (widget, `withClock(summerDay)`, FakeCopilot): draw level by
  keyboard → sheet → reason → reply shown in list → stored note; skip path; failure → fallback,
  reason kept; voice vs text per plan.
- `test/chart/pre_trade_check_test.dart`: limit hit line + coach button, continue never blocked.
- `test/chart/chart_copy_test.dart`: copy + odds scan over every string and fallback.
- `test/chart/chart_a11y_test.dart`: labelled tool buttons, targets, 200% text, list path works.
- `test/goldens/chart_golden_test.dart`: phone + windows, one per tool (zone, level, trend,
  position with labels, selection handles) + crosshair. Pinned `withClock`.
- `supabase/functions/ai-copilot/spec_test.ts`: body validation, crisis, guard + odds fallback.
- Trade detail test: notes section shown / hidden.

## 8. Existing tests this touches

- `markets_golden_test` 1b goldens: must stay identical (PairChart wrapper keeps the fixed view);
  if a pixel moves I stop and tell you before `--update-goldens`.
- `pair_detail` widget tests: new "open chart" button (extra semantics node only).
- `journal` save tests: linking adds a write to the notes repo (fakes override it).
- `auth_controller` sign-out / delete tests: expect the new key cleared.
- `accounts_controller` `invalidateAccountReaders` list test, if it counts providers.
- `test/helpers/fakes.dart`: override `copilotProvider` (FakeCopilot) and the notes repo.

## 9. Docs

- `design/SOURCE.md › Missing`: no design for the chart, tools, co-pilot sheet, pre-trade check,
  trade detail notes; built from `core/widgets/`.
- `CLAUDE.md`: new "Chart and co-pilot" section, folder map, `ai-copilot` deploy line.

## 10. Not in this slice

Replay `BarSource` (backtest/gym), more tools (fib, text), drawing sync, deploying `ai-copilot`,
the Dart clients for slice 03's coach/brief (still fakes).

## Questions

1. Position box: OK to show no direction word at all ("stop below entry") given " buy " /
   "go long" are banned?
2. Trade linking by a 24 h window before the trade (same account + symbol): OK for now?
