# Phase 1 · slice 02 — live prices (Deriv + MetaRPC)

Paste everything below the line into `claude` at the repo root.

---

You are working on doji, a Flutter trading-discipline app (iOS, Android, Windows). Read
`CLAUDE.md` and `design/SOURCE.md` first and follow them exactly: no buy/sell language, price is
always neutral grey, accessibility, Riverpod 3 without codegen, freezed + build_runner, and the
"never git checkout/restore/reset/stash/clean" rule.

## Context

Phase 1 is for the owner's own daily trading on Windows and Android, across the accounts built in
slice 01 (`TradingAccount`: Deriv synthetics on MT5, a prop challenge, personal forex/metals on
MT5). Today `MarketData` has one implementation, `FakeMarketData`, and Home's balance and equity
come from the journal (`accountStateFrom`). This slice makes prices and account equity real.

## Step 0

Run `git status`. If anything is uncommitted, list it and ask me before you start.

## Goal

1. **Deriv synthetics** (`R_*`, `BOOM*`, `CRASH*`): a `DerivMarketData` over Deriv's public
   WebSocket API (`ticks`, `ticks_history` with `style: candles`). Read the current Deriv API docs
   first and use the endpoint and `app_id` they require; the app id goes in `--dart-define` /
   `assets/env/.env`, never hard-coded. Reconnect with backoff; a dropped feed shows 1b's existing
   "price feed not responding." state.
2. **MT5 via MetaRPC** (mrpc.pro) for forex, metals, indices and oil, plus the account's balance
   and equity. Read MetaRPC's API docs (`/api`, MT5 explorer) before designing anything. The
   MetaRPC API key is a secret: it lives only in a Supabase edge function (`supabase/functions/`),
   and the app calls that function with the user's Supabase session. Never put the key in the app,
   a `--dart-define`, or git. Each `TradingAccount` gets an optional broker link (terminal id,
   stored server-side; the app keeps only a reference). Edit it in the account editor.
3. **Routing**: one `MarketData` the app reads, choosing Deriv or MetaRPC per instrument; custom
   symbols and anything without a feed stay on `FakeMarketData` and keep the "sample prices · not
   a live feed" label. Real prices drop that label and say where they come from.
4. **Account state**: when an account has a broker link, Home's drawdown meter and loss % use the
   broker's balance and equity (and track their highs for trailing drawdown, per `PropDrawdown`);
   otherwise keep `accountStateFrom`. Show how old the figure is; refuse to show a stale one as
   current.
5. **Rates**: replace `PlaceholderRateSource` for sizing with live rates from the same edge
   function, cached with a timestamp; `RiskSizing` refuses to size on a stale rate.

## Rules

- Plan first: list the docs you read, the edge function(s), every file you touch and every test it
  breaks, and the secrets I must set (`supabase secrets set …`). Wait for my OK.
- If MetaRPC's docs don't give candles or trade history, say so in the plan; don't invent an API.
- Keep the `MarketData` boundary; the UI must not know which feed it reads.
- Tests use fakes for both feeds (no network in `flutter test`): reconnect, stale data, routing
  per instrument, broker equity into `PropDrawdown`. Goldens only change if a label changes.
- Done = `flutter analyze` zero issues, `dart format .`, `flutter test` green, CLAUDE.md updated
  (Markets, drawdown, and a short "Feeds" section with how to run with the keys), and the edge
  function deployable with `supabase functions deploy`. Do not deploy, commit or push unless I ask.
