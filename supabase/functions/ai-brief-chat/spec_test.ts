import { assertEquals } from "jsr:@std/assert@1";
import { handle } from "../_shared/ai.ts";
import { CHAT_FALLBACK, CRISIS_REPLY } from "../_shared/guard.ts";
import { post, stubDeps } from "../_shared/test_deps.ts";
import { chatSpec } from "./spec.ts";

const body = (message: string, symbol = "EURUSD") => ({
  symbol,
  zone: "UTC",
  plan: "free",
  brief: { context: "london is open.", strategy: "one of three met.", riskNote: "1% a trade." },
  facts: { riskPct: 1 },
  history: [{ fromYou: true, text: "hi" }, { fromYou: false, text: "hello" }],
  message,
});

Deno.test("ai-brief-chat: answers from the brief", async () => {
  const r = await handle(
    post(body("what am i waiting for?")),
    chatSpec,
    stubDeps({ model: { reply: "the close back." } }),
  );
  assertEquals(await r.json(), { reply: "the close back.", crisis: false });
});

Deno.test("ai-brief-chat: a call is replaced by the fallback and logged", async () => {
  const d = stubDeps({ model: { reply: "price will go up, go long." } });
  const r = await handle(post(body("which way?")), chatSpec, d);
  assertEquals((await r.json()).reply, CHAT_FALLBACK);
  assertEquals(d.logs, ["ai-brief-chat|user-1|COPY_RULE"]);
});

Deno.test("ai-brief-chat: crisis first, no model call", async () => {
  const d = stubDeps({ model: { reply: "x" } });
  const r = await handle(post(body("honestly i want to end my life")), chatSpec, d);
  assertEquals(await r.json(), { reply: CRISIS_REPLY, crisis: true });
  assertEquals(d.geminiCalls, 0);
});

Deno.test("ai-brief-chat: free plan can't chat about another symbol today", async () => {
  const d = stubDeps({ model: { reply: "ok." } });
  await handle(post(body("q")), chatSpec, d);
  assertEquals((await handle(post(body("q", "GBPUSD")), chatSpec, d)).status, 402);
});

Deno.test("ai-brief-chat: missing message is 400", async () => {
  assertEquals((await handle(post(body("")), chatSpec, stubDeps())).status, 400);
});
