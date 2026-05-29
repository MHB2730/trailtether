---
tags: [type/source, layer/frontend, domain/community]
aliases: [community_service]
source_paths: [trailtether_app/lib/services/community_service.dart]
---

# community_service.dart

`CommunityService` — fetches the global activity feed and team leaderboard.

## Key members

| Member | Role |
|---|---|
| `fetchActivities()` | `Future<List<CommunityActivity>>` — last 40 rows from `community_activities`, ordered by `timestamp` desc |
| `fetchLeaderboard()` | `Future<List<TeamLeaderboardStats>>` — calls the `berg_pulse_leaderboard` RPC |

## Tables / RPCs

- `community_activities` — `team_id` and `team_name` are nullable (solo hikes allowed since migration `20260529`)
- `berg_pulse_leaderboard` — materialized-view-backed RPC from [[Supabase Migrations Module]]

## Used by

- [[community_provider.dart]]
