---
tags: [type/model, layer/db, status/stable, domain/trails]
aliases: [public.gpx_uploads]
source_paths: []
---

# gpx_uploads

User-submitted GPX files (separate from the curated [[trails]] catalogue). Came from `admin_trails_tab.dart` (now deleted) but the underlying pipeline still ingests from mobile via [[gpx_service.dart]].

## Schema (key columns)

| Column | Type | Note |
|---|---|---|
| id | uuid PK | |
| user_id | uuid → profiles.id | |
| filename | text | original .gpx filename |
| display_name | text | admin-editable |
| description | text | |
| difficulty | text | |
| file_path | text | Storage path in `gpx_uploads` bucket |
| point_count | int | |
| distance_km, elevation_gain_m | numeric | derived at upload |
| created_at | timestamptz | |

## CRUD locations

- **Uploaded** by [[gpx_service.dart]] `pickAndParse()` → `upload()` (parses XML, writes to Storage, inserts row)
- **Read** by [[gpx_provider.dart]] `syncWithCloud()` — pulls all rows + downloads bytes
- **Read** by [[MissionControlTab]] (admin overlay)
- **Updated/Deleted** — was done via the deleted `admin_trails_tab.dart`; no current UI

## Relationship to `trails`

These two tables are **separate**:
- [[trails]] = curated catalogue (admin authoritative, RLS-gated)
- `gpx_uploads` = user-submitted (each user uploads their own, visible to admin)

The newer flow is to promote a user upload into [[recorded_trails]] (private) or into [[trails]] (curated). `gpx_uploads` is the raw landing zone.

> [!warning] Verify
> No current UI for editing or deleting `gpx_uploads` rows after `admin_trails_tab.dart` was removed. Cleanup may need a new admin surface or RPC.

## Used by

- [[gpx_service.dart]], [[gpx_provider.dart]]
- [[MissionControlTab]] (renders user GPX overlays)
