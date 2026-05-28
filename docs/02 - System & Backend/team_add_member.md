---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/teams]
aliases: [public.team_add_member]
source_paths: []
---

# team_add_member

**RPC** `public.team_add_member(p_team_id uuid, p_member jsonb) returns jsonb` (SECURITY DEFINER)

Owner-only: add a member to a team without going through the invite-code flow. See [[join_team_by_invite_code]] for the user-initiated path.

## Auth

Owner of the team (uid match against `teams.owner_uid`).

## Callers

- [[team_provider.dart]]
