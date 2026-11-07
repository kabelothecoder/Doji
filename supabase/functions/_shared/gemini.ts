// Gemini through the Interactions API (POST /v1beta/interactions), server-side
// only. The key is the GEMINI_API_KEY function secret and never leaves here.
// The system prompt goes at the start of `input`: the docs read on 2026-11-06
// show no system field for interactions.

import type { Json } from "./mrpc.ts";

export class AiError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

export const defaultModel = "gemini-3.8-flash";

export async function geminiJson(prompt: string, schema: Json): Promise<Json> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new AiError("NO_API_KEY");
  let res: Response;
  try {
    res = await fetch("https://generativelanguage.googleapis.com/v1beta/interactions", {
      method: "POST",
      headers: { "x-goog-api-key": key, "Content-Type": "application/json", "Api-Revision": "2026-05-20" },
      body: JSON.stringify({
        model: Deno.env.get("GEMINI_MODEL") || defaultModel,
        input: prompt,
        store: false,
        response_format: { type: "text", mime_type: "application/json", schema },
        generation_config: { thinking_level: "low" },
      }),
      signal: AbortSignal.timeout(25_000),
    });
  } catch {
    throw new AiError("GEMINI_UNREACHABLE");
  }
  if (!res.ok) throw new AiError(`GEMINI_HTTP_${res.status}`);
  return parseJson(outputText(await res.json()));
}

/** The model's text: steps[type=model_output].content[].text (REST), else outputs[].text. */
export function outputText(body: Json): string {
  const parts: string[] = [];
  for (const s of body?.steps ?? []) {
    if (s?.type === "thought") continue;
    for (const c of s?.content ?? []) if (typeof c?.text === "string") parts.push(c.text);
  }
  if (!parts.length) { for (const o of body?.outputs ?? []) if (typeof o?.text === "string") parts.push(o.text); }
  return parts.join("");
}

export function parseJson(text: string): Json {
  try {
    const v = JSON.parse(text.trim().replace(/^```(?:json)?\s*|\s*```$/g, ""));
    if (v && typeof v === "object") return v;
  } catch { /* fall through */ }
  throw new AiError("BAD_MODEL_JSON");
}
