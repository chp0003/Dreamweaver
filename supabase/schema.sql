-- Dreamweaver — Supabase schema
-- Run once in: Supabase Dashboard → SQL Editor → New query → Run
--
-- Creates profiles + player_saves with RLS so each Auth user only
-- touches their own rows.

-- Profiles (username ↔ auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique,
  created_at timestamptz not null default now()
);

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

-- Optional: keep username in sync when Auth user is created (backup to client upsert)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
