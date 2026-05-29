---
tags: [type/issue, layer/infra, status/stable]
aliases: [Bugs, Open issues]
source_paths: []
---

# Known Issues

Open bugs + tech debt as of 2026-05-29 (v4.0 pre-ship).

## ⚠️ Verify before v4.0 goes public

### verify_jwt = true on payment webhooks (HIGH — confirm payments finalize)
All 15 edge functions report `verify_jwt: true`, including the provider webhooks ([[payfast-itn]], [[yoco-webhook]], [[zapper-webhook]]) and email-tracking ([[newsletter-track-open]], [[newsletter-track-click]]). External callers (payment providers, email clients) send no Supabase JWT, so a truly-enforced `verify_jwt` would 401 them at the gateway and orders would never finalize. The webhook *code* verifies provider signatures correctly, so the fix is config: set `verify_jwt = false` on those functions (commit a `supabase/config.toml`, or set per-function on redeploy). **Action: run one real test payment end-to-end; if the order doesn't flip to paid, turn verify_jwt off on the webhooks.**

### Auth leaked-password protection disabled (advisor)
Enable in Supabase Dashboard → Authentication → Password (checks against HaveIBeenPwned). Dashboard toggle; doesn't affect existing users or signups.

### Google sign-in needs the release keystore's SHA-1 in Google Cloud Console
The code is correct (native idToken via `google_sign_in` → `signInWithIdToken`). But the published/sideload APK is signed with the release keystore, whose SHA-1 must be registered on the Android OAuth client in Google Cloud Console — otherwise Google returns no idToken and sign-in fails *only in the released build*. **Action: sign in with Google once on the published APK.**

### On-device QA of core flows not yet run
Code + backend wiring is verified and the app smoke-launches clean, but the interactive flows haven't been tapped end-to-end (no tool drives the physical UI). Before public ship: sign-up, create + join a team, record + save a hike, and confirm it streams live to the PC watcher.

## Resolved 2026-05-29 (post-ship) ✅
- **PC Trails edit/delete did nothing** ("Saved" but no change). Three overlapping causes: (1) [[trails]] was never seeded, so [[trail_service.dart]] served the read-only bundle and writes hit nonexistent rows; (2) `bremnermail@gmail.com` had `profiles.is_admin=true` but no [[admin_users]] row, so [[is_admin]]() was false and RLS silently filtered writes to 0 rows (split-brain admin); (3) [[trail_repository.dart]] didn't check affected rows, so it reported false success. Fixed: added the admin_users row (verified `is_admin()=true`), seeded the catalogue, and the repo now `.select()`s affected rows. [[Trail Model]] now treats stored difficulty + elevation-gain as authoritative (those edits used to be recomputed away) and reads `published`.
- **Catalogue duplicates** — the bundle seeds ~29 routes twice (hyphen-id + underscore-id twins). Removed the redundant twins: 233 → **197 unique routes**. ⚠️ Re-seeding reintroduces them until `routes_cleaned.json` is cleaned.

## Resolved in v4.0.0+62 ✅
- Live mobile map marker froze at start (now advances; directional dot).
- Solo hike/walk save failed on `community_activities` NOT-NULL `team_id`/`team_name` (now nullable; duplicate client insert removed).
- [[TTWelcomeScreen]] RenderFlex overflow + missing `feature_graphic.png` asset crash on launch.
- PII (email + GPS) streamed to [[app_logs]] in release builds — gated to debug + email dropped.
- `increment_recorded_trail_downloads` mutable search_path (advisor 0011).
- App-wide stale UX copy ("Tap PLAY", "Start Hike on the Map", PC-pairing instructions, "Hilltrek" brand leak, achievement label mismatches).

## Resolved in v3.7.6+61 ✅

All previously identified P1 critical risks and core P2 developer warnings have been successfully addressed, resolved, and deployed:

- **zapper-checkout CORS Hardening**: Restrained `Access-Control-Allow-Origin` from `*` to `ALLOWED_ORIGINS` (hilltrek.co.za / www. / admin.) in [[zapper-checkout]] to match payfast/yoco checkout security.
- **Off-Trail Alert Failures**: Resolved silent failure swallow by introducing the local persistent [[offline_incident_queue.dart]] FIFO buffer. Failed off-trail alerts are now safely queued and synchronization-retried automatically.
- **`increment_recorded_trail_downloads` RPC**: Created and successfully deployed the standard Postgres RPC SQL function to the production database via the linked Supabase CLI. Counters now increment properly when recorded trails are downloaded.
- **Edge Function Imports Standardisation**: Standardized all remaining Supabase JS SDK imports in Deno Edge Functions to exclusively use `jsr:` specifiers instead of raw `esm.sh` URLs.
- **Linter Warnings & Use-Build-Context Synchronisation**: Successfully resolved all 23 Flutter linter warnings (unawaited futures, redundant casts, missing const constructor keywords, and unmounted BuildContext calls) in widgets like `pc_shell.dart`, `tt_home_screen.dart`, and `start_hike_ramp.dart`.
- **Storage Bucket RLS Documentation**: Created `20260528_storage_rls_policies.sql` migration as living documentation. Verified 31 RLS policies already active across all 6 storage buckets (app-releases, recorded-trails, gpx-uploads, incident-photos, profile-photos, website-assets) in production.

## P2 — Polish

### app_links dependency_overrides

Pinned to 6.4.1. Worth checking whether newer versions have fixed the desktop OAuth regression so the override can be removed.

## P2 — Open follow-up RPCs

Several RPCs referenced from migrations / functions don't yet exist in production:
- `newsletter_record_open(p_send_id)` — fallback path in [[newsletter-track-open]] handles its absence

## See also

- [[Audit Findings]] — what was found in the recent audit (most fixed, some carried over here)
- [[Open Follow-Ups]] — non-bug planned work
