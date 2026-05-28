---
tags: [type/issue, layer/infra, status/fragile]
aliases: [Fragile, Tech Debt]
source_paths: []
---

# Fragile Areas

Code/architecture spots where care is required when changing.

## hilltrek-admin/app.js is monolithic

4,500 LOC of vanilla JS in one file, hash-routed. No build, no minification, no module boundaries. Edits are read-heavy. The next significant change is a refactor candidate — likely worth extracting modules (views, services) but no current priority.

See [[Hilltrek Admin Module]].

## Two recording UIs in parallel

[[LiveTrackingScreen]] (full-screen route) and [[TTMapScreen]] (Map tab with bottom sheet) both render recording state from [[recording_provider.dart]]. The [[FinishHikeSheet]] refactor unified the save flow but left both surfaces — see commit `988bb2e`.

If you change recording UX, both need updating in lock-step.

## Trail data has 3 storage layers

- Bundled `assets/data/routes_cleaned.json` (offline fallback)
- SharedPreferences cache `trails_supabase_cache_v1` (after first fetch)
- Supabase [[trails]] table (source of truth)

Layered fallback in [[trail_service.dart]] `loadTrails()`:
1. In-memory cache (already loaded)
2. Supabase fetch
3. On-disk cache from previous fetch
4. Bundled JSON

After admin edits via [[PcTrailsScreen]], `StaticDataProvider.refreshTrails()` invalidates layers 1 + 2 so the change propagates. Skipping this step shows stale data.

## Heavy `Trail.fromJson`

[[Trail Model]] `.fromJson` does RDP simplification + Chaikin smoothing + ascent/descent computation + difficulty derivation. Roughly 280 LOC of one-shot work. If a row is corrupt, the exception is logged and the row is skipped — but a malformed `coords` array can silently degrade visual fidelity. Worth a JSON schema gate before insert from `seedFromBundle`.

## Schema drift: migrations folder is incomplete

`supabase/migrations/` only has 13 files (mostly 2026-05 additions). Tables like [[profiles]], [[teams]], [[hike_history]], [[recorded_trails]], [[chat_messages]], [[reviews]] etc. don't appear in any migration file — they predate the folder. The deleted `master_supabase_setup.sql` was a partial dump from initial commit.

**A fresh-install from `supabase/migrations/` alone won't work.** You'd need to dump the live schema first.

## Two supabase-js import paths in edge functions

`jsr:@supabase/supabase-js@2` (newer functions) vs `https://esm.sh/@supabase/supabase-js@2.45.0` (older). Standardising will require touching every payment function.

## Storage bucket policies aren't in migrations

`recorded-trails`, `gpx_uploads`, `incident-photos`, `profile-photos`, `app-releases` policies are configured via Supabase dashboard. Re-deploy / disaster recovery would lose them.

## Realtime channel reconnection in chat

[[chat_provider.dart]] has 2-30s exponential backoff for reconnects. Solid for normal hiccups, but if the user is offline for long periods, the queue is in-memory only (not persisted like [[offline_track_queue.dart]]). Messages typed offline are lost.

## See also

- [[Known Issues]] — overlap with concrete bugs
- [[Open Follow-Ups]]
