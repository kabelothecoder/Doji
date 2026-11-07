// Deploy: supabase functions deploy ai-brief   Secrets: GEMINI_API_KEY (GEMINI_MODEL, AI_TRUST_CLIENT_PLAN optional)
// Needs migration 0003_ai_usage.sql. Contract in spec.ts.
import { handle } from "../_shared/ai.ts";
import { realDeps } from "../_shared/real_deps.ts";
import { briefSpec } from "./spec.ts";

const deps = realDeps();
Deno.serve((req) => handle(req, briefSpec, deps));
