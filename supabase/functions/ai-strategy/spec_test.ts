import { assertEquals } from "jsr:@std/assert@1";
import { handle } from "../_shared/ai.ts";
import { post, stubDeps } from "../_shared/test_deps.ts";
import { strategySpec } from "./spec.ts";

const words = "london breakout of the asian range on m15. wait for a close back. rsi under 30. no news.";

Deno.test("ai-strategy: measurable kinds kept, everything else manual", async () => {
  const model = {
    parsed: {
      setup: "london breakout of the asian range",
      timeframe: "m15",
      entry: "close back",
      stop: null,
      target: null,
    },
    conditions: [
      { kind: "session", session: "london" },
      { kind: "range_break", closeBack: true },
      { kind: "rsi_below", text: "rsi under 30" },
      { kind: "news_buffer" },
      { kind: "session", session: "frankfurt" },
    ],
  };
  const r = await handle(post({ words, sessions: ["london"] }), strategySpec, stubDeps({ model }));
  const j = await r.json();
  assertEquals(j.parsed.timeframe, "M15");
  assertEquals(j.conditions, [
    { kind: "session", session: "london" },
    { kind: "range_break", closeBack: true },
    { kind: "manual", text: "rsi under 30" },
    { kind: "news_buffer" },
    { kind: "manual", text: "frankfurt" },
  ]);
});

Deno.test("ai-strategy: a proposal that breaks the copy rules falls back to the trader's own words", async () => {
  const d = stubDeps({
    model: {
      parsed: { setup: "a guaranteed profit setup", timeframe: "H9" },
      conditions: [{ kind: "manual", text: "buy signal on the break" }],
    },
  });
  const r = await handle(post({ words, sessions: [] }), strategySpec, d);
  const j = await r.json();
  assertEquals(j.parsed.setup, null);
  assertEquals(j.parsed.timeframe, null);
  assertEquals(j.conditions, [{ kind: "manual", text: "london breakout of the asian range on m15" }]);
  assertEquals(d.logs, ["ai-strategy|user-1|COPY_RULE"]);
});

Deno.test("ai-strategy: empty or huge words are 400", async () => {
  assertEquals((await handle(post({ words: "" }), strategySpec, stubDeps())).status, 400);
  assertEquals((await handle(post({ words: "x".repeat(2001) }), strategySpec, stubDeps())).status, 400);
});
