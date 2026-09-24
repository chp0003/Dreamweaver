-- Dreamweaver — Supabase schema
-- =============================================================================
-- COPY EVERYTHING BELOW → Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run (idempotent). Creates/updates profiles + player_saves with RLS.
-- =============================================================================

-- Profiles: display username + real email, linked to Auth
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null,
  email text not null,
  created_at timestamptz not null default now()
);

-- Upgrade path if you already ran an older schema without email
alter table public.profiles
  add column if not exists email text;

alter table public.profiles
  alter column email set default '';

-- Backfill empty emails from Auth when possible
update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id
  and (p.email is null or p.email = '');

-- Enforce uniqueness (drop+recreate so re-runs stay clean)
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_username_key'
  ) then
    alter table public.profiles add constraint profiles_username_key unique (username);
  end if;
exception when others then
  -- already unique via another name; ignore
  null;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_email_key'
  ) then
    alter table public.profiles add constraint profiles_email_key unique (email);
  end if;
exception when others then
  null;
end $$;

-- Cloud game saves (one row per player)
create table if not exists public.player_saves (
  user_id uuid primary key references auth.users (id) on delete cascade,
  progress jsonb not null default '{}'::jsonb,
  has_seen_intro boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.player_saves enable row level security;

-- profiles policies
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
  on public.profiles for delete
  using (auth.uid() = id);

-- player_saves policies
drop policy if exists "saves_select_own" on public.player_saves;
create policy "saves_select_own"
  on public.player_saves for select
  using (auth.uid() = user_id);

drop policy if exists "saves_insert_own" on public.player_saves;
create policy "saves_insert_own"
  on public.player_saves for insert
  with check (auth.uid() = user_id);

drop policy if exists "saves_update_own" on public.player_saves;
create policy "saves_update_own"
  on public.player_saves for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "saves_delete_own" on public.player_saves;
create policy "saves_delete_own"
  on public.player_saves for delete
  using (auth.uid() = user_id);

-- Auto-create a profile row when an Auth user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, email)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'username'), ''),
      split_part(new.email, '@', 1)
    ),
    coalesce(new.email, '')
  )
  on conflict (id) do update
    set username = excluded.username,
        email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Public leaderboard: usernames + progress only (no emails). Bypasses own-row RLS.
create or replace function public.fetch_leaderboard()
returns table (
  username text,
  progress jsonb,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    p.username,
    coalesce(s.progress, '{}'::jsonb),
    s.updated_at
  from public.profiles p
  left join public.player_saves s on s.user_id = p.id
  where p.username is not null
    and length(trim(p.username)) > 0
$$;

revoke all on function public.fetch_leaderboard() from public;
grant execute on function public.fetch_leaderboard() to authenticated;
