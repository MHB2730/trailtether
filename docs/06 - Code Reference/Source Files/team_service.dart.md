---
tags: [type/source, layer/frontend, domain/teams]
aliases: [team_service]
source_paths: [trailtether_app/lib/services/team_service.dart]
---

# team_service.dart

`TeamService` — all Supabase calls related to teams.

## Key members

| Member | Role |
|---|---|
| `fetchTeamsForUser(uid)` | `Future<List<Team>>` — teams where `member_uids` contains `uid`, ordered newest first |
| `createTeam(name, uid)` | `Future<Team?>` — inserts a new team row, adds creator as first member |
| `generateInviteCode(teamId)` | `Future<String?>` — generates and stores a random 6-char invite code |
| `joinByCode(code, uid)` | `Future<bool>` — calls `join_team_by_invite_code` RPC |
| `leaveTeam(teamId, uid)` | `Future<void>` — removes `uid` from `member_uids` array |
| `deleteTeam(teamId)` | `Future<void>` — deletes team (owner only) |

## Tables / RPCs

- `teams` table — `kColTeams` constant from [[constants.dart]]
- `join_team_by_invite_code` RPC — secure server-side invite validation

## Used by

- [[team_provider.dart]]
