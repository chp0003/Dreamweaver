# Supabase setup for Dreamweaver

Dreamweaver talks to Supabase for **accounts** and **cloud saves**.
Until you paste keys, it keeps using local `user://accounts.json` so the game still runs.

## 1. Create a project

1. Go to [https://supabase.com](https://supabase.com) and sign in.
2. **New project** → pick a name, DB password, region → create.
3. Wait until the project is ready.

## 2. Turn off email confirmation (important for games)

Authentication → **Providers** → **Email**:

- Disable **Confirm email** (otherwise register succeeds but the player cannot sign in until they click a link).

## 3. Create tables

1. Open **SQL Editor** → New query.
2. Paste the contents of [`supabase/schema.sql`](../supabase/schema.sql).
3. Run it. You should see `profiles` and `player_saves` under **Table Editor**.

## 4. Copy API keys into the game

1. **Project Settings** → **API**.
2. Copy:
   - **Project URL** (looks like `https://xxxxx.supabase.co`)
   - **anon public** key (long JWT starting with `eyJ...`)
3. Open [`scripts/systems/supabase_config.gd`](../scripts/systems/supabase_config.gd) and paste:

```gdscript
const URL := "https://YOUR_PROJECT.supabase.co"
const ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...."
```

4. Save. Relaunch the game.

Do **not** put the **service_role** key in the game client. Only the anon key.

## 5. How it connects

| Piece | Role |
|--------|------|
| `scripts/systems/supabase_config.gd` | URL + anon key |
| `Supabase` autoload | HTTP Auth + PostgREST |
| `AccountManager` | Same API as before; routes to cloud when configured |

- UI still asks for **username + password** (no email field).
- Under the hood the email is `username@players.dreamweaver.game`.
- Progress JSON matches what `GameState.save()` already writes.
- Session tokens live in `user://supabase_session.json`.

## 6. Verify

1. Register a new username in-game.
2. In Supabase → **Authentication → Users**, you should see that user.
3. Play a bit / New Game so progress saves.
4. In **Table Editor → player_saves**, you should see a row with JSON progress.
5. Log out, log back in — Continue should restore the run.

## 7. Account deletion note

In-game **Delete account** clears `player_saves` + `profiles` and signs out (soft delete).
Removing the Auth user entirely needs the dashboard or a service-role Edge Function — the anon key cannot delete Auth users.

## Local fallback

Leave `URL` and `ANON_KEY` as `""` and nothing changes: accounts stay in `user://accounts.json`.
