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

## 3. Create / update tables

1. Open **SQL Editor** → New query.
2. Open [`supabase/schema.sql`](../supabase/schema.sql), **copy the entire file**, paste, Run.
3. Safe to re-run if you already applied an older version — it adds the `email` column, keeps RLS, and creates `fetch_leaderboard()` for the Gateway leaderboard.
4. You should see `profiles` (with `username` + `email`) and `player_saves` under **Table Editor**. Re-run this SQL if the in-game leaderboard only shows your own name while other weavers exist in the cloud.

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
| `AccountManager` | Routes to cloud when configured |

- **Register:** username + email + password
- **Sign in:** email + password (username is display-only)
- Auth uses the real email; `profiles.username` is the in-game name
- Progress JSON matches what `GameState.save()` already writes
- Session tokens live in `user://supabase_session.json`
- The Gateway **Leaderboard** calls `fetch_leaderboard()` (usernames + progress, no emails)

## 6. Verify

1. Register with a username + real email in-game.
2. In Supabase → **Authentication → Users**, you should see that email.
3. In **Table Editor → profiles**, username and email should both appear.
4. Play a bit / New Game so progress saves → check **player_saves**.
5. Log out, sign in with the same email — Continue should restore the run.

## 7. Account deletion note

In-game **Delete account** clears `player_saves` + `profiles` and signs out (soft delete).
Removing the Auth user entirely needs the dashboard or a service-role Edge Function — the anon key cannot delete Auth users.

## Local fallback

Leave `URL` and `ANON_KEY` as `""` and accounts stay in `user://accounts.json` (still stores username + email).
