extends RefCounted
## Paste your Supabase project values here.
##
## Full walkthrough: docs/SUPABASE_SETUP.md
## 1. Create a project at https://supabase.com
## 2. Project Settings → API → copy Project URL + anon public key
## 3. SQL Editor → run supabase/schema.sql
## 4. Fill URL and ANON_KEY below (leave empty to keep local JSON auth)

## Example: "https://abcdefghijklmnop.supabase.co"
const URL := "https://dsfxttfwdqswmafzkitd.supabase.co"

## Example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
const ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRzZnh0dGZ3ZHFzd21hZnpraXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3OTIzNDUsImV4cCI6MjEwMzM2ODM0NX0.eTcRiYHnExnumR-eFeURAjXW30yi3mKe5Ak9LEkuI24"

## Turns usernames into Auth emails without adding an email field to the UI.
## Login "slang" becomes "slang@players.dreamweaver.game".
const EMAIL_DOMAIN := "players.dreamweaver.game"


static func is_configured() -> bool:
	return not URL.strip_edges().is_empty() and not ANON_KEY.strip_edges().is_empty()


static func email_for_username(username: String) -> String:
	var key := username.strip_edges().to_lower()
	var cleaned := ""
	for i in key.length():
		var ch := key[i]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "." or ch == "_" or ch == "-":
			cleaned += ch
	if cleaned.is_empty():
		cleaned = "weaver"
	return "%s@%s" % [cleaned, EMAIL_DOMAIN]
