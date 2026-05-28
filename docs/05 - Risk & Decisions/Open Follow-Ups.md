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

## Storage bucket RLS in migrations

Capture current bucket policies in a new SQL migration so disaster recovery works. See [[Fragile Areas]].

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

## flutter test suite

No automated tests in `trailtether_app/test/`. Manual QA is the safety net. If/when the app grows or contributors join, worth seeding a few golden tests on critical paths ([[Workflow - Record Hike]] save, [[FinishHikeSheet]] state machine).

## Hilltrek site weather card moved to APK page?

The `/trailtether/` APK landing page could carry the same `weather.js` widget as the homepage, since users on that page are about to install a weather-dependent app. Marketing decision.

## Audit follow-ups from this session

- Fix [[zapper-checkout]] CORS `*` (described in [[Known Issues]])
- Build `increment_recorded_trail_downloads` RPC
- Off-trail incident retry queue
- Standardise supabase-js imports

## See also

- [[Known Issues]] — open bugs
- [[Audit Findings]] — what just got done
