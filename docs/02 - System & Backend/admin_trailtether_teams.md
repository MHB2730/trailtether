---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/admin]
aliases: [public.admin_trailtether_teams, admin_set_team_public]
source_paths: [supabase/migrations/20260527_berg_live_admin_kill_switch.sql]
---

# admin_trailtether_teams

**RPC** `public.admin_trailtether_teams() returns setof <row>` (admin-only)

Lists all teams + their `is_public` flag + member count for the POPIA admin kill-switch view.

## Output

Per-row: team_id, name, member_count, owner_email, is_public, public_display_name, is_public_changed_at, is_public_changed_by.

## Sibling RPC: `admin_set_team_public(p_team_id uuid, p_is_public boolean, p_display_name text)`

Lets an admin force a team off the public Berg Live leaderboard (or re-enable). Updates [[teams]] and is audited via the `teams_track_public_change()` trigger.

## Auth

Both `is_admin()` gated.

## Callers

- [[Hilltrek Admin Module]] Trailtether tab — team management section
