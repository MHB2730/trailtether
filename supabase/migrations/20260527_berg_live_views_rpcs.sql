-- =====================================================================
-- Berg Live: aggregate materialized views, RPCs, and pg_cron refresh
-- schedules powering hilltrek.co.za/pulse/.
--
-- Three materialized views — all designed so the rows are aggregate-only
-- (no PII) and the RPCs can safely be granted to anon:
--
--   berg_pulse_community_totals  Single-row totals (30d + all-time).
--                                Refreshed every 15 min via pg_cron.
--   berg_pulse_team_leaderboard  Per-team stats for teams where the
--                                creator opted in (is_public=true).
--                                Refreshed nightly (02:17 UTC).
--   berg_pulse_heatmap           ~50m hex bins of team_member_track_points,
--                                only cells with ≥3 distinct hikers.
--                                Refreshed nightly (02:37 UTC).
--
-- Plus berg_pulse_active_count() — live function returning the count of
-- users whose locations updated in the last 30 minutes.
--
-- See docs/design/the-berg-live.md §7 for the spec.
-- Applied via Supabase MCP on 2026-05-27.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Community totals (single row)
-- ---------------------------------------------------------------------
drop materialized view if exists public.berg_pulse_community_totals cascade;
create materialized view public.berg_pulse_community_totals as
with last30 as (
  select * from public.recorded_trails where created_at > now() - interval '30 days'
)
select
  (select count(*) from last30)::int                                          as hikes_30d,
  (select count(distinct user_id) from last30)::int                           as hikers_30d,
  (select count(distinct team_id) filter (where team_id is not null) from last30)::int as teams_active_30d,
  (select coalesce(round(sum(distance_km)::numeric, 1), 0) from last30)       as km_30d,
  (select coalesce(sum(ascent_m), 0) from last30)::bigint                     as ascent_m_30d,
  (select count(*) from public.recorded_trails)::int                          as hikes_total,
  (select coalesce(round(sum(distance_km)::numeric, 1), 0) from public.recorded_trails) as km_total,
  (select coalesce(sum(ascent_m), 0) from public.recorded_trails)::bigint     as ascent_m_total,
  now()                                                                       as refreshed_at,
  1                                                                           as singleton;

create unique index if not exists berg_pulse_community_totals_pk
  on public.berg_pulse_community_totals (singleton);

-- ---------------------------------------------------------------------
-- 2. Public team leaderboard (only is_public=true teams)
-- ---------------------------------------------------------------------
drop materialized view if exists public.berg_pulse_team_leaderboard cascade;
create materialized view public.berg_pulse_team_leaderboard as
select
  t.id                                                  as team_id,
  t.public_display_name                                 as team_name,
  coalesce(array_length(t.member_uids, 1), 0)           as member_count,
  coalesce(ts.total_km, 0)                              as total_km,
  coalesce(ts.total_ascent, 0)                          as total_ascent_m,
  coalesce(ts.peaks_climbed, 0)                         as peaks_climbed,
  rank() over (order by coalesce(ts.total_km, 0) desc)      as rank_by_km,
  rank() over (order by coalesce(ts.total_ascent, 0) desc)  as rank_by_ascent,
  rank() over (order by coalesce(ts.peaks_climbed, 0) desc) as rank_by_peaks
from public.teams t
left join public.team_stats ts on ts.team_id = t.id
where t.is_public = true
  and t.public_display_name is not null;

create unique index if not exists berg_pulse_team_leaderboard_pk
  on public.berg_pulse_team_leaderboard (team_id);

-- ---------------------------------------------------------------------
-- 3. Heatmap hex cells
-- Bin every track point in the last 12 months into ~50m cells; only
-- cells with ≥3 distinct hikers survive (min-N=3 threshold defined in
-- design doc §11 Q3 — privacy floor, can tighten to 5 later).
-- ---------------------------------------------------------------------
drop materialized view if exists public.berg_pulse_heatmap cascade;
create materialized view public.berg_pulse_heatmap as
select
  round(lat::numeric * 2200) / 2200 as lat_cell,
  round(lon::numeric * 1820) / 1820 as lon_cell,
  count(distinct uid)::int          as hikers,
  count(*)::int                     as fixes,
  max(timestamp)                    as last_seen
