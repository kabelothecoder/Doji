// The live Deps: Supabase Auth for the session, the 0003 RPCs, Gemini.
// Only index.ts files import this, so tests never load supabase-js.

import { createClient } from "npm:@supabase/supabase-js@2";
import type { Deps } from "./ai.ts";
import { AiError, geminiJson } from "./gemini.ts";

export function realDeps(): Deps {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  return {
    async userId(req) {
      const asUser = createClient(url, anon, {
        global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
      });
      const { data, error } = await asUser.auth.getUser();
      return error ? null : data.user?.id ?? null;
    },
    async take(userId, kind, perDay, perMinute) {
      const { data, error } = await admin.rpc("ai_take", {
        p_user: userId,
        p_kind: kind,
        p_per_day: perDay,
        p_per_minute: perMinute,
      });
      if (error) throw new AiError("LIMIT_RPC");
      return data === true;
    },
    async claimBrief(userId, day, symbol) {
      const { data, error } = await admin.rpc("ai_claim_brief", { p_user: userId, p_day: day, p_symbol: symbol });
      if (error) throw new AiError("BRIEF_RPC");
      return data === true;
    },
    gemini: geminiJson,
    env: (n) => Deno.env.get(n),
    log: (fn, userId, code) => console.error(JSON.stringify({ fn, user: userId, code })),
  };
}
