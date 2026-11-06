// MetaRPC MT5 REST client (https://mt5.mrpc.pro). Server-side only: the API
// key comes from the MRPC_API_KEY function secret and never leaves here.
//
// Every MetaRPC reply is HTTP 200 with either `data` or `error` (see
// MetaRPC/NodeMT5 docs/All_Guides/ERRORS.md). Proto JSON may arrive in
// camelCase or snake_case, so `pick` reads both.

const BASE = "https://mt5.mrpc.pro";

export class MrpcError extends Error {
  constructor(readonly code: string, message: string) {
    super(`${code}: ${message}`);
  }
}

// deno-lint-ignore no-explicit-any
export type Json = any;

/** The first defined field of [obj] among [names] (camelCase / snake_case). */
export function pick(obj: Json, ...names: string[]): Json {
  if (obj == null) return undefined;
  for (const n of names) if (obj[n] !== undefined) return obj[n];
  return undefined;
}

/** A protobuf Timestamp as JSON is an RFC 3339 string or {seconds, nanos}. */
export function epochMs(ts: Json): number | null {
  if (ts == null) return null;
  if (typeof ts === "string") {
    const ms = Date.parse(ts);
    return Number.isNaN(ms) ? null : ms;
  }
  if (typeof ts === "number") return ts > 1e12 ? ts : ts * 1000;
  const s = Number(pick(ts, "seconds"));
  return Number.isFinite(s) ? s * 1000 : null;
}

export async function mrpc(
  path: string,
  params: Record<string, string | number | string[]>,
  terminalId?: string,
): Promise<Json> {
  const apiKey = Deno.env.get("MRPC_API_KEY");
  if (!apiKey) throw new MrpcError("NO_API_KEY", "MRPC_API_KEY is not set on this function");
  const url = new URL(path, BASE);
  for (const [k, v] of Object.entries(params)) {
    if (Array.isArray(v)) v.forEach((x) => url.searchParams.append(k, x));
    else url.searchParams.set(k, String(v));
  }
  const headers: Record<string, string> = { APIKey: apiKey };
  if (terminalId) headers.id = terminalId;
  const res = await fetch(url, { headers, signal: AbortSignal.timeout(path === "/ConnectEx" ? 130_000 : 20_000) });
  if (!res.ok) throw new MrpcError(`HTTP_${res.status}`, await res.text().catch(() => ""));
  const body = await res.json();
  const err = pick(body, "error");
  if (err) {
    throw new MrpcError(
      String(pick(err, "errorCode", "error_code") ?? "MRPC_ERROR"),
      String(pick(err, "errorMessage", "error_message") ?? ""),
    );
  }
  return pick(body, "data") ?? {};
}

/** QUOTE_HISTORY_TIMEFRAME: the bar length in minutes. */
export const timeframeMinutes: Record<string, number> = {
  m1: 1,
  m5: 5,
  m15: 15,
  h1: 60,
  h4: 240,
  d1: 1440,
};
