---
tags: [type/module, layer/db, status/stable, domain/backend]
aliases: [Migrations]
source_paths: [supabase/migrations]
---

# Supabase Migrations Module

13 SQL migration files in `supabase/migrations/`, applied chronologically by filename. They build incrementally onto a base schema that predates this folder (an older `master_supabase_setup.sql` was deleted in cleanup — see [[Build & Deploy]]).

## How migrations land in production

Two paths:

1. **MCP** — `mcp__supabase__apply_migration` (used during this session for [[trails]] and edge function search_path fix)
2. **Supabase CLI** — `supabase db push` (older workflow)

> [!warning] Verify
> Some tables exist in production but **don't appear** in any migration file in `supabase/migrations/` (e.g. [[profiles]], [[teams]], [[hike_history]], [[recorded_trails]], [[team_member_locations]], [[team_member_track_points]], [[chat_messages]], [[posts]], [[notifications]], [[reviews]]). They were created by the deleted `master_supabase_setup.sql` or via direct dashboard SQL. The migrations folder is **incremental only** — not a fresh-install source. To bootstrap, dump the live schema first.

## Migrations (oldest → newest)

| File | Creates | Purpose |
|---|---|---|
| `20260524_phase_b_orders.sql` | [[site_orders]], [[site_order_items]], `site_order_line_variants` tables; [[place_order]] + [[get_order_for_confirmation]] RPCs; `touch_updated_at()` trigger | Merch checkout schema |
| `20260524_phase_c_payment_events.sql` | [[site_payment_events]] audit table | Audit log for every PayFast/Yoco/Zapper callback (valid or invalid signature) |
| `20260526_admin_trailtether_rpcs.sql` | [[admin_trailtether_stats]], [[admin_trailtether_active_users]], [[admin_trailtether_top_hikers]] (+ recent_hikes + teams) | Admin SPA's Trailtether tab |
| `20260526_advisor_cleanup.sql` | (function search_path locks, EXECUTE revokes) | Security advisor cleanup |
| `20260526_apk_download_gate.sql` | [[apk_downloads]] table | Gated APK download tracking (T&Cs + Turnstile audit) |
| `20260526_cron_secret_to_vault.sql` | Vault secret + pg_cron job rewrite | Move `cron_secret` from world-readable `site_settings` row to `vault.secrets` |
| `20260526_finalize_orphan_hikes_cron.sql` | pg_cron job entry | Hourly call to [[finalize-orphan-hikes]] edge function |
| `20260526_profiles_pii_lockdown.sql` | `profiles_public` view, [[profiles_public]] RPC, [[profiles]] RLS policy replacement | Tighten profiles access (owner + admin only; public-safe fields exposed via view) |
| `20260527_berg_live_admin_kill_switch.sql` | [[admin_trailtether_teams]], `admin_set_team_public()` | Admin RPC to toggle team public visibility (POPIA §7 takedown) |
| `20260527_berg_live_lockdown_materialized_views.sql` | (revokes SELECT on MVs from anon/authenticated) | Force MV access through SECURITY DEFINER RPCs only |
| `20260527_berg_live_teams_consent.sql` | [[teams]] columns added (is_public, public_display_name, …); `teams_track_public_change()` trigger | Opt-in for public leaderboard + audit trail |
| `20260527_berg_live_views_rpcs.sql` | `berg_pulse_community_totals` / `berg_pulse_team_leaderboard` / `berg_pulse_heatmap` MVs; [[berg_pulse_stats]] / [[berg_pulse_leaderboard]] / `berg_pulse_active_count` / `berg_pulse_heatmap_cells` RPCs | Hilltrek `/pulse/` leaderboard backend |
| `20260527_curated_trails_table.sql` | [[trails]] table + RLS + `touch_trails_updated_at()` trigger | Curated catalogue editor backend |

## RPC ownership

| RPC | Defined in migration |
|---|---|
| [[place_order]], [[get_order_for_confirmation]] | `20260524_phase_b_orders.sql` |
| Admin Trailtether tab RPCs | `20260526_admin_trailtether_rpcs.sql` |
| [[berg_pulse_stats]], [[berg_pulse_leaderboard]], `berg_pulse_active_count`, `berg_pulse_heatmap_cells` | `20260527_berg_live_views_rpcs.sql` |
| `admin_set_team_public`, [[admin_trailtether_teams]] | `20260527_berg_live_admin_kill_switch.sql` |
| `touch_trails_updated_at` | `20260527_curated_trails_table.sql` |
| `is_admin`, `place_order`, [[subscriber_signup]], [[subscriber_confirm]], [[subscriber_unsubscribe]], [[handle_new_user]], [[team_add_member]], [[team_remove_member]], [[join_team_by_invite_code]], [[claim_tether_token]], [[verify_incident]], [[flag_incident]], `increment_flag_count`, [[mark_notification_read]], `find_profile_by_username`, `is_username_available`, `app_release_meta`, `sync_team_hike_stats`, `ping_safety_plan`, `on_hike_saved`, `prune_old_locations`, `prune_stale_telemetry`, `purge_old_analytics_and_health`, `audit_table_change` | **Not in `supabase/migrations/`** — predate the folder or applied via dashboard |

## Conventions

- All migrations use `if not exists` / `or replace` for idempotency
- Trigger functions are locked with `set search_path = public, pg_temp` (per [[Audit Findings]] cleanup)
- RLS-enabled tables get explicit policy creation per role; the `is_admin()` pattern handles admin gating

## Depends on

- `public.is_admin()` (defined elsewhere, predates migration folder)
- `public.set_updated_at()` / `touch_updated_at()` triggers
- Vault for the `cron_secret`

## Used by

- [[Trailtether App Module]] — every table read/write
- [[Hilltrek Site Module]] — public RPCs
- [[Hilltrek Admin Module]] — admin RPCs
- [[Supabase Functions Module]] — service-role queries
