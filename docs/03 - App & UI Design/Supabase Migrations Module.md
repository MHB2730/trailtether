---
tags: [type/module, layer/db, status/stable, domain/backend]
aliases: [Migrations]
source_paths: [supabase/migrations]
---

# Supabase Migrations Module

17 SQL migration files in `supabase/migrations/`, applied chronologically by filename. They build incrementally onto a base schema that predates this folder (an older `master_supabase_setup.sql` was deleted in cleanup — see [[Build & Deploy]]).

## How migrations land in production

Two paths:

1. **MCP** — `mcp__supabase__apply_migration` (used during this session for [[trails]] and edge function search_path fix)
2. **Supabase CLI** — `supabase db push` (older workflow)

> [!warning]
> Some tables exist in production but **don't appear** in any migration file (e.g. `profiles`, `teams`, `hike_history`, `recorded_trails`, `team_member_locations`, `chat_messages`, `reviews`). They were created by the deleted `master_supabase_setup.sql` or via direct dashboard SQL. The migrations folder is **incremental only** — not a fresh-install source. To bootstrap a fresh project, dump the live schema first.

## Migrations (oldest → newest)

| File | Purpose | Key objects created |
|---|---|---|
| `20260524_phase_b_orders.sql` | Merch checkout schema | `site_orders`, `site_order_items`; [[place_order]] + [[get_order_for_confirmation]] RPCs |
| `20260524_phase_c_payment_events.sql` | Payment audit log | `site_payment_events` |
| `20260526_admin_trailtether_rpcs.sql` | Admin SPA Trailtether tab | [[admin_trailtether_stats]], [[admin_trailtether_active_users]], [[admin_trailtether_top_hikers]], `admin_trailtether_recent_hikes`, [[admin_trailtether_teams]] RPCs |
| `20260526_advisor_cleanup.sql` | Security hardening | Function search_path locks; EXECUTE revokes |
| `20260526_apk_download_gate.sql` | APK download audit | `apk_downloads` table |
| `20260526_cron_secret_to_vault.sql` | Secrets hygiene | Moves `cron_secret` from `site_settings` row → `vault.secrets`; rewrites pg_cron jobs to use vault |
| `20260526_finalize_orphan_hikes_cron.sql` | Cron wiring | Hourly pg_cron job calling [[finalize-orphan-hikes]] |
| `20260526_profiles_pii_lockdown.sql` | POPIA profiles RLS | `profiles_public` view; [[profiles_public]] RPC; tightened RLS (owner + admin only) |
| `20260527_berg_live_admin_kill_switch.sql` | POPIA §7 takedown | `admin_set_team_public()` RPC; [[admin_trailtether_teams]] kill-switch column |
| `20260527_berg_live_lockdown_materialized_views.sql` | MV access control | Revokes SELECT on MVs from anon/authenticated — forces access through SECURITY DEFINER RPCs |
| `20260527_berg_live_teams_consent.sql` | Berg Live opt-in | Adds `is_public`, `public_display_name`, consent columns to `teams`; `teams_track_public_change()` trigger |
| `20260527_berg_live_views_rpcs.sql` | `/pulse/` leaderboard | `berg_pulse_community_totals/team_leaderboard/heatmap` MVs; [[berg_pulse_stats]], [[berg_pulse_leaderboard]], `berg_pulse_active_count`, `berg_pulse_heatmap_cells` RPCs |
| `20260527_curated_trails_table.sql` | Trail catalogue CRUD | `trails` table + RLS + `touch_trails_updated_at()` trigger |
| `20260528_recorded_trail_downloads_rpc.sql` | Download counter | `increment_recorded_trail_downloads(trail_id)` RPC |
| `20260528_storage_rls_policies.sql` | Storage RLS documentation | Living doc of 31 RLS policies across 6 storage buckets (app-releases, recorded-trails, gpx-uploads, incident-photos, profile-photos, website-assets) — verified in production |
| `20260529_community_activities_team_nullable.sql` | Solo-activity fix | Makes `team_id` + `team_name` nullable in `community_activities` so solo hikes can save without a team |
| `20260529_fix_download_rpc_search_path.sql` | RPC security | Fixes `search_path` on `increment_recorded_trail_downloads` (security advisor followup from [[Audit Findings]]) |

## RPCs not in migrations folder

These exist in production but predate the migrations folder or were applied via dashboard:

`is_admin`, `place_order`, `subscriber_signup`, `subscriber_confirm`, `subscriber_unsubscribe`, `handle_new_user`, `team_add_member`, `team_remove_member`, `join_team_by_invite_code`, `claim_tether_token`, `verify_incident`, `flag_incident`, `mark_notification_read`, `app_release_meta`, `ping_safety_plan`, `on_hike_saved`, `prune_old_locations`.

## Conventions

- All migrations use `if not exists` / `or replace` for idempotency.
- Trigger functions locked with `set search_path = public, pg_temp`.
- RLS-enabled tables get explicit policy creation per role; `is_admin()` pattern handles admin gating.

## Depends on

- `public.is_admin()` — predates migration folder
- `vault.secrets` for `cron_secret`

## Used by

- [[Trailtether App Module]] — every table read/write
- [[Hilltrek Site Module]] — public RPCs
- [[Hilltrek Admin Module]] — admin RPCs
- [[Supabase Functions Module]] — service-role queries
