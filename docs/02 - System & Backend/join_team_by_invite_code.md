---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/teams]
aliases: [public.join_team_by_invite_code, team_add_member, team_remove_member]
source_paths: []
---

# join_team_by_invite_code (+ team_add_member + team_remove_member)

Team membership RPCs. Authenticated.

## join_team_by_invite_code

`public.join_team_by_invite_code(p_invite_code text, p_member jsonb) returns jsonb`

User-facing: scan/enter invite code → joins the team. Validates code exists, adds caller's uid + member metadata to [[teams]].member_uids.

## team_add_member

`public.team_add_member(p_team_id uuid, p_member jsonb) returns jsonb`

Owner-only: add a known user to a team without an invite code.

## team_remove_member

`public.team_remove_member(p_team_id uuid, p_member_uid text) returns jsonb`

Owner-only: remove a member.

## Auth

All three check the caller's uid against [[teams]].owner_uid (for add/remove) or simply add caller (for join_by_code).

## Callers

- [[team_provider.dart]] (`createTeam`, `joinByCode`, member edit)
- [[TTTeamScreen]]
