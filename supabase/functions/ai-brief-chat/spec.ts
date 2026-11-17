// ai-brief-chat: "ask about this brief", scoped to that brief.
//
// POST { symbol, zone, plan, brief: {context, strategy, riskNote, conditions}, facts,
//        history: [{fromYou, text}], message }
// 200  { reply, crisis }   402 BRIEF_USED (free: only today's symbol)   401 / 400 / 429 / 502

import { facts, guarded, Refusal, type Spec, str } from "../_shared/ai.ts";
import type { Json } from "../_shared/mrpc.ts";
import { breaksCopyRules, CHAT_FALLBACK } from "../_shared/guard.ts";
import { factLines, PREAMBLE, traderWords } from "../_shared/voice.ts";
import { effectivePlan, localDay, symbolRe } from "../ai-brief/spec.ts";

type Input = {
  symbol: string;
  zone: string;
  plan: string;
  brief: Record<string, unknown>;
  facts: Record<string, unknown>;
  history: { fromYou: boolean; text: string }[];
  message: string;
};

export const CHAT_PROMPT =
  `Answer the trader's question about this brief only, from BRIEF and FACTS. At most 3 sentences.
If the question is about something not in them (another instrument, where price goes, what to
trade), say it's outside this brief and point back to their conditions.
Return JSON: {"reply": string}.`;

export const chatSpec: Spec<Input> = {
  fn: "ai-brief-chat",
  perDay: 40,
  perMinute: 6,
  input(body: Json): Input {
    const symbol = str(body?.symbol, 32);
    if (!symbolRe.test(symbol)) throw new Refusal(400, { code: "BAD_REQUEST" });
    const history = Array.isArray(body?.history) ? body.history.slice(-12) : [];
    return {
      symbol,
      zone: str(body?.zone, 64, false) || "UTC",
      plan: str(body?.plan, 16, false) || "free",
      brief: facts(body?.brief),
      facts: facts(body?.facts),
      history: history.map((t: Json) => ({ fromYou: t?.fromYou === true, text: str(t?.text, 600) })),
      message: str(body?.message, 600),
    };
  },
  crisisText: (i) => i.message,
  async before(i, userId, deps) {
    if (effectivePlan(i.plan, deps.env("AI_TRUST_CLIENT_PLAN")) !== "free") return;
    if (!(await deps.claimBrief(userId, localDay(i.zone), i.symbol))) {
      throw new Refusal(402, { code: "BRIEF_USED" });
    }
  },
  prompt: (i) =>
    [
      PREAMBLE,
      CHAT_PROMPT,
      `BRIEF:\n${factLines(i.brief)}`,
      `FACTS:\nsymbol: ${i.symbol}\n${factLines(i.facts)}`,
      `HISTORY:\n${i.history.map((t) => `${t.fromYou ? "you" : "doji"}: ${t.text}`).join("\n") || "(none)"}`,
      traderWords(i.message),
    ].join("\n\n"),
  schema: { type: "object", properties: { reply: { type: "string" } }, required: ["reply"] },
  finish: (m, _i, flag) => ({ reply: guarded(m?.reply, CHAT_FALLBACK, breaksCopyRules, flag), crisis: false }),
};
