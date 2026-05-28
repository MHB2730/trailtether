---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/admin]
aliases: [public.admin_trailtether_recent_hikes]
source_paths: [supabase/migrations/20260526_admin_trailtether_rpcs.sql]
---

# admin_trailtether_recent_hikes

**RPC** `public.admin_trailtether_recent_hikes(p_days int default 30) returns setof <row>` (admin-only)

Returns recently-saved hikes from [[hike_history]], joined with [[profiles]] for the hiker name.

## Output

Per-row: hike_id, user name, photo, distance_km, ascent_m, started_at, activity_type, team_name.

## Auth

`is_admin()` gate.

## Callers

- [[Hilltrek Admin Module]] Trailtether tab recent-hikes list