from public.team_member_track_points
where timestamp > now() - interval '12 months'
  and lat is not null and lon is not null
group by 1, 2
having count(distinct uid) >= 3;

create unique index if not exists berg_pulse_heatmap_pk
  on public.berg_pulse_heatmap (lat_cell, lon_cell);
create index if not exists berg_pulse_heatmap_lat_lon
  on public.berg_pulse_heatmap (lat_cell, lon_cell);

-- ---------------------------------------------------------------------
-- 4. RPCs — public-safe, anon-callable, locked search_path
-- ---------------------------------------------------------------------

create or replace function public.berg_pulse_stats()
returns jsonb
language sql security definer
set search_path = public, pg_temp
stable
as $$
  select to_jsonb(t) from public.berg_pulse_community_totals t limit 1;
$$;
revoke all on function public.berg_pulse_stats() from public;
grant execute on function public.berg_pulse_stats() to anon, authenticated, service_role;

create or replace function public.berg_pulse_active_count()
returns int
language sql security definer
set search_path = public, pg_temp
stable
as $$
  select count(distinct uid)::int
  from public.team_member_locations
  where timestamp > now() - interval '30 minutes';
$$;
revoke all on function public.berg_pulse_active_count() from public;
grant execute on function public.berg_pulse_active_count() to anon, authenticated, service_role;

create or replace function public.berg_pulse_leaderboard(
  p_metric text default 'km',
  p_limit  int  default 25
)
returns setof public.berg_pulse_team_leaderboard
language plpgsql security definer
set search_path = public, pg_temp
stable
as $$
declare
  lim int := greatest(1, least(coalesce(p_limit, 25), 200));
begin
  if p_metric = 'ascent' then
    return query select * from public.berg_pulse_team_leaderboard order by rank_by_ascent limit lim;
  elsif p_metric = 'peaks' then
    return query select * from public.berg_pulse_team_leaderboard order by rank_by_peaks limit lim;
  else
    return query select * from public.berg_pulse_team_leaderboard order by rank_by_km limit lim;
  end if;
end;
$$;
revoke all on function public.berg_pulse_leaderboard(text, int) from public;
grant execute on function public.berg_pulse_leaderboard(text, int) to anon, authenticated, service_role;

create or replace function public.berg_pulse_heatmap_cells(
  p_min_lat numeric default -32,
  p_max_lat numeric default -27,
  p_min_lon numeric default  27,
  p_max_lon numeric default  31
)
returns table (lat_cell numeric, lon_cell numeric, hikers int)
language sql security definer
set search_path = public, pg_temp
stable
as $$
  select lat_cell, lon_cell, hikers
  from public.berg_pulse_heatmap
  where lat_cell between p_min_lat and p_max_lat
    and lon_cell between p_min_lon and p_max_lon
  limit 5000;
$$;
revoke all on function public.berg_pulse_heatmap_cells(numeric, numeric, numeric, numeric) from public;
grant execute on function public.berg_pulse_heatmap_cells(numeric, numeric, numeric, numeric)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 5. pg_cron schedules for the materialized view refreshes
-- ---------------------------------------------------------------------

select cron.unschedule(jobid) from cron.job
  where jobname in ('berg-pulse-totals-15min', 'berg-pulse-leaderboard-night', 'berg-pulse-heatmap-night');

select cron.schedule(
  'berg-pulse-totals-15min',
  '*/15 * * * *',
  $$ refresh materialized view concurrently public.berg_pulse_community_totals; $$
);

select cron.schedule(
  'berg-pulse-leaderboard-night',
  '17 2 * * *',
  $$ refresh materialized view concurrently public.berg_pulse_team_leaderboard; $$
);

select cron.schedule(
  'berg-pulse-heatmap-night',
  '37 2 * * *',
  $$ refresh materialized view concurrently public.berg_pulse_heatmap; $$
);
