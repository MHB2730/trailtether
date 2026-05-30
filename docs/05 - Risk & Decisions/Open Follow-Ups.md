---
tags: [type/issue, layer/infra, status/wip]
aliases: [TODOs, Backlog]
source_paths: []
---

# Open Follow-Ups

Non-bug planned work and decisions.

## v4.0 follow-ups (lower priority)
- **Commit `supabase/config.toml`** pinning `verify_jwt = false` for the webhook + email-tracking functions so the setting is reproducible (currently only in the live project; see [[Known Issues]]).
- **Narrow the [[zapper-webhook]] signature check** — it accepts multiple header names + hex/base64 ("unconfirmed"); narrow to the single correct form once verified against a real Zapper delivery. Fails closed when the secret is unset, so not a hole.
- **Confirm `team_add_member` / `team_remove_member` verify caller-owns-team** internally (authenticated-callable SECURITY DEFINER; should reject editing a team you don't own).
- **Routing is start/end-node only** ([[routing_service.dart]]) — trails crossing mid-segment aren't connected. Intersection-aware routing is a feature, not a bug; track if multi-trail routing matters.
- **Off-trail/incident queue drains only on a connectivity *change*** — launching already-online with a backlog won't drain until connectivity flaps. Consider draining once on startup.

## Security hardening (current Supabase)
- **Enable Auth leaked-password protection** — Supabase Dashboard → Authentication → password / attack-protection settings → toggle on (HaveIBeenPwned). Advisor still flags it; the one genuinely valuable quick win. Can't be done via SQL/MCP — it's a GoTrue config toggle.
- **`citext` / `pg_net` in `public`** (advisor `extension_in_public`, WARN) — **left as-is on purpose**. `citext` backs [[site_subscribers]]`.email` + [[apk_downloads]]`.email`, and the API roles (`anon`/`authenticated`/`authenticator`) don't carry `extensions` in their search_path (only `postgres` does) — so `ALTER EXTENSION … SET SCHEMA extensions` risks breaking newsletter signup; `pg_net` is finicky to relocate. Cosmetic, not a vulnerability. Only move in a maintenance window with role search_path updates + testing.

## Platform: Supabase → Google Cloud (decision, not started)
Driver: **control / avoiding lock-in** — explicitly *not* cost or security (a migration wouldn't improve security; the cutover is the bigger risk). Target: **Cloud SQL (Postgres) + Google managed services** — keep the schema, RLS and SECURITY DEFINER RPCs; replace Supabase Auth → Identity Platform, the auto REST/Realtime, Storage → GCS, and the ~18 edge functions → Cloud Run/Functions. Touches all four surfaces (app, site, admin, watch). Multi-week; run old + new in parallel with a deliberate cutover. Detailed phased plan still to be written.

## Play Store launch (no code blockers)
- Build with `flutter build appbundle --flavor playStore --release` — **not** `sideload` (that flavor carries the Play-banned `REQUEST_INSTALL_PACKAGES`, isolated to its source set).
- Play Console: **Data Safety** form (answer sheet ready at `trailtether_app/PLAY_DATA_SAFETY.md`), background-location declaration + ~20–40s demo video, content rating, store listing. Privacy URL `https://hilltrek.co.za/privacy/`; deletion URL `https://hilltrek.co.za/account`.
- Confirm before submitting Data Safety: Sentry device-id/PII setting; whether HR/health data is stored server-side; whether in-app chat is live for users.

## Hilltrek admin SPA modularisation

[[Hilltrek Admin Module]] — `app.js` is 4,500 LOC monolithic. Worth carving into modules per view (newsletters, orders, hikers, trailtether tab). Lower priority while it works; refactor when adding a major new feature.

## Mobile Trails admin

Currently the curated trails CRUD is **PC-only** ([[PcTrailsScreen]]). Mobile users with admin privileges can't edit on the go. If demand emerges, add a mobile admin surface.

## Berg Live community heatmap UI

[[berg_pulse_stats]] family has `berg_pulse_heatmap_cells()` returning hex-binned tracks. The public `/pulse/` page on hilltrek.co.za uses it. Hover to confirm — could be richer visualisation.

## Refresh tokens for tether_pairings

Currently [[tether_pairings]] tokens expire and are claimed once. If the link is lost, the PC user has to mint a new one. Refresh / re-claim flow could be added.

## Open + click counters in newsletter sends

[[site_newsletter_sends]] has `open_count` + `click_count` columns but [[newsletter-track-open]] / [[newsletter-track-click]] only `set opened_at = now() where opened_at is null`. They don't increment per repeat hit. If per-recipient repeat-engagement tracking matters, fix that.

## iOS / Web builds inactive

`pubspec.yaml` has ios + web sections but no actively-shipped build. Currently Android + Windows only. If iOS becomes important, expect:
- Apple Developer account + signing
- ATS exemption for Open-Meteo HTTP (or move to HTTPS-only)
- Local notifications iOS authorisation
- Apple Pay (instead of South African providers, depending on geo)

## flutter test suite (partial ✅)

23 automated tests now passing — covering [[offline_incident_queue.dart]] retry logic (4 tests), widget tests, and model parsing tests. Manual QA remains for broader flows. More tests on critical paths ([[Workflow - Record Hike]] save, [[FinishHikeSheet]] state machine) still desirable.

## Hilltrek site weather card moved to APK page?

The `/trailtether/` APK landing page could carry the same `weather.js` widget as the homepage, since users on that page are about to install a weather-dependent app. Marketing decision.

## Completed ✅

- **Storage bucket RLS in migrations**: Created `20260528_storage_rls_policies.sql` migration. Verified 31 RLS policies active across all 6 storage buckets in production.
- **Audit follow-ups from this session** — all 4 items done:
  - [[zapper-checkout]] CORS: fixed (`ALLOWED_ORIGINS` instead of `*`)
  - `increment_recorded_trail_downloads` RPC: built and deployed
  - Off-trail incident retry queue: built, tested (4 tests in [[offline_incident_queue.dart]])
  - Supabase-js imports: all standardised on `jsr:` specifiers

## See also

- [[Known Issues]] — open bugs
- [[Audit Findings]] — what just got done
