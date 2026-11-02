# Phase 1 · slice 01 — accounts and the strategy editor

Paste everything below the line into `claude` at the repo root.

---

You are working on doji, a Flutter trading-discipline app (iOS, Android, Windows). Read
`CLAUDE.md` and `design/SOURCE.md` first and follow them exactly: the no buy/sell language rule,
accessibility, the design-sync rule, Riverpod 3 without codegen, freezed + build_runner, and the
"never git checkout/restore/reset/stash/clean" rule.

## Context

Phase 1 is for the owner's own daily trading on Windows and Android. Later slices replace the
fakes with live prices (Deriv WebSocket API for synthetics, MetaRPC for MT5) and Gemini behind
Supabase edge functions. This slice is local only: no network, no new backend.

Today `ProfileDoji` holds one strategy, one risk setup and one `PropRules`, and none of it can be
edited after onboarding. The owner trades three accounts, each with its own rules:

1. Deriv synthetics on MT5 (Volatility, Boom/Crash)
2. a prop challenge (daily loss, max drawdown fixed or trailing, profit target)
3. personal forex/metals on MT5

## Step 0 — before any edit

The working tree holds uncommitted markets-list work. Run `git status`, show me the list, and ask
me whether to commit it as its own commit before you start. Do not start until I answer.

## Goal

1. **Accounts.** A trader has 1+ `TradingAccount`s (freezed): id, name, kind (`deriv_synthetic`,
   `prop_challenge`, `personal`, `demo`), account currency, starting size, instruments, risk %
   per trade, max trades a day, daily loss limit, optional `PropRules`, and its own `Strategy`.
   One account is active at a time. Onboarding creates the first account from its answers
   (keep the onboarding script data-driven in `onboarding_catalog.dart`).
2. **Strategy as measurable rules.** A `Strategy` is plain-language text plus a list of
   structured conditions. Each condition is one of a small set of kinds doji can measure from
   data it has (session window, news buffer, trades vs max, daily loss vs limit, range break +
   close back beyond the level, which exists today in `StrategyReading`) or `manual` (doji shows
   it as "check on your chart" and never guesses). Keep the existing london-break reading working
   as one condition kind. Add no indicator kinds yet; list in your plan which ones my strategies
   would need and ask me.
3. **Editor.** A screen to add, rename, switch and delete accounts, and to edit each account's
   risk, limits, prop rules and strategy (plain language + conditions). Build it from
   design-system parts in `core/widgets/` (no design file exists for it; note that in
   `design/SOURCE.md` › Missing). Reachable from settings and from "MEASURED AGAINST" on the
   markets list. Deleting an account asks first.
4. **Everything reads the active account:** Home (loss limit, drawdown meter, trades vs max),
   the journal (trades are saved with an `accountId`; filter by account), Markets 1b conditions,
   the brief, the coach's `CoachContext`, the rail.
5. **Storage.** Bump `kOnboardingVersion` (no migration, per CLAUDE.md). Sign out and delete
   clear accounts too.

## Rules

- Plan first: list every file you will touch and every test/golden it breaks, then wait for my OK.
- Smallest complete change. Reuse existing types (`PropRules`, `PropDrawdown`, `RiskSizing`,
  `EntryCondition`, `StrategyReading`) instead of parallel copies.
- Copy is lowercase, calm, honest. No signals, no win rates, no profit promises.
- Tests: unit tests for account switching and condition evaluation, widget tests for the editor,
  extend the copy-rules test to the new copy, keep `test/core/a11y_test.dart` green. Pin dates
  with `withClock(summerDay, …)`.
- Done = `flutter analyze` zero issues, `dart format .`, `flutter test` green (update goldens only
  for intended changes and tell me which), and CLAUDE.md updated (folder structure, a short
  "Accounts and strategies" section, Not built list).
- Do not commit or push unless I ask.
