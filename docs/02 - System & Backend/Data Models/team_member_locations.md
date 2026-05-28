---
tags: [type/model, layer/db, status/stable, domain/teams, domain/realtime]
aliases: [public.team_member_locations]
source_paths: []
---

# team_member_locations

Last-known position per team member. One row per (team_id, uid). Updated every 3s (or when battery saver allows) by [[team_tracking_provider.dart]].

## Schema (key columns)

| Column | Type | Note |
|---|---|---|
| team_id | uuid → teams.id | |
| uid | uuid → profiles.id | |
| name | text | denormalised |
| photo_url | text | denormalised |
| latitude | numeric | |
| longitude | numeric | |
| altitude | numeric | |
| accuracy | numeric | metres |
| heading | numeric | degrees |
| speed | numeric | m/s |
| battery_pct | int | hiker's battery level |
| connectivity | text | wifi / cellular / offline |
| timestamp | timestamptz | last fix time |
| ghost_mode | bool | privacy flag |
| status | text | recording / arrived / departed / lost |

## Indexes

- `(team_id, uid)` unique
- `timestamp` for stale-data filtering

## CRUD locations

- **Upserted** by [[team_tracking_provider.dart]] every 3s during recording
- **Read** by [[MissionControlTab]] (live map) via Supabase Realtime channel
- **Read** by [[TTTeamScreen]] for per-member chips
- **Pruned** by `prune_old_locations()` cron job (clears rows >24h old)

## Realtime

Supabase Realtime channel `team_member_locations` is subscribed by [[MissionControlTab]] in `_setupRealtime`. INSERT/UPDATE events update the `_locations` map; UI redraws.

## Ghost mode

If `ghost_mode = true`, [[team_tracking_provider.dart]] doesn't publish position updates → teammates see stale data. See [[Workflow - Live Team Tracking]].

## See also

- [[team_member_track_points]] — full history (this table is just "latest")
- [[Workflow - Live Team Tracking]]
