-- 0002_broker_links: one row per trading account linked to an MT5 terminal on
-- MetaRPC (mrpc.pro). Read and written only by the `mt5` edge function.
--
-- NOT APPLIED to any project. Apply it yourself:
--   supabase db push            (linked project)   or
--   supabase migration up       (local stack)
--
-- The MetaRPC API key never touches this table (it is a function secret:
-- `supabase secrets set MRPC_API_KEY=...`). The MT5 investor password is kept
-- in Supabase Vault; this table holds only the Vault secret's id, so a
-- dropped terminal can be reconnected without asking again.

create table if not exists public.broker_links (
  user_id      uuid        not null references auth.users (id) on delete cascade,
  -- TradingAccount.id on the device. The app never sees the terminal id.
  account_ref  text        not null check (length(account_ref) between 1 and 64),
  terminal_id  text        not null,
  login        bigint      not null,
  server       text        not null,
  secret_id    uuid        not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (user_id, account_ref)
);

comment on table public.broker_links is
  'MT5 links via MetaRPC. terminal_id and secret_id are server-only; clients read login/server only.';

drop trigger if exists broker_links_set_updated_at on public.broker_links;
create trigger broker_links_set_updated_at
  before update on public.broker_links
  for each row execute function public.set_updated_at();

alter table public.broker_links enable row level security;

-- Owners may see that a link exists (login, server), never the terminal or secret id.
create policy "broker_links: read own rows"
  on public.broker_links for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.broker_links from authenticated, anon;
grant select (account_ref, login, server, created_at, updated_at) on public.broker_links to authenticated;

-- Vault helpers for the edge function (service role only). Vault encrypts the
-- password at rest; `vault.decrypted_secrets` is not exposed to clients.
create or replace function public.broker_secret_create(p_secret text, p_name text)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select vault.create_secret(p_secret, p_name, 'mt5 investor password (broker_links)');
$$;

create or replace function public.broker_secret_read(p_id uuid)
returns text
language sql
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets where id = p_id;
$$;

create or replace function public.broker_secret_delete(p_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from vault.secrets where id = p_id;
$$;

revoke all on function public.broker_secret_create(text, text) from public, anon, authenticated;
revoke all on function public.broker_secret_read(uuid) from public, anon, authenticated;
revoke all on function public.broker_secret_delete(uuid) from public, anon, authenticated;
grant execute on function public.broker_secret_create(text, text) to service_role;
grant execute on function public.broker_secret_read(uuid) to service_role;
grant execute on function public.broker_secret_delete(uuid) to service_role;
