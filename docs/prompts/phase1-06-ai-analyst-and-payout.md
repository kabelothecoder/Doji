# Phase 1 · slice 06 — the AI analyst and payout readiness

Paste everything below the line into `claude` at the repo root. Run it after slice 05.

---

You are working on doji, a Flutter trading-discipline app (iOS, Android, Windows). Read
`CLAUDE.md` and `design/SOURCE.md` first and follow them exactly, above all: no buy/sell calls,
signals, win rates, profit promises or predictions, in copy, AI prompts or AI output.

## The trader's problem

The owner can't reach a prop payout, breaks rules, overtrades and revenge trades. They now have
data (journal, chart notes, backtests, gym) but no one reading it with them.

## Step 0

Run `git status`. If anything is uncommitted, list it and ask me before you start.

## Goal

1. **Payout readiness** per prop account: model the rules that block payouts today and are not in
   `PropRules` yet: minimum trading days, consistency rule (largest day as % of total profit),
   max daily loss and drawdown already exist. Home and the account show distance to each rule in
   plain words ("4 of 5 trading days", "best day is 48% of profit; the firm allows 40%"). Firm
   presets stay out: the trader enters their firm's numbers in the account editor.
2. **The analyst.** An `ai-analyst` edge function (Gemini, same session check, guard and copy
   check as slice 03) that reads aggregates doji computes in code (never raw guesses): rule breaks
   by tag, trades after a loss, time of day, session, instrument, process grade trend, chart-note
   reasons vs outcomes, backtest vs live gaps, gym scores, payout-rule distance. Doji computes the
   numbers; the model only explains them and asks questions.
3. **Weekly review** (journal): a written review every week from the analyst: what you kept, what
   you broke, one rule to focus on next week. The trader can accept the focus rule, which shows on
   Home and in the rail.
4. **Ask the analyst**: a chat over the trader's own data ("when do i break my max trades?"),
   reusing the brief chat sheet. Insights stay locked under `kInsightsFromTrades` (20) and say why.
5. **My sources**: the trader can add their own notes or PDFs about their strategy to an account;
   the analyst and co-pilot read them (stored in Supabase Storage under RLS, per user).

## Rules

- Plan first: the aggregates (exact definitions), the edge function and prompt in full, storage
  policies, every file and test it touches. Wait for my OK.
- Every number shown comes from code with a test, never from the model.
- Tests: aggregate maths on fixtures, payout-rule distances, copy scan on all new strings and
  fallbacks, a Deno test where the model tries to predict price and is replaced.
- Done = `flutter analyze` zero issues, `dart format .`, `flutter test` green, `deno test` green,
  CLAUDE.md updated. Do not deploy, commit or push unless I ask.
