// ai-copilot: the chart co-pilot (slice 04). The trader marks the chart and
// says what the mark is; the reply holds that reason up against their own
// written strategy, as one short question or a reminder of their rule. It
// never rates the setup or its odds.
//
// POST { symbol, timeframe, drawing: {kind, prices[], times[], position?}, reason,
//        strategy: {words, conditions: [{text, status}]}, facts }
// 200  { reply, kind: "question"|"rule", crisis }
// 401 NO_SESSION   400 BAD_REQUEST   429 RATE_LIMITED   502 AI_UNAVAILABLE

import { facts, guarded, num, Refusal, type Spec, str } from "../_shared/ai.ts";
import type { Json } from "../_shared/mrpc.ts";
import { breaksCopyRules, COPILOT_FALLBACK, ratesOdds } from "../_shared/guard.ts";
import { factLines, PREAMBLE, traderWords } from "../_shared/voice.ts";

const KINDS = ["zone", "level", "trendLine", "position"] as const;
const TIMEFRAMES = ["M5", "M15", "H1", "H4", "D1"] as const;
const STATUSES = ["met", "notMet", "waiting"] as const;

type Input = {
  symbol: string;
  timeframe: string;
  drawing: {
    kind: string;
    prices: number[];
    times: string[];
    position: { entry: number; stop: number; target: number; r: number | null } | null;
  };
  reason: string;
  strategy: { words: string; conditions: { text: string; status: string }[] };
  facts: Record<string, unknown>;
};

export const COPILOT_PROMPT = `You are doji's chart co-pilot. The trader just marked their chart and said, in their own words,
what the mark is. Your job is to hold that reason up against THEIR written strategy.

Reply with exactly one short line (under 30 words), lowercase:
- If FACTS show a limit reached (tradesToday at or over maxTradesPerDay, lossTodayPct at or over
  dailyLossLimitPct, lossStreak of 2 or more), say that plainly first. kind = "rule".
- If the reason matches a rule in STRATEGY WORDS or CONDITIONS that has a requirement the trader
  has not mentioned, remind them of that rule in their own terms and ask if it was there
  ("your rules take order blocks only after a london sweep. was there one?"). kind = "rule".
- If a condition is notMet or waiting, you may name it as a fact from CONDITIONS. kind = "rule".
- Otherwise ask one reflective question about why this mark matters to their plan. kind = "question".

Never: rate the setup, say it is good or bad, give odds, percentages of success or likelihood,
say where price will go or whether it will reach the mark, or tell them to enter or exit.
If the drawing is a position, talk only about whether it follows their plan (risk, R, rules),
never whether it will work.
If the strategy words are empty, ask what rule in their plan this mark belongs to.
Return JSON: {"reply": string, "kind": "question" | "rule"}.`;

function oneOf<T extends string>(v: Json, list: readonly T[]): T {
  if (typeof v !== "string" || !list.includes(v as T)) throw new Refusal(400, { code: "BAD_REQUEST" });
  return v as T;
}

function numbers(v: Json, max: number): number[] {
  if (!Array.isArray(v) || v.length > max) throw new Refusal(400, { code: "BAD_REQUEST" });
  return v.map((x: Json) => {
    const n = num(x);
    if (n == null) throw new Refusal(400, { code: "BAD_REQUEST" });
    return n;
  });
}

export const copilotSpec: Spec<Input> = {
  fn: "ai-copilot",
  perDay: 80,
  perMinute: 8,
  input(body: Json): Input {
    const d = body?.drawing;
    const p = d?.position;
    const conditions = body?.strategy?.conditions ?? [];
    if (!Array.isArray(conditions) || conditions.length > 12) throw new Refusal(400, { code: "BAD_REQUEST" });
    const times = Array.isArray(d?.times) && d.times.length <= 2 ? d.times.map((t: Json) => str(t, 40)) : null;
    if (!times) throw new Refusal(400, { code: "BAD_REQUEST" });
    return {
      symbol: str(body?.symbol, 20),
      timeframe: oneOf(body?.timeframe, TIMEFRAMES),
      drawing: {
        kind: oneOf(d?.kind, KINDS),
        prices: numbers(d?.prices, 4),
        times,
        position: p == null ? null : {
          entry: num(p.entry) ?? 0,
          stop: num(p.stop) ?? 0,
          target: num(p.target) ?? 0,
          r: num(p.r),
        },
      },
      reason: str(body?.reason, 500),
      strategy: {
        words: str(body?.strategy?.words, 2000, false),
        conditions: conditions.map((c: Json) => ({ text: str(c?.text, 200), status: oneOf(c?.status, STATUSES) })),
      },
      facts: facts(body?.facts),
    };
  },
  crisisText: (i) => i.reason,
  prompt: (i) => {
    const d = i.drawing;
    const where = d.position
      ? `entry ${d.position.entry}, stop ${d.position.stop}, target ${d.position.target}, planned R ${d.position.r ?? "unknown"}`
      : `prices ${d.prices.join(", ")}`;
    return [
      PREAMBLE,
      COPILOT_PROMPT,
      `FACTS:\n${factLines(i.facts)}`,
      `DRAWING:\n${d.kind} on ${i.symbol} ${i.timeframe}, ${where}`,
      `STRATEGY WORDS: <<<${(i.strategy.words || "(none written)").replaceAll(">>>", "> > >")}>>>`,
      `CONDITIONS:\n${i.strategy.conditions.map((c) => `- ${c.text}: ${c.status}`).join("\n") || "(none)"}`,
      traderWords(i.reason),
    ].join("\n\n");
  },
  schema: {
    type: "object",
    properties: { reply: { type: "string" }, kind: { type: "string", enum: ["question", "rule"] } },
    required: ["reply", "kind"],
  },
  finish: (m, _i, flag) => {
    const reply = guarded(m?.reply, COPILOT_FALLBACK, (s) => breaksCopyRules(s) || ratesOdds(s), flag);
    return { reply, kind: m?.kind === "rule" && reply !== COPILOT_FALLBACK ? "rule" : "question", crisis: false };
  },
};
