---
tags: [type/workflow, layer/frontend, status/stable, domain/teams, domain/realtime]
aliases: [Live tracking flow, Team tracking]
source_paths: [trailtether_app/lib/providers/team_tracking_provider.dart, trailtether_app/lib/screens/admin/mission_control_tab.dart, trailtether_app/lib/services/offline_track_queue.dart]
---

# Workflow - Live Team Tracking

Mobile hiker → Supabase Realtime → PC watcher in [[MainPcShell]]. Concurrent with [[Workflow - Record Hike]] — the same GPS stream feeds both.

```mermaid
sequenceDiagram
  participant RP as RecordingProvider (mobile)
  participant TT as TeamTrackingProvider (mobile)
  participant Q as OfflineTrackQueue
  participant DB as Supabase
  participant RT as Realtime channel
  participant MC as MissionControlTab (PC)

  RP->>TT: notify (each accepted GPS fix)
  alt online + not ghost mode
    TT->>DB: upsert team_member_locations (latest position)
    TT->>DB: insert team_member_track_points (history)
    DB->>RT: broadcast INSERT/UPDATE
  else offline OR ghost mode
    TT->>Q: enqueue track point JSON
  end

  Note over Q: User goes offline → back online
  TT->>TT: connectivity listener fires
  TT->>Q: drainAll()
  Q-->>TT: queued points[]
  TT->>DB: batch insert
  alt insert fails
    TT->>Q: reenqueue
  end

  Note over MC: PC watcher
  MC->>RT: subscribe to team_member_locations + team_member_track_points + incidents
  RT-->>MC: realtime events
  MC->>MC: update _locations map + _liveTracks polyline per uid
  MC-->>MC: redraw map + "Nm ago" labels every 30s
```

## Components

- [[team_tracking_provider.dart]] — the mobile-side publisher
- [[offline_track_queue.dart]] — SharedPreferences-backed FIFO buffer (4000 cap)
- [[MissionControlTab]] — the PC-side subscriber + renderer
- [[recording_provider.dart]] — emits fixes (the source)

## Tables

- [[team_member_locations]] — latest position per (team, uid) — upsert, 3s throttle
- [[team_member_track_points]] — full history (append-only)
- Both pruned by `prune_old_locations()` / `prune_stale_telemetry()` cron jobs

## Ghost mode

When the user toggles ghost mode via [[recording_provider.dart]] `toggleGhostMode()`, `team_tracking_provider.dart` stops publishing. Teammates see stale data — no "left the room" notification. Reversible.

## Battery saver

Reduces publish frequency from 3s to 30s + uses `LocationAccuracy.medium`. Recording itself becomes less precise; team broadcasts also become less frequent.

## Failure modes

- **Offline drain failure**: queue re-enqueued. Retries on next connectivity tick.
- **Queue overflow**: 4000-item cap. Oldest dropped to make room.
- **Realtime channel disconnect**: [[MissionControlTab]] auto-reconnects via Supabase's built-in retry.

## Privacy

- Locations only visible to team members (RLS filters by `team_id` membership)
- Berg Live public leaderboard / heatmap requires opt-in per [[teams]].`is_public` — separate gate from team-internal tracking

## See also

- [[Workflow - Record Hike]] (the shared source of GPS fixes)
- [[Workflow - Auth]] (team membership required to be visible)
