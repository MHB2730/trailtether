---
tags: [type/model, layer/db, status/stable, domain/teams, domain/recording]
aliases: [public.team_member_track_points]
source_paths: []
---

# team_member_track_points

Every accepted GPS fix from a recording session, streamed live to the team. Append-only ledger.

## Schema (key columns)

| Column | Type | Note |
|---|---|---|
| uid | uuid | hiker |
| team_id | uuid → teams.id | |
| hike_id | uuid (nullable) | links to recorded_trails / hike_history |
| lat, lon, altitude | numeric | |
| timestamp | timestamptz | |
| accuracy | numeric | |
| created_at | timestamptz | server-side ingest time |

## CRUD locations

- **Inserted** by [[team_tracking_provider.dart]] — batched at 3s throttle, drained from offline queue when reconnected
- **Read** by [[MissionControlTab]] for per-hiker live route polylines (last 60 min)
- **Read** by [[finalize-orphan-hikes]] for orphan session recovery
- **Pruned** by `prune_stale_telemetry()` job

## Realtime

Subscribed by [[MissionControlTab]] — INSERT events append to the per-hiker `_liveTracks` polyline so the PC watcher sees the route extend in realtime.

## hike_id is often null

Live tracking starts BEFORE a hike_id is assigned (because [[recording_provider.dart]] doesn't generate the UUID until `start()` is fully through — and live tracking can begin in a pre-start "live track" mode). [[finalize-orphan-hikes]] groups by time-gap to reconstruct sessions in this case.

## See also

- [[team_member_locations]] (latest only — this is full history)
- [[Workflow - Live Team Tracking]]
- [[Workflow - Record Hike]]
