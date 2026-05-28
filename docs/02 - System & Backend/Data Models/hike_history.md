---
tags: [type/model, layer/db, status/stable, domain/recording]
aliases: [public.hike_history]
source_paths: []
---

# hike_history

Per-user completed hikes table. One row per saved recording, includes the full point list as JSONB.

## Schema (key columns)

| Column | Type | Note |
|---|---|---|
| user_id | uuid → profiles.id | |
| team_id | uuid → teams.id (nullable) | |
| trail_id | text → trails.id (nullable) | benchmark trail if recorded against one |
| name | text | |
| distance_km | numeric | |
| ascent_m | integer | |
| peaks_climbed | integer | |
| duration_seconds | integer | |
| activity_type | text | hike / walk / run |
| activity_context | text | personal / team / training |
| avg_accuracy_m, best_accuracy_m, worst_accuracy_m | numeric | GPS quality |
| accepted_fixes, rejected_fixes | integer | |
| points | jsonb | full point list — `[{lat, lon, alt, ts, spd, acc}, ...]` |
| created_at | timestamptz | (= startedAt) |

## Trigger

`_set_hike_history_score` calls `_compute_hike_score(avg_accuracy_m, accepted_fixes, rejected_fixes)` on insert/update to populate a quality score. `sync_team_hike_stats()` + `on_hike_saved()` triggers also fire.

## CRUD locations

- **Created** by `HikeHistoryProvider.syncToSupabase(hike, userId)` in [[hike_history_provider.dart]]
- **Read** by [[hike_history_provider.dart]] `load()` (Supabase sync) + local SharedPreferences mirror
- **Updated/Deleted** — currently no UI for these

## Difference from `recorded_trails`

| Concern | `hike_history` | `recorded_trails` |
|---|---|---|
| Granularity | Every saved hike | Only ones promoted for sharing |
| Storage | Full points in jsonb column | Points in Storage GPX file |
| Visibility | Owner + admin | Configurable (private/team/public) |

A saved hike writes to **both** — `hike_history` first (always), then `recorded_trails` (if not skipped). [[hike_history_provider.dart]] `add()` does both in sequence.

## Used by

- [[hike_history_provider.dart]]
- [[TTProfileScreen]] (lifetime stats aggregation)
- [[admin_trailtether_recent_hikes]], [[admin_trailtether_stats]] RPCs
- [[finalize-orphan-hikes]] reads orphan track points but writes to `recorded_trails` (not `hike_history`)
