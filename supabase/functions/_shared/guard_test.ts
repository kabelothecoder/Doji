import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";
import { breaksCopyRules, CHAT_FALLBACK, COACH_FALLBACK, CRISIS_REPLY, isCrisis } from "./guard.ts";
import { AiError, outputText, parseJson } from "./gemini.ts";
import { PREAMBLE } from "./voice.ts";

Deno.test("copy rules catch calls, signals and promises, with punctuation", () => {
  for (
    const s of [
      "you should buy here.",
      "Sell, now",
      "a strong signal",
      "guaranteed",
      "easy profit",
      "70% win rate",
      "go long",
    ]
  ) {
    assert(breaksCopyRules(s), s);
  }
  for (const s of ["your london session is open.", "two of three conditions met", "buyer", "selling pressure"]) {
    assertFalse(breaksCopyRules(s), s);
  }
});

Deno.test("fallbacks and the crisis line keep the copy rules", () => {
  for (const s of [CRISIS_REPLY, COACH_FALLBACK, CHAT_FALLBACK]) assertFalse(breaksCopyRules(s), s);
});

Deno.test("crisis words match FakeCoach's", () => {
  for (const s of ["i want to die", "thinking about suicide", "I don't want to be here", "self-harm"]) {
    assert(isCrisis(s), s);
  }
  assertFalse(isCrisis("this market is killing my account"));
});

Deno.test("gemini reply text: steps, skipping thoughts, then outputs", () => {
  assertEquals(
    outputText({
      steps: [{ type: "thought", content: [{ text: "x" }] }, { type: "model_output", content: [{ text: '{"a":1}' }] }],
    }),
    '{"a":1}',
  );
  assertEquals(outputText({ outputs: [{ type: "text", text: "{}" }] }), "{}");
  assertEquals(parseJson('```json\n{"reply":"ok"}\n```'), { reply: "ok" });
  try {
    parseJson("not json");
    throw new Error("expected AiError");
  } catch (e) {
    assert(e instanceof AiError);
  }
});

Deno.test("the preamble tells the model the rules", () => {
  assert(PREAMBLE.includes("never invent") || PREAMBLE.toLowerCase().includes("never invent"));
  assert(PREAMBLE.includes("TRADER WORDS"));
});
