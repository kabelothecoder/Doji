// deno test supabase/functions/ai-copilot/spec_test.ts
import { assertEquals } from "jsr:@std/assert@1";
import { type Deps, handle } from "../_shared/ai.ts";
import type { Json } from "../_shared/mrpc.ts";
import { COPILOT_FALLBACK, CRISIS_REPLY } from "../_shared/guard.ts";
import { copilotSpec } from "./spec.ts";

const body = (over: Record<string, Json> = {}) => ({
  symbol: "EURUSD",
  timeframe: "M15",
  drawing: { kind: "zone", prices: [1.085, 1.084], times: ["2026-07-15T08:00:00Z", "2026-07-15T10:00:00Z"] },
  reason: "order block on the 15m",
  strategy: {
    words: "i take order blocks only after a london sweep.",
    conditions: [{ text: "London session is open", status: "met" }],
  },
  facts: { tradesToday: 1, maxTradesPerDay: 3 },
  ...over,
});

function deps(model: Json, calls: { gemini: number; logs: string[] } = { gemini: 0, logs: [] }): Deps {
  return {
    userId: () => Promise.resolve("u1"),
    take: () => Promise.resolve(true),
    claimBrief: () => Promise.resolve(true),
    gemini: () => {
      calls.gemini++;
      return Promise.resolve(model);
    },
    env: () => undefined,
    log: (_f, _u, code) => calls.logs.push(code),
  };
}

const post = (b: Json) => new Request("http://x", { method: "POST", body: JSON.stringify(b) });

Deno.test("a reply that keeps the rules passes through", async () => {
  const res = await handle(post(body()), copilotSpec, deps({ reply: "your rules take order blocks only after a london sweep. was there one?", kind: "rule" }));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).kind, "rule");
});

Deno.test("odds and banned words are replaced by the fallback", async () => {
  for (const reply of ["that's a high-quality setup", "70% of these work", "price will reach it", "a good place to buy now"]) {
    const calls = { gemini: 0, logs: [] as string[] };
    const res = await handle(post(body()), copilotSpec, deps({ reply, kind: "rule" }, calls));
    const out = await res.json();
    assertEquals(out.reply, COPILOT_FALLBACK);
    assertEquals(out.kind, "question");
    assertEquals(calls.logs, ["COPY_RULE"]);
  }
});

Deno.test("crisis words answer before the model", async () => {
  const calls = { gemini: 0, logs: [] as string[] };
  const res = await handle(post(body({ reason: "i want to die" })), copilotSpec, deps({}, calls));
  const out = await res.json();
  assertEquals(out.reply, CRISIS_REPLY);
  assertEquals(out.crisis, true);
  assertEquals(calls.gemini, 0);
});

Deno.test("bad bodies are refused", async () => {
  for (const b of [
    body({ timeframe: "M1" }),
    body({ reason: "" }),
    body({ reason: "x".repeat(501) }),
    body({ drawing: { kind: "fib", prices: [1], times: [] } }),
    body({ drawing: { kind: "level", prices: [1, 2, 3, 4, 5], times: [] } }),
  ]) {
    const res = await handle(post(b), copilotSpec, deps({ reply: "ok", kind: "question" }));
    assertEquals(res.status, 400);
  }
});
