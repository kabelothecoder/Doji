# Phase 1 · slice 03 — the real coach, brief and strategy reader (Gemini via Supabase)

Paste everything below the line into `claude` at the repo root. Run it after slice 02.

---

You are working on doji, a Flutter trading-discipline app (iOS, Android, Windows). Read
`CLAUDE.md` and `design/SOURCE.md` first and follow them exactly, above all the product rule:
**never** buy/sell calls, "signals", win rates, profit promises, or where price will go, in UI
copy, AI prompts or AI output.

## Context

Doji's AI is an analysis helper for the trader's own rules, not a signals service. Today
`FakeCoach`, `FakeBrief` and `FakeBriefChat` are the only implementations of `Coach`,
`BriefSource` and `BriefChat`, and `mock_strategy_parser.dart` turns strategy words into rules.
The model is **Gemini**, called only from Supabase edge functions. The app never holds a model key.

## Step 0

Run `git status`. If anything is uncommitted, list it and ask me before you start.

## Goal

1. **Auth for real**: AI calls need the user's Supabase session. Implement `SupabaseAuthRepository`
   behind `AuthRepository` for email codes first (Apple/Google stay fake unless the plan shows
   they are small). Apply `supabase/migrations` only when I say so.
2. **Edge functions** (`supabase/functions/`, Deno/TypeScript): `ai-coach`, `ai-brief`,
   `ai-brief-chat`, `ai-strategy`. Each one: checks the session, rate-limits per user, builds the
   prompt server-side, calls Gemini with the key from `supabase secrets`, and returns structured
   JSON (or a stream for the coach). Read the current Gemini API docs first and pick the model
   in the plan.
3. **The prompts** (server-side, in version control): the AI gets only facts doji measured
   (`CoachContext`, the brief's `EntryCondition`s, the active account's rules, today's journal) and
   the trader's own strategy words. It explains them, asks reflective questions, and holds the
   trader to the plan. It refuses calls and predictions in doji's calm voice. Crisis words get the
   SADAG line first, decided in code before the model is called, not by the model.
4. **Output guard**: every model reply passes the same copy-rule check the tests use before it
   reaches the app; a failing reply is replaced by a safe fallback and logged. Port the check to
   the edge function and keep the Dart one.
5. **App side**: `SupabaseCoach`, `SupabaseBrief`, `SupabaseBriefChat` behind the existing
   boundaries; the fakes stay for tests and for running with no Supabase keys. Offline or error
   uses the existing error states. Free plan's one brief a day is now counted server-side too.
6. **Strategy reader**: `ai-strategy` reads the trader's own words for an account and proposes
   `StrategyCondition`s from the kinds doji can measure, marking everything else `manual`. The
   editor shows the proposal; the trader accepts, edits or rejects it. Never a fixed indicator
   menu (owner decision 2026-11-02).

## Rules

- Plan first: the edge functions, their request/response shapes, the prompts in full, the
  secrets I must set, every Dart file you touch and every test it breaks. Wait for my OK.
- No key, token or user data in logs beyond a user id and an error code.
- Tests: Dart tests with fakes (no network); Deno tests for each function with a stubbed Gemini,
  including a reply that breaks the copy rules and a crisis message. Extend `coach_domain_test`
  and `brief_test` copy scans to the new fallbacks.
- Done = `flutter analyze` zero issues, `dart format .`, `flutter test` green, `deno test` green,
  CLAUDE.md updated (Coach, Markets 1b, Accounts: the AI parts now built, how to run with Supabase).
  Do not deploy, apply migrations, commit or push unless I ask.
