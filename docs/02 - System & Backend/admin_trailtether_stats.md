---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/admin]
aliases: [public.admin_trailtether_stats]
source_paths: [supabase/migrations/20260526_admin_trailtether_rpcs.sql]
---

# admin_trailtether_stats

**RPC** `public.admin_trailtether_stats() returns jsonb` (SECURITY DEFINER, admin-only)

Single-row snapshot for the admin SPA's Trailtether tab top strip.

## Output

```json
{
  "total_users": 123,
  "total_teams": 8,
  "teams_with_members": 6,
  "hikes_total": 542,
  "hikes_30d": 41,
  "total_km": 1834.5,
  "total_ascent_m": 92480,
  "active_now": 3,
  "incidents_open": 2,
  "incidents_30d": 11
}
```

## Source tables

- `auth.users` (count), [[teams]], [[recorded_trails]], [[team_member_locations]] (active now), [[incidents]]

## Auth

Raises `42501` if `!is_admin()`.

## Sibling RPCs

- [[admin_trailtether_active_users]] — rows for the live map
- [[admin_trailtether_recent_hikes]]
- [[admin_trailtether_teams]]
- [[admin_trailtether_top_hikers]]

## Callers

- [[Hilltrek Admin Module]] Trailtether tab dashboard
