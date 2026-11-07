// The one request path every AI function shares: session, body, crisis check,
// rate limit, prompt, Gemini, copy guard, reply. Each function gives a Spec;
// tests give stub Deps (no network, no database).

import type { Json } from "./mrpc.ts";
import { AiError } from "./gemini.ts";
import { CRISIS_REPLY, isCrisis } from "./guard.ts";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export const reply = (body: Json, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

/** An answer that is not the model's: a bad body, a limit, the free brief used. */
export class Refusal extends Error {
  constructor(readonly status: number, readonly body: Json) {
    super(String(body?.code ?? status));
  }
}

export type Deps = {
  /** The caller's user id from their session, else null. */
  userId(req: Request): Promise<string | null>;
  /** Counts one more call of [kind]; false when over a limit. */
  take(userId: string, kind: string, perDay: number, perMinute: number): Promise<boolean>;
  /** Free plan's brief: true when [symbol] is (or now becomes) today's one. */
  claimBrief(userId: string, day: string, symbol: string): Promise<boolean>;
  gemini(prompt: string, schema: Json): Promise<Json>;
  env(name: string): string | undefined;
  /** Only the function, the user id and an error code: never text, prompts or keys. */
  log(fn: string, userId: string, code: string): void;
};

export type Spec<I> = {
  fn: string;
  perDay: number;
  perMinute: number;
  /** Validates the body; throws Refusal(400) when it is wrong. */
  input(body: Json): I;
  /** Words to check for crisis before anything else (coach and chat). */
  crisisText?(input: I): string | null;
  /** Checks before the model (the free brief). */
  before?(input: I, userId: string, deps: Deps): Promise<void>;
  prompt(input: I): string;
  schema: Json;
  /** Model JSON to reply body, every string through the guard; [flag] marks a failure. */
  finish(model: Json, input: I, flag: () => void): Json;
};

export async function handle<I>(req: Request, spec: Spec<I>, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "method not allowed" }, 405);
  const userId = await deps.userId(req).catch(() => null);
  if (!userId) return reply({ error: "sign in first", code: "NO_SESSION" }, 401);
  try {
    let body: Json;
    try {
      body = await req.json();
    } catch {
      throw new Refusal(400, { code: "BAD_REQUEST" });
    }
    const input = spec.input(body);
    const words = spec.crisisText?.(input);
    if (words && isCrisis(words)) return reply({ reply: CRISIS_REPLY, crisis: true });
    await spec.before?.(input, userId, deps);
    if (!(await deps.take(userId, spec.fn, spec.perDay, spec.perMinute))) {
      throw new Refusal(429, { code: "RATE_LIMITED" });
    }
    const model = await deps.gemini(spec.prompt(input), spec.schema);
    let flagged = false;
    const out = spec.finish(model, input, () => (flagged = true));
    if (flagged) deps.log(spec.fn, userId, "COPY_RULE");
    return reply(out);
  } catch (e) {
    if (e instanceof Refusal) return reply(e.body, e.status);
    const code = e instanceof AiError ? e.code : "INTERNAL";
    deps.log(spec.fn, userId, code);
    return reply({ code: "AI_UNAVAILABLE" }, 502);
  }
}

// ---- input helpers ----

export function str(v: Json, max: number, required = true): string {
  if (v == null || v === "") {
    if (required) throw new Refusal(400, { code: "BAD_REQUEST" });
    return "";
  }
  if (typeof v !== "string" || v.length > max) throw new Refusal(400, { code: "BAD_REQUEST" });
  return v;
}

export const num = (v: Json): number | null => (typeof v === "number" && Number.isFinite(v) ? v : null);

/** Plain JSON facts from the app, capped so a body can't grow the prompt without limit. */
export function facts(v: Json, maxChars = 4000): Record<string, unknown> {
  if (v == null || typeof v !== "object" || Array.isArray(v)) throw new Refusal(400, { code: "BAD_REQUEST" });
  if (JSON.stringify(v).length > maxChars) throw new Refusal(400, { code: "BAD_REQUEST" });
  return v;
}

/** A model string field through [check]: [fallback] when missing or failing. */
export function guarded(v: Json, fallback: string | null, check: (s: string) => boolean, flag: () => void) {
  if (typeof v !== "string" || !v.trim()) return fallback;
  if (check(v)) {
    flag();
    return fallback;
  }
  return v.trim();
}
