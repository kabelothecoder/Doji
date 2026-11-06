// mt5: the app's only door to MetaRPC (mrpc.pro). Prices, bars, account
// balance/equity and FX rates from the trader's own MT5 account.
//
// Deploy:  supabase functions deploy mt5
// Secret:  supabase secrets set MRPC_API_KEY=<key from https://mrpc.pro/my>
// Needs:   migration 0002_broker_links.sql (table + Vault helpers).
//
// The caller must send its Supabase session (Authorization: Bearer <jwt>);
// supabase-js `functions.invoke` does that. Every row is scoped to that user.
// The app never sees the MetaRPC key, the terminal id or the stored password.
//
// POST body: { action, accountRef, ... }
//   link    { login, password, server }       -> { login, server }
//   unlink  {}                                 -> {}
//   status  {}                                 -> { linked, login?, server? }
//   account {}                                 -> { balance, equity, currency, asOf }
//   quote   { symbol }                         -> { symbol, bid, ask, at, digits?, dayOpen? }
//   bars    { symbol, tf, from, to }           -> { bars: [{ t, o, h, l, c }] }   (seconds, UTC)
//   rates   { pairs: ["USDZAR", ...] }         -> { rates: { USDZAR: { bid, ask, at } } }

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { epochMs, type Json, mrpc, MrpcError, pick, timeframeMinutes } from "../_shared/mrpc.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const reply = (body: Json, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const symbolRe = /^[A-Za-z0-9._#-]{1,32}$/;

type Link = { terminal_id: string; login: number; server: string; secret_id: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const auth = req.headers.get("Authorization") ?? "";

  // Who is calling: the user's own session, checked by Supabase Auth.
  const asUser = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const { data: who, error: whoErr } = await asUser.auth.getUser();
  if (whoErr || !who.user) return reply({ error: "sign in first" }, 401);
  const userId = who.user.id;
  const admin = createClient(url, service);

  let body: Json;
  try {
    body = await req.json();
  } catch {
    return reply({ error: "bad json" }, 400);
  }
  const action = String(body?.action ?? "");
  const accountRef = String(body?.accountRef ?? "");
  if (!accountRef || accountRef.length > 64) return reply({ error: "accountRef required" }, 400);

  try {
    switch (action) {
      case "link":
        return reply(await link(admin, userId, accountRef, body));
      case "unlink":
        await unlink(admin, userId, accountRef);
        return reply({});
      case "status": {
        const l = await loadLink(admin, userId, accountRef);
        return reply(l ? { linked: true, login: l.login, server: l.server } : { linked: false });
      }
    }

    const l = await loadLink(admin, userId, accountRef);
    if (!l) return reply({ error: "not linked", code: "NOT_LINKED" }, 404);
    const call = (path: string, params: Record<string, string | number | string[]>) =>
      withReconnect(admin, userId, accountRef, l, (id) => mrpc(path, params, id));

    switch (action) {
      case "account": {
        const d = await call("/AccountSummary", {});
        return reply({
          balance: Number(pick(d, "accountBalance", "account_balance")),
          equity: Number(pick(d, "accountEquity", "account_equity")),
          currency: String(pick(d, "accountCurrency", "account_currency") ?? ""),
          asOf: epochMs(pick(d, "serverTimeUtc", "server_time_utc")) ?? Date.now(),
        });
      }
      case "quote": {
        const symbol = String(body.symbol ?? "");
        if (!symbolRe.test(symbol)) return reply({ error: "bad symbol" }, 400);
        const t = await call("/SymbolInfoTick", { symbol });
        // Today's first M1 bar (00:00 UTC) gives "± % today" its base.
        const midnight = Math.floor(Date.now() / 86_400_000) * 86_400;
        let dayOpen: number | null = null;
        try {
          const b = await call("/QuoteHistory/Bars", { symbol, timeframe: 1440, fromTime: midnight, pageSize: 1 });
          const first = (pick(b, "bars") ?? [])[0];
          if (first) dayOpen = Number(pick(first, "open"));
        } catch (_) { /* no daily bar yet: the app shows 0% */ }
        return reply({
          symbol,
          bid: Number(pick(t, "bid")),
          ask: Number(pick(t, "ask")),
          at: Number(pick(t, "timeMscUtc", "time_msc_utc") ?? 0) || Date.now(),
          dayOpen,
        });
      }
      case "bars": {
        const symbol = String(body.symbol ?? "");
        const tf = timeframeMinutes[String(body.tf ?? "")];
        const from = Number(body.from), to = Number(body.to);
        if (!symbolRe.test(symbol) || !tf || !Number.isFinite(from) || !Number.isFinite(to) || to < from) {
          return reply({ error: "bad request" }, 400);
        }
        const out: Json[] = [];
        let token = "";
        // At most 3 pages of 1000: the app never asks for more than a few hundred bars.
        for (let page = 0; page < 3; page++) {
          const d = await call("/QuoteHistory/Bars", {
            symbol,
            timeframe: tf,
            fromTimeUtc: Math.floor(from),
            toTimeUtc: Math.floor(to),
            pageSize: 1000,
            ...(token ? { pageToken: token } : {}),
          });
          for (const b of pick(d, "bars") ?? []) {
            out.push({
              t: Number(pick(b, "timeUtc", "time_utc") ?? pick(b, "time")),
              o: Number(pick(b, "open")),
              h: Number(pick(b, "high")),
              l: Number(pick(b, "low")),
              c: Number(pick(b, "close")),
            });
          }
          token = String(pick(d, "nextPageToken", "next_page_token") ?? "");
          if (!token) break;
        }
        return reply({ bars: out });
      }
      case "rates": {
        const pairs: string[] = Array.isArray(body.pairs) ? body.pairs.slice(0, 16).map(String) : [];
        const rates: Record<string, Json> = {};
        for (const p of pairs) {
          if (!/^[A-Z]{6}$/.test(p)) continue;
          try {
            const t = await call("/SymbolInfoTick", { symbol: p });
            rates[p] = {
              bid: Number(pick(t, "bid")),
              ask: Number(pick(t, "ask")),
              at: Number(pick(t, "timeMscUtc", "time_msc_utc") ?? 0) || null,
            };
          } catch (_) { /* the broker lacks this pair: left out, the app refuses to size */ }
        }
        return reply({ rates });
      }
      default:
        return reply({ error: "unknown action" }, 400);
    }
  } catch (e) {
    if (e instanceof MrpcError) return reply({ error: e.message, code: e.code }, 502);
    console.error(e);
    return reply({ error: "mt5 call failed" }, 502);
  }
});

