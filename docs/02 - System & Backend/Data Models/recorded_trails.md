---
tags: [type/model, layer/db, status/stable, domain/recording]
aliases: [public.recorded_trails]
source_paths: []
---

# recorded_trails

User-promoted hike routes. When a user saves a hike via [[FinishHikeSheet]], a GPX file lands in Storage and a row lands here.

## Schema (key columns)

| Column | Type | Note |
|---|---|---|
| id | uuid PK | |
| hike_id | uuid | links to the recording session (same value as [[SavedHike]].id) |
| user_id | uuid → profiles.id | |
| team_id | uuid → teams.id (nullable) | |
| name | text | from `SavedHike.name` |
| description | text | |
| distance_km | numeric | |
| ascent_m, descent_m | integer | |
| duration_seconds | integer | |
| activity_type | text | hike / walk / run |
| point_count | integer | |
| min_lat, max_lat, min_lon, max_lon | numeric | bbox |
| gpx_path | text | Storage path like `<user_id>/<hike_id>.gpx` |
| thumbnail_path | text (nullable) | |
| sharing | text | private / team / public (see [[TrailSharing]] enum in [[RecordedTrail]] Dart model) |
| share_count, download_count | integer | |
| created_at, updated_at | timestamptz | |

## Constraints

- `UNIQUE (user_id, hike_id)` → upserts on save are idempotent

## CRUD locations

- **Created** by `RecordedTrailService.saveFromHike` from [[hike_history_provider.dart]] `.add()`
- **Read** by [[recorded_trails_provider.dart]] (`listMine`, `listCommunity`)
- **Updated** by `setSharing()` (private → team → public)
- **Deleted** by `RecordedTrailService.delete()`

## Storage

The GPX file at `gpx_path` lives in the `recorded-trails` bucket. Service-role write, public-read for `sharing = 'public'` rows (verify bucket policy in dashboard — see [[Known Issues]]).

## Triggers

`recorded_trails_touch_updated_at` — bumps updated_at on UPDATE.

## RPCs

- `increment_recorded_trail_downloads(p_id)` — soft-counter. **Not yet defined** — call site has graceful try/catch. See [[Known Issues]].

## Used by

- [[recorded_trails_provider.dart]]
- [[Workflow - Record Hike]]
- [[finalize-orphan-hikes]] (recovers orphan sessions into here)
