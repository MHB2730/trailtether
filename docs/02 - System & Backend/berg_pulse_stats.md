---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/community]
aliases: [public.berg_pulse_stats, berg_pulse_active_count, berg_pulse_heatmap_cells]
source_paths: [supabase/migrations/20260527_berg_live_views_rpcs.sql]
---

# berg_pulse_stats (+ siblings)

Family of SECURITY DEFINER RPCs powering the **/pulse/ page** on hilltrek.co.za — the Berg Live community leaderboard.

## RPCs

| RPC | Returns | Purpose |
|---|---|---|
| `berg_pulse_stats()` | jsonb | Single-row stats: total_km, total_hikers, total_ascent_m, total_hikes_30d |
| `berg_pulse_active_count()` | int | Live count of hikers active in last X minutes |
| `berg_pulse_heatmap_cells(p_min_lat, p_max_lat, p_min_lon, p_max_lon)` | setof | Hex-binned heatmap cells (≥3 hikers per cell) within bbox |
| [[berg_pulse_leaderboard]] | setof | Team / individual rankings |

## Materialized views (backing)

- `berg_pulse_community_totals` — 30d + all-time stats
- `berg_pulse_team_leaderboard` — only `is_public=true` teams
- `berg_pulse_heatmap` — hex-binned tracks (k-anonymity ≥3)

## Refresh schedule

15min + nightly via pg_cron (per migration).

## Auth

`SECURITY DEFINER` — anon-callable. Direct SELECT on the MVs is **revoked** from anon/authenticated (forces access through these RPCs which return only safe columns).

## Privacy

`is_public=false` teams excluded from leaderboard. Heatmap requires ≥3 hikers per cell (k-anonymity).

## Callers

- `hilltrek-site/pulse/index.html`

## See also

- [[teams]] `is_public` column
- [[admin_trailtether_teams]] for admin kill switch
