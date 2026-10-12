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

-- Every registered login gets a profile, including accounts created before the
-- trigger existed and profiles that were deleted while the Auth user remained.
do $$
declare
  rec record;
  base_name text;
  final_name text;
  n int;
begin
  for rec in
    select u.id, u.email, u.raw_user_meta_data
    from auth.users u
    where u.deleted_at is null
      and not exists (select 1 from public.profiles p where p.id = u.id)
  loop
    base_name := left(coalesce(
      nullif(trim(rec.raw_user_meta_data->>'username'), ''),
      nullif(split_part(coalesce(rec.email, ''), '@', 1), ''),
      'weaver'
    ), 40);
    final_name := base_name;
    n := 2;
    while exists (
      select 1 from public.profiles where lower(username) = lower(final_name)
    ) loop
      final_name := left(base_name, 36) || ' ' || n::text;
      n := n + 1;
      exit when n > 50;
    end loop;
    begin
      insert into public.profiles (id, username, email)
      values (rec.id, final_name, coalesce(rec.email, ''))
      on conflict (id) do nothing;
    exception when unique_violation then
      begin
        insert into public.profiles (id, username, email)
        values (
          rec.id,
          left(final_name, 36) || ' ' || left(rec.id::text, 4),
          coalesce(nullif(rec.email, ''), 'recovered-' || rec.id::text)
        )
        on conflict (id) do nothing;
      exception when unique_violation then
        null;
      end;
    end;
  end loop;
end $$;

-- Public leaderboard: every registered weaver, username + progress only (no emails).
-- Reads auth.users so a missing profiles row cannot hide a registration.
-- Bypasses own-row RLS. Drop first because the return columns changed.
drop function if exists public.fetch_leaderboard();

create function public.fetch_leaderboard()
returns table (
  user_id uuid,
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
    u.id,
    coalesce(
      nullif(trim(p.username), ''),
      nullif(trim(u.raw_user_meta_data->>'username'), ''),
      nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
      'weaver'
    ),
    coalesce(s.progress, '{}'::jsonb),
    coalesce(s.updated_at, u.created_at)
  from auth.users u
  left join public.profiles p on p.id = u.id
  left join public.player_saves s on s.user_id = u.id
  where u.deleted_at is null
  order by u.id
$$;

revoke all on function public.fetch_leaderboard() from public;
grant execute on function public.fetch_leaderboard() to authenticated;

notify pgrst, 'reload schema';
