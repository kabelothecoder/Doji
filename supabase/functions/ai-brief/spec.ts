// ai-brief: writes 01 (market context), 02 (what your strategy says), 04 (risk
// note) and the follow-up questions of handoff 1b's brief. The conditions,
// levels and check-again are measured on the device and only explained here.
//
// POST { symbol, zone (IANA), plan, facts: {...measured} }
// 200  { context, strategy, riskNote, followUps }   any field null = the app keeps its own text
// 402  { code: "BRIEF_USED" }   free plan: today's brief went to another symbol
// 401 / 400 / 429 / 502 as every AI function.

import { facts, guarded, Refusal, type Spec, str } from "../_shared/ai.ts";
import type { Json } from "../_shared/mrpc.ts";
import { breaksCopyRules } from "../_shared/guard.ts";
import { factLines, PREAMBLE } from "../_shared/voice.ts";

type Input = { symbol: string; zone: string; plan: string; facts: Record<string, unknown> };

export const symbolRe = /^[A-Za-z0-9._#-]{1,32}$/;

export const BRIEF_PROMPT = `Write three sections of today's brief for the instrument in FACTS, from FACTS only.
- context (01, market context): the session that is open, the next news and its time if any,
  whether the market is open. No price direction. 1-2 sentences.
- strategy (02, what your strategy says): restate the trader's strategy in their own terms and
  which of their conditions are met, not met or waiting, using the condition texts as given.
  If there is no strategy, say doji has none to measure against yet. 2-3 sentences.
- riskNote (04): their risk per trade, trades left today, room left before the daily limit.
  If dayDone is true, say the plan is done for today. 1-2 sentences.
- followUps: three short questions the trader might ask about this brief (under 8 words each).
Return JSON matching the schema.`;

/** The trader's local date (YYYY-MM-DD) in [zone]; UTC when the zone is unknown. */
export function localDay(zone: string, now = new Date()): string {
  try {
    return new Intl.DateTimeFormat("en-CA", { timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit" })
      .format(now);
  } catch {
    return now.toISOString().slice(0, 10);
  }
}

/** Phase 1 trusts the plan the app sends (AI_TRUST_CLIENT_PLAN=true); otherwise everyone is free. */
export const effectivePlan = (sent: string, trust: string | undefined) => (trust === "true" ? sent : "free");

export const briefSpec: Spec<Input> = {
  fn: "ai-brief",
  perDay: 30,
  perMinute: 6,
  input(body: Json): Input {
    const symbol = str(body?.symbol, 32);
    if (!symbolRe.test(symbol)) throw new Refusal(400, { code: "BAD_REQUEST" });
    return {
      symbol,
      zone: str(body?.zone, 64, false) || "UTC",
      plan: str(body?.plan, 16, false) || "free",
      facts: facts(body?.facts),
    };
  },
  async before(i, userId, deps) {
    if (effectivePlan(i.plan, deps.env("AI_TRUST_CLIENT_PLAN")) !== "free") return;
    if (!(await deps.claimBrief(userId, localDay(i.zone), i.symbol))) {
      throw new Refusal(402, { code: "BRIEF_USED" });
    }
  },
  prompt: (i) => [PREAMBLE, BRIEF_PROMPT, `FACTS:\nsymbol: ${i.symbol}\n${factLines(i.facts)}`].join("\n\n"),
  schema: {
    type: "object",
    properties: {
      context: { type: "string" },
      strategy: { type: "string" },
      riskNote: { type: "string" },
      followUps: { type: "array", items: { type: "string" } },
    },
    required: ["context", "strategy", "riskNote", "followUps"],
  },
  finish(m, _i, flag) {
    const ups = (Array.isArray(m?.followUps) ? m.followUps : [])
      .map((q: Json) => guarded(q, null, breaksCopyRules, flag))
      .filter((q: string | null): q is string => q != null && q.length <= 80)
      .slice(0, 3);
    return {
      context: guarded(m?.context, null, breaksCopyRules, flag),
      strategy: guarded(m?.strategy, null, breaksCopyRules, flag),
      riskNote: guarded(m?.riskNote, null, breaksCopyRules, flag),
      followUps: ups.length ? ups : null,
    };
  },
};
