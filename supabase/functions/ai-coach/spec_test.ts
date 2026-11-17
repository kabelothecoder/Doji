import { assert, assertEquals } from "jsr:@std/assert@1";
import { handle } from "../_shared/ai.ts";
import { AiError } from "../_shared/gemini.ts";
import { COACH_FALLBACK, CRISIS_REPLY } from "../_shared/guard.ts";
import { post, stubDeps } from "../_shared/test_deps.ts";
import { coachSpec } from "./spec.ts";

const body = (message: string | null) => ({
  context: { name: "sam", maxTradesPerDay: 3, tradesToday: 1 },
  history: [{ speaker: "coach", text: "what's on your mind?" }],
  message,
});

Deno.test("ai-coach: no session is 401 and the model is never called", async () => {
  const d = stubDeps({ user: null });
  const r = await handle(post(body("hi")), coachSpec, d);
  assertEquals(r.status, 401);
  assertEquals(d.geminiCalls, 0);
});

Deno.test("ai-coach: bad body is 400", async () => {
  const r = await handle(post({ context: "x", message: "hi" }), coachSpec, stubDeps());
  assertEquals(r.status, 400);
});

Deno.test("ai-coach: replies with the model's words and the facts in the prompt", async () => {
  const d = stubDeps({ model: { reply: "one trade so far. what does your plan say next?" } });
  const r = await handle(post(body("feeling the urge")), coachSpec, d);
  assertEquals(await r.json(), { reply: "one trade so far. what does your plan say next?", crisis: false });
  assert(d.prompts[0].includes("tradesToday: 1"));
  assert(d.prompts[0].includes("TRADER WORDS: <<<feeling the urge>>>"));
});

Deno.test("ai-coach: a reply that breaks the copy rules is replaced and logged", async () => {
  const d = stubDeps({ model: { reply: "this looks like a good time to buy." } });
  const r = await handle(post(body("should i?")), coachSpec, d);
  assertEquals((await r.json()).reply, COACH_FALLBACK);
  assertEquals(d.logs, ["ai-coach|user-1|COPY_RULE"]);
});

Deno.test("ai-coach: crisis words get SADAG first and Gemini is never called", async () => {
  const d = stubDeps({ model: { reply: "x" } });
  const r = await handle(post(body("i want to die")), coachSpec, d);
  assertEquals(await r.json(), { reply: CRISIS_REPLY, crisis: true });
  assertEquals(d.geminiCalls, 0);
});

Deno.test("ai-coach: over the limit is 429", async () => {
  const r = await handle(post(body("hi")), coachSpec, stubDeps({ allow: false }));
  assertEquals(r.status, 429);
  assertEquals((await r.json()).code, "RATE_LIMITED");
});

Deno.test("ai-coach: a Gemini failure is 502 with only an error code logged", async () => {
  const d = stubDeps({
    model: () => {
      throw new AiError("GEMINI_HTTP_500");
    },
  });
  const r = await handle(post(body(null)), coachSpec, d);
  assertEquals(r.status, 502);
  assertEquals(d.logs, ["ai-coach|user-1|GEMINI_HTTP_500"]);
});
