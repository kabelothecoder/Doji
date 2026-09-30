-- 0001_profiles: one row per signed-in user, holding their profile.doji.
--
-- NOT APPLIED to any project. Apply it yourself:
--   supabase db push            (linked project)   or
--   supabase migration up       (local stack)
--
-- The app is local-first: onboarding writes profile.doji to the device and
-- marks it pendingSync; the auth slice upserts it here on first sign-in.

create table if not exists public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  -- Everything onboarding learned (ProfileDoji.toJson()).
  profile_doji       jsonb       not null default '{}'::jsonb,
  -- Rank ladder from the design system: M1 Impulsive → MN Doji.
  rank               text        not null default 'M1'
                       check (rank in ('M1', 'M5', 'M15', 'H1', 'H4', 'D1', 'W1', 'MN')),
  doji_score         integer     not null default 0 check (doji_score between 0 and 1000),
  onboarding_version integer     not null default 1,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table public.profiles is 'One row per user: profile.doji plus server-owned rank and score.';

create index if not exists profiles_rank_idx on public.profiles (rank);
create index if not exists profiles_doji_score_idx on public.profiles (doji_score desc);
create index if not exists profiles_created_at_idx on public.profiles (created_at);

-- Keep updated_at honest.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Row Level Security: users can read and write only their own row.
alter table public.profiles enable row level security;

create policy "profiles: read own row"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

create policy "profiles: insert own row"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);

create policy "profiles: update own row"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy "profiles: delete own row"
  on public.profiles for delete to authenticated
  using ((select auth.uid()) = id);

-- Rank and score are earned, not typed: clients may write their own
-- profile_doji but only the service role (server code) changes rank/score.
revoke insert, update on public.profiles from authenticated, anon;
grant select, delete on public.profiles to authenticated;
grant insert (id, profile_doji, onboarding_version) on public.profiles to authenticated;
grant update (profile_doji, onboarding_version) on public.profiles to authenticated;
