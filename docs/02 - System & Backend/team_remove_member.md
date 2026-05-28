---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/teams]
aliases: [public.team_remove_member]
source_paths: []
---

# team_remove_member

**RPC** `public.team_remove_member(p_team_id uuid, p_member_uid text) returns jsonb` (SECURITY DEFINER)

Owner-only: remove a member from a team.

## Auth

Caller's uid must match `teams.owner_uid`.

## Callers

- [[team_provider.dart]] (admin / owner editing UI)
