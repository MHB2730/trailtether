---
tags: [type/component, layer/frontend, status/removed, domain/recording, domain/teams]
aliases: [live_tracking_screen]
source_paths: []
---

# LiveTrackingScreen

> [!warning] DELETED 2026-05-30 (commit `eb7b7d0`)
> This screen was the **second** way to record a hike — a duplicate recorder reachable from the [[TTTeamScreen]] "trek-watch" map gesture. To lock recording down to a single tool, it was **deleted** (1,403 LOC) and the Teams gesture now routes to the Map tab (`onNavigate(1)`). **[[TTMapScreen]] is the sole recorder.** Doc kept as a tombstone; the notes below describe the removed screen for historical context only.

Full-screen recording UI. Originally the only recording UX; after the Strava-style refactor, it lived on as the "View Live Map" entry from [[TTTeamScreen]] but was no longer the primary recording surface (that's now on [[TTMapScreen]]) — and is now removed entirely.

## Composition

- Full-bleed `_LiveMap` (2D or 3D depending on `_mapMode`)
- Bottom gradient fade
- `_SituationBar` (top): trail name, sunset countdown, GPS health pill
- `_OffTrailBanner` (when off-trail) with bearing arrow + return direction
- `_IncidentBanner` (when nearby incident)
- Right column of map buttons: gps_fixed/not_fixed, layers, ghost mode, battery saver
- Bottom stat overlays: Altitude / Pace / Distance + target progress card
- Control bar: START TRACKING (when idle) or PAUSE/RESUME + FINISH (when recording)

## FINISH button

Calls `_showFinishDialog(rec)` which delegates to `FinishHikeSheet.show(context, rec, onSaved: …, onDiscarded: …)`. On save or discard, callbacks pop the LiveTrackingScreen route (returns the user to wherever they came from). On Keep Recording, sheet closes, screen stays put.

## Side effects

- Initialises compass listener (skipped on desktop platforms)
- Periodic weather fetch (every 30 min via Timer)
- Listens to `[[recording_provider.dart]]` and forwards new GPS fixes to `SafetyProvider.checkSafetyProximity` for incident alerts

## Push routes

- [[TTTeamScreen]] `_openLiveMap` pushes this for team viewing
- (Was previously pushed from home/map screens that have since been deleted in cleanup)

## Used by

- [[TTTeamScreen]]
- (no longer the primary recording surface — that's [[TTMapScreen]])

## Depends on

- [[recording_provider.dart]], [[safety_provider.dart]], [[static_data_provider.dart]], [[team_provider.dart]], [[units_provider.dart]], [[app_state_provider.dart]]
- [[FinishHikeSheet]] (FINISH button)
- [[TrailMapWidget]] / [[TrailMap3DWidget]] / [[SpeedPathLayer]]
- [[TT Design Tokens]]

## Key file

- `lib/screens/live_tracking_screen.dart` (~1450 LOC)
- After the recent refactor, the inline `_showFinishDialog` shrank from 264 to 14 lines (it just delegates to [[FinishHikeSheet]])
