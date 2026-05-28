---
tags: [type/workflow, layer/frontend, status/stable, domain/recording]
aliases: [Record flow, Recording flow]
source_paths: [trailtether_app/lib/providers/recording_provider.dart, trailtether_app/lib/widgets/finish_hike_sheet.dart, trailtether_app/lib/widgets/start_hike_ramp.dart, trailtether_app/lib/providers/hike_history_provider.dart, trailtether_app/lib/services/recorded_trail_service.dart]
---

# Workflow - Record Hike

Start → record → finish → save. The heart of the app.

```mermaid
sequenceDiagram
  actor U as Hiker
  participant Home as TTHomeScreen
  participant Ramp as StartHikeRamp
  participant RP as RecordingProvider
  participant Loc as LocationService
  participant TT as TeamTrackingProvider
  participant Map as TTMapScreen
  participant Sheet as FinishHikeSheet
  participant HH as HikeHistoryProvider
  participant RTS as RecordedTrailService
  participant DB as Supabase

  U->>Home: tap "Start Hike"
  Home->>Ramp: StartHikeRamp.show()
  Ramp-->>U: slide-to-start + 3-2-1
  U->>Ramp: confirmed
  Ramp-->>Home: true
  Home->>RP: start()
  RP->>RP: alloc UUID (currentHikeId), set _startTime
  RP->>Loc: subscribe smooth(getPositionStream)
  Loc-->>RP: stream of Position
  Home->>Map: navigate to Map tab

  loop each accepted GPS fix
    Loc-->>RP: Position
    RP->>RP: validate (accuracy, jump, freshness)
    RP->>RP: append to _points, update totals
    RP->>RP: every 30s persist draft to SharedPreferences
    RP-->>TT: emit position (via provider notify)
    TT->>DB: upsert team_member_locations + insert team_member_track_points
  end

  U->>Map: tap STOP on bottom sheet
  Map->>Sheet: FinishHikeSheet.show(rec)
  Sheet->>RP: pause()
  U->>Sheet: fill form + tap SAVE
  Sheet->>RP: setActivityMetadata(...)
  Sheet->>HH: add(savedHike, userId)
  HH->>HH: write to local SharedPreferences
  HH->>DB: upsert hike_history
  HH->>RTS: saveFromHike(hike, userId)
  RTS->>DB: upload GPX to Storage
  RTS->>DB: upsert recorded_trails row
  RTS-->>HH: RecordedTrail
  HH-->>Sheet: HikeSaveResult { localSaved, supabaseSynced, trailUploaded }
  Sheet-->>U: snack (green/amber/red)
  Sheet->>RP: clear()
  RP->>RP: reset _startTime, _points, currentHikeId
  Sheet-->>U: sheet pops
```

## Components in this flow

- [[StartHikeRamp]] — pre-recording ritual
- [[recording_provider.dart]] — the state machine
- [[location_service.dart]] — Geolocator wrapper with Kalman smoothing
- [[TTMapScreen]] — primary recording surface (Map tab)
- [[FinishHikeSheet]] — Save / Discard / Resume sheet
- [[hike_history_provider.dart]] — local + cloud persistence
- [[recorded_trail_service.dart]] — GPX upload + metadata row
- [[team_tracking_provider.dart]] — live tracking publisher (concurrent)

## Tables involved

- [[hike_history]] — finished hike row with full points (jsonb)
- [[recorded_trails]] — promoted-for-sharing metadata
- [[team_member_locations]] (live latest position)
- [[team_member_track_points]] (full live trail)
- [[community_activities]] — `hike_completed` row (non-fatal post)

## Models

- [[RecordingPoint]] (per-fix)
- [[SavedHike]] (per-finished-hike)
- [[RecordedTrail]] (per-shareable trail)

## Critical invariants

- `RecordingProvider._startTime == null` ↔ recording is truly idle (post-`clear()` only). After STOP-then-START with the old buggy flow, this stayed set and grafted new points onto the dead session. Now [[FinishHikeSheet]] always calls `clear()` after Save or Discard.
- **`currentHikeId` is allocated once per session** at `start()` and reused for both the [[SavedHike]].id and the `team_member_track_points.hike_id`. Critical for the recovery worker [[finalize-orphan-hikes]] to match orphan rows.

## Failure modes + recovery

| Failure | Recovery |
|---|---|
| App crashes during recording | Draft persisted to SharedPreferences every 30s. On next launch [[recording_provider.dart]] `_restoreDraft` re-hydrates state as `paused`. User picks Resume or Discard via [[FinishHikeSheet]]. |
| User force-closes without saving | [[team_member_track_points]] rows still in DB. [[finalize-orphan-hikes]] cron picks them up after `stale_hours` and creates a [[recorded_trails]] row "Recovered hike YYYY-MM-DD". |
| Offline at save time | `HikeSaveResult.localSaved=true`, `supabaseSynced=false`. Snack says "Saved on device only — sign in to sync". |
| Save succeeds but trail upload fails | Partial success. Snack says "Synced to your account, but trail file failed to upload. The hourly recovery job will retry." |

## See also

- [[Workflow - Off-Trail Alert]] (parallel safety thread during recording)
- [[Workflow - Live Team Tracking]] (parallel team broadcast)
