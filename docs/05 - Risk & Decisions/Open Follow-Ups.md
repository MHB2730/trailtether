---
tags: [type/issue, layer/infra, status/wip]
aliases: [TODOs, Backlog]
source_paths: []
---

# Open Follow-Ups

Non-bug planned work and decisions.

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
