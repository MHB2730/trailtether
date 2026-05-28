---
tags: [type/issue, layer/infra, status/wip]
aliases: [Bugs, Open issues]
source_paths: []
---

# Known Issues

Open bugs + tech debt as of 2026-05-27.

## P1 — Real risk

### zapper-checkout has `Access-Control-Allow-Origin: *`

Same vulnerability that was just fixed in [[payfast-checkout]] + [[yoco-checkout]]. Allows any origin to initiate a Zapper checkout flow. One-edit-one-deploy fix when ready.

- Location: `supabase/functions/zapper-checkout/index.ts` line ~21
- Fix: copy the `ALLOWED_ORIGINS` array + `corsHeaders` helper from [[payfast-checkout]]

### Off-trail incident insert silently swallows errors

`unawaited(Supabase.instance.client.from('incidents').insert(...).catchError(...))` in [[recording_provider.dart]] `_maybePublishOffTrailAlert`. If the insert fails (network, RLS, quota), nothing surfaces — alert is lost.

- Location: `recording_provider.dart:386`
- Fix: queue + retry pattern like [[Workflow - Live Team Tracking]] uses

### increment_recorded_trail_downloads RPC missing

[[recorded_trail_service.dart]] line 192 calls this RPC for soft-counting downloads. It doesn't exist. The call is intentionally tolerant (try/catch noop) so things still work — but the counter never increments.

- Fix: create the RPC: `update recorded_trails set download_count = download_count + 1 where id = p_id`

## P2 — Polish

### Two `supabase-js` import paths in edge functions

Some functions import from `jsr:`, others from `https://esm.sh/`. Supabase recommends `jsr:` exclusively now. Worth standardising for consistency + version pinning.

### One unawaited Future in pc_shell.dart

Pre-existing lint at line 1495 in `pc_shell.dart`. Cosmetic.

### tt_home_screen use_build_context_synchronously

Line 520. After `await StartHikeRamp.show(context)`, the next call uses `context` without a mounted check. Cosmetic but worth fixing.

### app_links dependency_overrides

Pinned to 6.4.1. Worth checking whether newer versions have fixed the desktop OAuth regression so the override can be removed.

### Storage bucket RLS not in migrations

The Storage policies for `recorded-trails`, `gpx_uploads`, `incident-photos`, `profile-photos`, `app-releases` aren't captured in `supabase/migrations/`. They live only in the Supabase dashboard. Means fresh-install bootstrap is incomplete.

- Fix: dump current policies into a new migration

## P2 — Open follow-up RPCs

Several RPCs referenced from migrations / functions don't yet exist in production:
- `newsletter_record_open(p_send_id)` — fallback path in [[newsletter-track-open]] handles its absence
- `increment_recorded_trail_downloads` — see above

## See also

- [[Audit Findings]] — what was found in the recent audit (most fixed, some carried over here)
- [[Open Follow-Ups]] — non-bug planned work
