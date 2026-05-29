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
