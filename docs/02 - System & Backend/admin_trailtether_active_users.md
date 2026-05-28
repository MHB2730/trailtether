---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/admin]
aliases: [public.admin_trailtether_active_users]
source_paths: [supabase/migrations/20260526_admin_trailtether_rpcs.sql]
---

# admin_trailtether_active_users

**RPC** `public.admin_trailtether_active_users(p_minutes int default 1440) returns setof <row>` (SECURITY DEFINER, admin-only)

Returns users with a [[team_member_locations]] row updated in the last N minutes. Drives the active-users live map in the admin SPA.

## Output (per row)

uid, name, photo_url, latitude, longitude, last_seen, status, team_name (joined).

## Auth

Raises `42501` if not admin.

## Callers

- [[Hilltrek Admin Module]] Trailtether tab → live map

## See also

- [[admin_trailtether_stats]]
