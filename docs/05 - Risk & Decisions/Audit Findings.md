---
tags: [type/issue, layer/infra, status/stable]
aliases: [Audit log, Session findings]
source_paths: []
---

# Audit Findings

Results of the 2026-05-27 comprehensive codebase audit. Each finding categorised by what got done.

## Fixed (already deployed)

### A1 — Hide PC admin tabs from non-admins ✅

PC nav now filters admin-only tabs (Trails, Settings) by `AuthProvider.isAdmin`. See [[MainPcShell]] `_NavSpec.adminOnly`.

### A2 — Restrict CORS on payment edge functions ✅

[[payfast-checkout]] + [[yoco-checkout]] no longer use `*`. Tightened to hilltrek.co.za / www. / admin. allowlist, matching [[apk-download-gate]]'s pattern. Deployed v22 each.

### A4 — 5s timeout on Turnstile verify ✅

[[apk-download-gate]] now uses `AbortController` with 5s deadline when calling Cloudflare. Avoids hangs on slow CDN. Deployed v16.

## False positives caught during verification

### A3 — Cron-secret bypass

Audit alleged that [[finalize-orphan-hikes]] line 58 accepts empty CRON_SECRET. Re-reading: `if (!CRON_SECRET || ...)` short-circuits to true when `CRON_SECRET=""` (empty string is falsy), so the guard fires and returns 401. **No change needed.**

### A5 — publish_site.ps1 env validation

Audit alleged `Require-Env` is defined but never called. Re-reading: lines 78-80 actually call `Require-Env` for `CPANEL_HOST`, `CPANEL_USER`, `CPANEL_API_TOKEN`. **No change needed.**

### A6 — Yoco re-checkout idempotency

Audit alleged [[yoco-checkout]] doesn't reject `processing` orders. Re-reading: line 66 is `if (order.status !== "pending")` which rejects everything except `pending`, including `processing`. **No change needed.**

## Carried into [[Known Issues]]

- zapper-checkout CORS `*` (same issue, separate function)
- Off-trail incident insert silently swallows errors
- increment_recorded_trail_downloads RPC missing
- Two supabase-js import paths

## Diagnosis findings (not bugs, design questions)

### Aasvoelkrans visibility

Trails with "cave" in the name are rendered brown/dotted/40%-opacity in [[TrailMapWidget]] + [[TrailMarkerLayer]]. On the dark Mission Control map they read as "missing". Not a bug — design choice — but the user perceived it as a data issue. The newly-built [[Workflow - Trails CRUD]] gives the admin a path to rename / dedupe / re-categorise.

## Cleanup actions also taken in audit

- Deleted 16 dead Flutter screens (B1)
- Deleted `master_supabase_setup.sql` + root Vite remnants (B2, ~148 MB)
- Deleted `trailtether_rn/` (B3, ~411 MB)
- Built [[newsletter-send]] edge function (C1) — the admin SPA was invoking a non-existent function
- Pulled 5 prod-only edge functions into repo (`analytics-ingest`, `health-pinger`, `newsletter-track-open`, `zapper-checkout`, `zapper-webhook`)

## See also

- [[Known Issues]] — what remains open
- [[Build & Deploy]]
