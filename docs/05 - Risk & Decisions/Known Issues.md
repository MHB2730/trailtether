---
tags: [type/issue, layer/infra, status/stable]
aliases: [Bugs, Open issues]
source_paths: []
---

# Known Issues

Open bugs + tech debt as of 2026-05-28.

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
