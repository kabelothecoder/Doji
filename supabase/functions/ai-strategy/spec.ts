// ai-strategy: reads the trader's own strategy words and proposes the
// conditions doji can measure. Everything else is `manual` in their words.
// Never a fixed indicator menu (owner decision 2026-11-02).
//
// POST { words (≤ 2000), sessions: ["london", ...] }
// 200  { parsed: {setup, timeframe, entry, stop, target}, conditions: [{kind, session?, closeBack?, text?}] }
// 401 / 400 / 429 / 502

import { guarded, type Spec, str } from "../_shared/ai.ts";
import type { Json } from "../_shared/mrpc.ts";
import { breaksCopyRules } from "../_shared/guard.ts";
import { PREAMBLE, traderWords } from "../_shared/voice.ts";

type Input = { words: string; sessions: string[] };

export const KINDS = ["session", "news_buffer", "trades_vs_max", "daily_loss_vs_limit", "range_break", "manual"];
export const SESSIONS = ["sydney", "tokyo", "london", "new_york"];
const TIMEFRAMES = ["M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1"];

export const STRATEGY_PROMPT = `Read the trader's strategy words and propose the conditions doji can measure.
Kinds doji measures:
- session {session: sydney|tokyo|london|new_york}: one of their sessions is open
- news_buffer: no high-impact news within 30 minutes either side
- trades_vs_max: trades today under their max
- daily_loss_vs_limit: today's loss under their daily limit
- range_break {closeBack: bool}: price leaves the asian range (tokyo open to london open);
  closeBack = also wait for a candle to close back beyond the broken level
Everything else they wrote (indicators, patterns, levels, confirmations) is kind "manual" with
"text" = that rule in their words, short. Do not invent rules they did not write. Do not turn a
manual rule into a measured kind unless it matches exactly. Keep their order.
Also fill parsed: setup, timeframe (M1..D1), entry, stop, target, in their words, null if absent.
Return JSON matching the schema.`;

export const strategySpec: Spec<Input> = {
  fn: "ai-strategy",
  perDay: 20,
  perMinute: 4,
  input: (body: Json) => ({
    words: str(body?.words, 2000),
    sessions: (Array.isArray(body?.sessions) ? body.sessions : []).filter((s: Json) => SESSIONS.includes(s)),
  }),
  prompt: (i) =>
    [PREAMBLE, STRATEGY_PROMPT, `Their sessions: ${i.sessions.join(", ") || "unknown"}`, traderWords(i.words)].join(
      "\n\n",
    ),
  schema: {
    type: "object",
    properties: {
      parsed: {
        type: "object",
        properties: {
          setup: { type: "string" },
          timeframe: { type: "string" },
          entry: { type: "string" },
          stop: { type: "string" },
          target: { type: "string" },
        },
      },
      conditions: {
        type: "array",
        items: {
          type: "object",
          properties: {
            kind: { type: "string", enum: KINDS },
            session: { type: "string" },
            closeBack: { type: "boolean" },
            text: { type: "string" },
          },
          required: ["kind"],
        },
      },
    },
    required: ["parsed", "conditions"],
  },
  finish(m, i, flag) {
    const field = (v: Json) => {
      const s = guarded(v, null, breaksCopyRules, flag);
      return s && s.length <= 160 ? s : null;
    };
    const tf = typeof m?.parsed?.timeframe === "string" ? m.parsed.timeframe.toUpperCase() : null;
    const conditions = (Array.isArray(m?.conditions) ? m.conditions : []).slice(0, 12).map((c: Json) =>
      condition(c, i.words, flag)
    ).filter((c: Json) => c != null);
    return {
      parsed: {
        setup: field(m?.parsed?.setup),
        timeframe: TIMEFRAMES.includes(tf) ? tf : null,
        entry: field(m?.parsed?.entry),
        stop: field(m?.parsed?.stop),
        target: field(m?.parsed?.target),
      },
      conditions,
    };
  },
};

/** One proposed condition, validated: an unknown kind or session becomes manual. */
export function condition(c: Json, words: string, flag: () => void): Json {
  const kind = String(c?.kind ?? "");
  const text = typeof c?.text === "string" ? c.text.trim().slice(0, 120) : "";
  switch (kind) {
    case "session":
      if (SESSIONS.includes(c?.session)) return { kind, session: c.session };
      break;
    case "news_buffer":
    case "trades_vs_max":
    case "daily_loss_vs_limit":
      return { kind };
    case "range_break":
      return { kind, closeBack: c?.closeBack === true };
  }
  const t = text || String(c?.session ?? kind).replaceAll("_", " ").trim();
  if (!t) return null;
  if (breaksCopyRules(t)) {
    flag();
    // The trader's own sentence holding it, else drop the rule.
    const own = words.split(/[.\n;]/).map((s) => s.trim()).find((s) => s && !breaksCopyRules(s));
    return own ? { kind: "manual", text: own.slice(0, 120) } : null;
  }
  return { kind: "manual", text: t };
}
