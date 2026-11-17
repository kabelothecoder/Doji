// Stub Deps for the function tests: no network, no database.
import type { Deps } from "./ai.ts";
import type { Json } from "./mrpc.ts";

export type Stub = Deps & { logs: string[]; prompts: string[]; geminiCalls: number; claimed: Map<string, string> };

export function stubDeps(opts: {
  user?: string | null;
  model?: Json | (() => Json);
  allow?: boolean;
  env?: Record<string, string>;
} = {}): Stub {
  const s: Stub = {
    logs: [],
    prompts: [],
    geminiCalls: 0,
    claimed: new Map(),
    userId: () => Promise.resolve(opts.user === undefined ? "user-1" : opts.user),
    take: () => Promise.resolve(opts.allow ?? true),
    claimBrief(userId, day, symbol) {
      const key = `${userId}:${day}`;
      if (!s.claimed.has(key)) s.claimed.set(key, symbol);
      return Promise.resolve(s.claimed.get(key) === symbol);
    },
    gemini(prompt) {
      s.geminiCalls++;
      s.prompts.push(prompt);
      const m = opts.model;
      return Promise.resolve(typeof m === "function" ? m() : m ?? {});
    },
    env: (n) => opts.env?.[n],
    log: (fn, user, code) => s.logs.push(`${fn}|${user}|${code}`),
  };
  return s;
}

export const post = (body: unknown) =>
  new Request("http://x/fn", { method: "POST", body: JSON.stringify(body), headers: { Authorization: "Bearer t" } });
