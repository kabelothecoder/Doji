// ai-coach: the coach session (handoff 1c). One reply, guarded whole before it
// reaches the app (no stream: the guard must see every word first).
//
// POST { context: CoachContext facts, history: [{speaker: "you"|"coach", text}], message: string|null }
//   message null = the opener.
// 200  { reply, crisis }   401 NO_SESSION   400 BAD_REQUEST   429 RATE_LIMITED   502 AI_UNAVAILABLE

import { facts, guarded, type Spec, str } from "../_shared/ai.ts";
import type { Json } from "../_shared/mrpc.ts";
import { breaksCopyRules, COACH_FALLBACK } from "../_shared/guard.ts";
import { factLines, PREAMBLE, traderWords } from "../_shared/voice.ts";

type Input = { context: Record<string, unknown>; history: { speaker: string; text: string }[]; message: string | null };

export const COACH_PROMPT = `You are the coach in a live session. Reply in at most 3 short sentences (under 60 words).
If the trader is over a limit in FACTS (trades today at or over max, loss today at or over the
daily limit, a loss streak of 2 or more), say so plainly and suggest stopping for the day.
If they name a feeling (revenge, fomo, boredom, hesitation), name it back and ask what their plan
says.
Opener (no message): greet by name if known, mention one fact that matters today, ask what is on
their mind before the next trade.
Return JSON: {"reply": string}.`;

export const coachSpec: Spec<Input> = {
  fn: "ai-coach",
  perDay: 60,
  perMinute: 6,
  input(body: Json): Input {
    const history = Array.isArray(body?.history) ? body.history.slice(-20) : [];
    return {
      context: facts(body?.context),
      history: history.map((t: Json) => ({
        speaker: t?.speaker === "coach" ? "coach" : "you",
        text: str(t?.text, 600),
      })),
      message: body?.message == null ? null : str(body.message, 1000),
    };
  },
  crisisText: (i) => i.message,
  prompt: (i) =>
    [
      PREAMBLE,
      COACH_PROMPT,
      `FACTS:\n${factLines(i.context)}`,
      `HISTORY:\n${i.history.map((t) => `${t.speaker}: ${t.text}`).join("\n") || "(none)"}`,
      i.message == null ? "This is the opener: there is no message yet." : traderWords(i.message),
    ].join("\n\n"),
  schema: { type: "object", properties: { reply: { type: "string" } }, required: ["reply"] },
  finish: (m, _i, flag) => ({ reply: guarded(m?.reply, COACH_FALLBACK, breaksCopyRules, flag), crisis: false }),
};
