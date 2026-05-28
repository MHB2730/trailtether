---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/admin]
aliases: [public.admin_trailtether_top_hikers]
source_paths: [supabase/migrations/20260526_admin_trailtether_rpcs.sql]
---

# admin_trailtether_top_hikers

**RPC** `public.admin_trailtether_top_hikers(p_limit int default 20) returns setof <row>` (admin-only)

Leaderboard joining [[recorded_trails]] aggregations to [[profiles]] for display names.

## Output

Per-row: uid, name, photo, total_km, hike_count, last_hike_at.

## Auth

`is_admin()` gate.

## Callers

- [[Hilltrek Admin Module]] Hikers + Trailtether tabs
