---
tags: [type/model, layer/db, status/stable, domain/trails]
aliases: [public.trails, curated trails]
source_paths: [supabase/migrations/20260527_curated_trails_table.sql]
---

# trails

The curated trail catalogue. Hilltrek-authored trails (vs. user-recorded routes which live in [[recorded_trails]]).

## Schema

| Column | Type | Note |
|---|---|---|
| id | text PK | string slug like `hc_to_aasvoelkrans_cave` |
| name | text | display name (normalized at load time by [[trail_service.dart]]) |
| description | text | |
| difficulty | text CHECK | Easy / Moderate / Challenging / Hard / Extreme |
| category | text CHECK | hike / cave / peak / circular / scramble |
| distance_km | numeric | |
| elevation_gain_m | integer | |
| elevation_descent_m | integer | |
| est_time_hours | numeric | |
| min_ele, max_ele | integer | |
| coords | jsonb | array of `[lon, lat, ele]` triples |
| min_lat, max_lat, min_lon, max_lon | numeric | pre-computed bbox |
| published | bool | default true |
| created_at, updated_at | timestamptz | |
| created_by | uuid → auth.users.id | |

## Indexes

- `lower(name)` for search
- `category`
- `published`
- `(min_lat, max_lat, min_lon, max_lon)` for viewport queries

## RLS

| Role | SELECT | INSERT/UPDATE/DELETE |
|---|---|---|
| anon / authenticated | only where `published = true` | — |
| admin (via [[is_admin]]) | all rows | all rows |

## CRUD locations

- **Seeded** from `assets/data/routes_cleaned.json` via `TrailRepository.seedFromBundle()` (idempotent, callable from [[PcTrailsScreen]])
- **Read** by [[trail_service.dart]] (cached in [[static_data_provider.dart]])
- **Edited / added / deleted** by [[trail_repository.dart]] via [[PcTrailsScreen]] (admin-only via RLS)

## Triggers

`touch_trails_updated_at()` — bumps `updated_at` on every UPDATE. Locked search_path.

## Operational state (2026-05-29)

- **Seeded + deduped to 197 unique routes.** The table sat *empty* after the migration; while empty, [[trail_service.dart]] silently falls back to the read-only bundled JSON, so the app showed trails but edits/deletes hit nonexistent DB rows and appeared to do nothing. Seed first (PC → "Seed from bundle"), then edits persist.
- **Duplicate gotcha:** `routes_cleaned.json` carries ~29 routes *twice* — a clean underscore-id entry (`hc_to_caracal_cave` → "Caracal Cave via Highmoor") and a raw hyphen-id twin (`hc-to-caracal-cave` → "Caracal Cave via Hc"). Distinct ids → the idempotent seed inserts both. The redundant twins were deleted (233 → 197), but **re-running "Seed from bundle" reintroduces them** until the bundle asset is cleaned.

## Relationships

- Referenced by [[hike_history]].trail_id, [[recorded_trails]].benchmark_route_id (when a recorded hike matches a curated trail)

## See also

- [[Workflow - Trails CRUD]]
- [[Trail Model]] — Dart class
- [[trail_repository.dart]] — service layer
- [[trail_service.dart]] — Supabase → cache → bundle fallback loader
