extends RefCounted
## Paste your Supabase project values here.
##
## Full walkthrough: docs/SUPABASE_SETUP.md
## 1. Create a project at https://supabase.com
## 2. Project Settings → API → copy Project URL + anon public key
## 3. SQL Editor → run supabase/schema.sql (whole file)
## 4. Fill URL and ANON_KEY below (leave empty to keep local JSON auth)

## Example: "https://abcdefghijklmnop.supabase.co"
const URL := "https://dsfxttfwdqswmafzkitd.supabase.co"

## Example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
const ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRzZnh0dGZ3ZHFzd21hZnpraXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3OTIzNDUsImV4cCI6MjEwMzM2ODM0NX0.eTcRiYHnExnumR-eFeURAjXW30yi3mKe5Ak9LEkuI24"


static func is_configured() -> bool:
	return not URL.strip_edges().is_empty() and not ANON_KEY.strip_edges().is_empty()
