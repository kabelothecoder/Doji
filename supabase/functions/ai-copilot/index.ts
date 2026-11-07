// Deploy: supabase functions deploy ai-copilot   Secrets: GEMINI_API_KEY (GEMINI_MODEL optional)
// Needs migration 0003_ai_usage.sql. Contract in spec.ts.
import { handle } from "../_shared/ai.ts";
import { realDeps } from "../_shared/real_deps.ts";
import { copilotSpec } from "./spec.ts";

const deps = realDeps();
Deno.serve((req) => handle(req, copilotSpec, deps));
