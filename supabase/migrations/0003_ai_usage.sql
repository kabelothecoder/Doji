-- 0003_ai_usage: rate limits for the AI functions and the free plan's one
-- brief a day, counted on the server.
--
-- NOT APPLIED to any project. Apply it yourself (supabase db push).
-- Only the edge functions (service role) touch these; RLS is on with no
-- policies, so the app's anon/authenticated roles see nothing.

create table if not exists public.ai_usage (
  user_id uuid        not null references auth.users (id) on delete cascade,
  kind    text        not null,
  minute  timestamptz not null,
  count   integer     not null default 0,
  primary key (user_id, kind, minute)
);

alter table public.ai_usage enable row level security;

-- One more call of p_kind for p_user, if under both limits. Atomic per row.
create or replace function public.ai_take(p_user uuid, p_kind text, p_per_day integer, p_per_minute integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_minute timestamptz := date_trunc('minute', now());
  v_day    integer;
  v_now    integer;
begin
  -- Serialise this user's calls of this kind so two requests can't both pass.
  perform pg_advisory_xact_lock(hashtext(p_user::text || ':' || p_kind));

  select coalesce(sum(count), 0) into v_day
    from public.ai_usage
   where user_id = p_user and kind = p_kind and minute > now() - interval '1 day';
  select coalesce(sum(count), 0) into v_now
    from public.ai_usage
   where user_id = p_user and kind = p_kind and minute = v_minute;
  if v_day >= p_per_day or v_now >= p_per_minute then
    return false;
  end if;

  insert into public.ai_usage (user_id, kind, minute, count)
  values (p_user, p_kind, v_minute, 1)
  on conflict (user_id, kind, minute) do update set count = public.ai_usage.count + 1;

  delete from public.ai_usage where user_id = p_user and minute < now() - interval '2 days';
  return true;
end;
$$;

-- The free plan's brief: the first symbol each (trader-local) day.
create table if not exists public.brief_days (
  user_id uuid not null references auth.users (id) on delete cascade,
  day     date not null,
  symbol  text not null,
  primary key (user_id, day)
);

alter table public.brief_days enable row level security;

-- True when p_symbol is today's brief (claiming the day if it is unused).
create or replace function public.ai_claim_brief(p_user uuid, p_day date, p_symbol text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_symbol text;
begin
  insert into public.brief_days (user_id, day, symbol) values (p_user, p_day, p_symbol)
  on conflict (user_id, day) do nothing;
  select symbol into v_symbol from public.brief_days where user_id = p_user and day = p_day;
  return v_symbol = p_symbol;
end;
$$;

revoke all on function public.ai_take(uuid, text, integer, integer) from public, anon, authenticated;
revoke all on function public.ai_claim_brief(uuid, date, text) from public, anon, authenticated;
grant execute on function public.ai_take(uuid, text, integer, integer) to service_role;
grant execute on function public.ai_claim_brief(uuid, date, text) to service_role;