async function loadLink(admin: SupabaseClient, userId: string, accountRef: string): Promise<Link | null> {
  const { data, error } = await admin
    .from("broker_links")
    .select("terminal_id, login, server, secret_id")
    .eq("user_id", userId)
    .eq("account_ref", accountRef)
    .maybeSingle();
  if (error) throw error;
  return data as Link | null;
}

async function connect(login: number, password: string, server: string): Promise<string> {
  const d = await mrpc("/ConnectEx", {
    user: login,
    password,
    mtClusterName: server,
    timeoutSeconds: 120,
    expiration: 0,
  });
  const id = String(pick(d, "terminalInstanceGuid", "terminal_instance_guid") ?? "");
  if (!id) throw new MrpcError("NO_TERMINAL", "ConnectEx returned no terminal id");
  return id;
}

async function link(admin: SupabaseClient, userId: string, accountRef: string, body: Json) {
  const login = Number(body.login);
  const password = String(body.password ?? "");
  const server = String(body.server ?? "").trim();
  if (!Number.isSafeInteger(login) || login <= 0 || !password || !server || server.length > 128) {
    throw new MrpcError("BAD_REQUEST", "login, password and server are required");
  }
  // Connect first: a wrong password never gets stored.
  const terminalId = await connect(login, password, server);
  await unlink(admin, userId, accountRef);
  const { data: secretId, error: vErr } = await admin.rpc("broker_secret_create", {
    p_secret: password,
    p_name: `mt5:${userId}:${accountRef}:${crypto.randomUUID()}`,
  });
  if (vErr) throw vErr;
  const { error } = await admin.from("broker_links").insert({
    user_id: userId,
    account_ref: accountRef,
    terminal_id: terminalId,
    login,
    server,
    secret_id: secretId,
  });
  if (error) throw error;
  return { login, server };
}

async function unlink(admin: SupabaseClient, userId: string, accountRef: string) {
  const l = await loadLink(admin, userId, accountRef);
  if (!l) return;
  try {
    await mrpc("/Disconnect", {}, l.terminal_id);
  } catch (_) { /* already gone */ }
  await admin.from("broker_links").delete().eq("user_id", userId).eq("account_ref", accountRef);
  await admin.rpc("broker_secret_delete", { p_id: l.secret_id });
}

/** Runs [fn]; when the terminal is gone, reconnects once from the Vault password. */
async function withReconnect<T>(
  admin: SupabaseClient,
  userId: string,
  accountRef: string,
  l: Link,
  fn: (terminalId: string) => Promise<T>,
): Promise<T> {
  try {
    return await fn(l.terminal_id);
  } catch (e) {
    if (!(e instanceof MrpcError) || !/TERMINAL_INSTANCE_NOT_FOUND|NOT_CONNECTED/.test(e.code)) throw e;
    const { data: password, error } = await admin.rpc("broker_secret_read", { p_id: l.secret_id });
    if (error || !password) throw new MrpcError("RELINK_NEEDED", "stored password missing; link again");
    const id = await connect(l.login, password as string, l.server);
    await admin.from("broker_links").update({ terminal_id: id }).eq("user_id", userId).eq("account_ref", accountRef);
    l.terminal_id = id;
    return await fn(id);
  }
}
