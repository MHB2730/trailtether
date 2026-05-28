---
tags: [type/endpoint, layer/backend, status/stable, domain/recording]
aliases: [finalize-orphan-hikes edge function]
source_paths: [supabase/functions/finalize-orphan-hikes/index.ts]
---

# finalize-orphan-hikes

**POST** `/functions/v1/finalize-orphan-hikes` (called by pg_cron hourly)

Recovers recording sessions that never called save. App crashes, flat batteries, "never tapped save" — points sit in [[team_member_track_points]] without a parent [[recorded_trails]] row. This function reconstructs them.

## Auth

`verify_jwt: false` — `X-Cron-Secret` header check.

## Request body (optional overrides)

```json
{
  "gap_minutes": 60,   // >60min between fixes = session boundary
  "stale_hours": 6,    // wait this long after session end
  "min_points": 5,     // skip sessions shorter than this
  "lookback_days": 30  // don't re-process ancient orphans
}
```

## Algorithm

1. SELECT track points within lookback window (ordered by uid, then timestamp)
2. Group by uid
3. Within each uid's points, detect session boundaries by time-gap (>gap_minutes between consecutive)
4. For each session ending >stale_hours ago AND not already in [[recorded_trails]]:
   - Compute bbox, distance (haversine), ascent/descent, duration
   - Generate GPX
   - Upload to `recorded-trails` Storage bucket
   - INSERT [[recorded_trails]] row tagged "Recovered hike YYYY-MM-DD"
5. Use synthesized hike_id per session (since track points often have null hike_id at start of recording)

## Idempotency

Pre-check: skip if a [[recorded_trails]] row already exists for `(user_id, hike_id)`. The synthesized hike_id is deterministic per session, so re-runs don't duplicate.

## Side effects

- New [[recorded_trails]] rows
- New GPX files in `recorded-trails` Storage bucket
- Audit log via [[logger_service.dart]] (or edge function console)

## Cron schedule

Hourly at minute 17 (per `20260526_finalize_orphan_hikes_cron.sql`).
