---
tags: [type/model, layer/db, status/stable, domain/teams]
aliases: [public.teams]
source_paths: [supabase/migrations/20260527_berg_live_teams_consent.sql]
---

# teams

Team membership table. A team is a group of hikers with a shared invite code.

## Schema (key columns)

| Column | Type | Note |
|---|---|---|
| id | uuid PK | |
| name | text | |
| description | text | |
| owner_uid | uuid → profiles.id | |
| member_uids | uuid[] | denormalised array (also see `team_members` if exists) |
| invite_code | text | short code used by [[join_team_by_invite_code]] |
| is_public | bool | for Berg Live leaderboard — defaults false |
| public_display_name | text | optional override name for leaderboard |
| is_public_changed_at | timestamptz | audit trail |
| is_public_changed_by | uuid | audit trail |
| created_at, updated_at | timestamptz | |

`is_public_changed_*` audit columns added in `20260527_berg_live_teams_consent.sql` for POPIA §7 takedown.

## RLS

Members of a team can read it. Owner can update. Admin can do anything.

## Audit trigger

`teams_track_public_change()` fires on update of `is_public`, recording who flipped the flag + when.

## CRUD locations

- **Created/Updated** by [[team_provider.dart]] (create team, edit settings)
- **Read** by [[team_provider.dart]], [[team_tracking_provider.dart]] (for current team)
- **Join** via [[join_team_by_invite_code]] RPC
- **Member add/remove** via [[team_add_member]] / [[team_remove_member]] RPCs
- **Public toggle** via `admin_set_team_public` RPC (admin-only, see [[admin_trailtether_teams]])

## Relationships

- Referenced by [[team_member_locations]].team_id, [[team_member_track_points]].team_id, [[hike_history]].team_id, [[chat_messages]].team_id, [[community_activities]].team_id

## See also

- [[TTTeamScreen]] — mobile UI
- [[team_member_locations]] — live position table
- [[Workflow - Live Team Tracking]]
