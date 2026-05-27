-- =====================================================================
-- Berg Live: lock direct access to the materialized views.
--
-- Resolves the `materialized_view_in_api` security advisor warnings
-- introduced by 20260527_berg_live_views_rpcs.sql.
--
-- The four anon RPCs (berg_pulse_stats, berg_pulse_active_count,
-- berg_pulse_leaderboard, berg_pulse_heatmap_cells) are SECURITY
-- DEFINER and execute as the function owner, so they keep working
-- regardless of role grants.  Revoking SELECT from anon /
-- authenticated / public on the underlying materialized views forces
-- all external access through the RPCs, which return a deliberately
-- trimmed subset of columns:
--
--   * berg_pulse_community_totals — RPC returns the 8 stat columns but
--     not `singleton` / `refreshed_at`
--   * berg_pulse_team_leaderboard — RPC returns the leaderboard
--     subset; full MV also includes raw rank columns
--   * berg_pulse_heatmap          — RPC returns only (lat_cell,
--     lon_cell, hikers); full MV also exposes `fixes` counts and
--     `last_seen` timestamps that we don't want to publish
--
-- Verified post-apply with curl:
--   /rest/v1/berg_pulse_community_totals  → 401 (anon)
--   /rest/v1/berg_pulse_team_leaderboard  → 401 (anon)
--   /rest/v1/berg_pulse_heatmap           → 401 (anon)
--   /rest/v1/rpc/berg_pulse_stats         → 200
--   /rest/v1/rpc/berg_pulse_active_count  → 200
--   /rest/v1/rpc/berg_pulse_leaderboard   → 200
--   /rest/v1/rpc/berg_pulse_heatmap_cells → 200
--
-- Applied via Supabase MCP on 2026-05-27.
-- =====================================================================

revoke all on public.berg_pulse_community_totals from public, anon, authenticated;
revoke all on public.berg_pulse_team_leaderboard from public, anon, authenticated;
revoke all on public.berg_pulse_heatmap          from public, anon, authenticated;
