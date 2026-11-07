import { assertEquals } from "jsr:@std/assert@1";
import { handle } from "../_shared/ai.ts";
import { post, stubDeps } from "../_shared/test_deps.ts";
import { briefSpec, localDay } from "./spec.ts";

const body = (symbol: string, plan = "free") => ({
  symbol,
  zone: "Africa/Johannesburg",
  plan,
  facts: { conditions: [{ text: "London session is open", status: "met" }], riskPct: 1, dayDone: false },
});

const good = {
  context: "london is open. cpi is at 14:30.",
  strategy: "your london break: one of three conditions met.",
  riskNote: "1% a trade, two trades left today.",
  followUps: ["what am i waiting for?", "when is the news?", "how much room is left?"],
};

Deno.test("ai-brief: writes the three sections and follow-ups", async () => {
  const r = await handle(post(body("EURUSD")), briefSpec, stubDeps({ model: good }));
  assertEquals(await r.json(), good);
});

Deno.test("ai-brief: a field that breaks the copy rules comes back null and is logged", async () => {
  const d = stubDeps({ model: { ...good, context: "a clear signal to sell.", followUps: ["should i buy now?"] } });
  const r = await handle(post(body("EURUSD")), briefSpec, d);
  const j = await r.json();
  assertEquals(j.context, null);
  assertEquals(j.followUps, null);
  assertEquals(j.strategy, good.strategy);
  assertEquals(d.logs, ["ai-brief|user-1|COPY_RULE"]);
});

Deno.test("ai-brief: free plan gets one symbol a day; the same symbol again is fine", async () => {
  const d = stubDeps({ model: good });
  assertEquals((await handle(post(body("EURUSD")), briefSpec, d)).status, 200);
  assertEquals((await handle(post(body("EURUSD")), briefSpec, d)).status, 200);
  const r = await handle(post(body("GBPUSD")), briefSpec, d);
  assertEquals(r.status, 402);
  assertEquals((await r.json()).code, "BRIEF_USED");
  assertEquals(d.geminiCalls, 2);
});

Deno.test("ai-brief: a paid plan is trusted only with AI_TRUST_CLIENT_PLAN", async () => {
  const trusted = stubDeps({ model: good, env: { AI_TRUST_CLIENT_PLAN: "true" } });
  await handle(post(body("EURUSD", "pro")), briefSpec, trusted);
  assertEquals((await handle(post(body("GBPUSD", "pro")), briefSpec, trusted)).status, 200);

  const untrusted = stubDeps({ model: good });
  await handle(post(body("EURUSD", "pro")), briefSpec, untrusted);
  assertEquals((await handle(post(body("GBPUSD", "pro")), briefSpec, untrusted)).status, 402);
});

Deno.test("ai-brief: bad symbol is 400", async () => {
  assertEquals((await handle(post(body("EUR USD; drop")), briefSpec, stubDeps())).status, 400);
});

Deno.test("ai-brief: the day is the trader's local day", () => {
  const lateUtc = new Date("2026-11-06T23:30:00Z");
  assertEquals(localDay("Africa/Johannesburg", lateUtc), "2026-11-07");
  assertEquals(localDay("Not/AZone", lateUtc), "2026-11-06");
});
