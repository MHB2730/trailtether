-- =====================================================================
-- Admin-only RPCs powering the Trailtether tab in the admin SPA
--
-- Three SECURITY DEFINER functions, all gating on public.is_admin() with
-- an explicit 42501 raise so unauthenticated/non-admin callers get a
-- proper PostgREST error rather than a silent empty result:
--
--   admin_trailtether_stats()         single-row JSON snapshot used by the
--                                     stats strip at the top of the tab
--   admin_trailtether_active_users()  rows for the live map (users with a
--                                     team_member_locations entry updated
--                                     in the last 30 minutes)
--   admin_trailtether_top_hikers()    leaderboard joining recorded_trails
--                                     to profiles via is_admin()-bypassed
--                                     SECURITY DEFINER access
--
-- search_path is locked on all three so the function_search_path_mutable
-- advisor doesn't flag them. EXECUTE is revoked from PUBLIC and granted
-- to `authenticated` only — anon callers can't reach these.
--
-- Applied via Supabase MCP on 2026-05-26. Saved here for reproducibility.
-- =====================================================================

create or replace function public.admin_trailtether_stats()
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
stable
as $$
declare result jsonb;
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'total_users',        (select count(*) from auth.users),
    'total_teams',        (select count(*) from public.teams),
    'teams_with_members', (select count(*) from public.teams where array_length(member_uids, 1) > 1),
    'hikes_total',        (select count(*) from public.recorded_trails),
    'hikes_30d',          (select count(*) from public.recorded_trails where created_at > now() - interval '30 days'),
    'total_km',           (select round(coalesce(sum(distance_km), 0)::numeric, 1) from public.recorded_trails),
    'total_ascent_m',     (select coalesce(sum(ascent_m), 0)::bigint from public.recorded_trails),
    'active_now',         (select count(distinct uid) from public.team_member_locations where timestamp > now() - interval '30 minutes'),
    'incidents_open',     (select count(*) from public.incidents where status is null or status not in ('resolved', 'flagged')),
    'incidents_30d',      (select count(*) from public.incidents where reported_at > now() - interval '30 days')
  ) into result;

  return result;
end;
$$;

revoke all on function public.admin_trailtether_stats() from public;
grant execute on function public.admin_trailtether_stats() to authenticated;

-- ---------------------------------------------------------------------
-- Active users for the live map. display_name is denormalized on
-- team_member_locations so no profile join needed.
--
-- p_minutes accepts the lookback window; defaults to 24h because the
-- current user base hikes weekly, not constantly. UI surfaces a
-- selector (30m / 24h / 7d). Clamped to 1 minute - 30 days so a
-- malformed value can't trigger a full scan or return stale data.
-- ---------------------------------------------------------------------
drop function if exists public.admin_trailtether_active_users();

create or replace function public.admin_trailtether_active_users(p_minutes int default 1440)
returns table (
  uid          uuid,
  display_name text,
  team_id      uuid,
  hike_id      uuid,
  lat          double precision,
  lon          double precision,
  status       text,
  ts           timestamptz,
  speed        double precision,
  altitude     double precision,
  battery_pct  int,
  connectivity text
)
language plpgsql security definer
set search_path = public, pg_temp
stable
as $$
declare
  m int := greatest(1, least(coalesce(p_minutes, 1440), 43200));
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;
  return query
    select l.uid, l.display_name, l.team_id, l.hike_id, l.lat, l.lon, l.status,
           l.timestamp, l.speed, l.altitude, l.battery_pct, l.connectivity
    from public.team_member_locations l
    where l.timestamp > now() - make_interval(mins => m)
    order by l.timestamp desc
    limit 500;
end;
$$;

revoke all on function public.admin_trailtether_active_users(int) from public;
grant execute on function public.admin_trailtether_active_users(int) to authenticated;

-- ---------------------------------------------------------------------
-- Top hikers leaderboard. SECURITY DEFINER bypasses the new owner-only
-- RLS on profiles since the is_admin() check inside the function is the
-- gate.
-- ---------------------------------------------------------------------
create or replace function public.admin_trailtether_top_hikers(p_limit int default 20)
returns table (
  user_id      uuid,
  display_name text,
  username     text,
  hikes        bigint,
  total_km     double precision,
  total_ascent bigint,
  last_hike    timestamptz
)
language plpgsql security definer
set search_path = public, pg_temp
stable
as $$
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;
  return query
    select
      rt.user_id,
      p.display_name,
      p.username,
      count(*)::bigint                                          as hikes,
      round(sum(rt.distance_km)::numeric, 1)::double precision  as total_km,
      sum(rt.ascent_m)::bigint                                  as total_ascent,
      max(rt.created_at)                                        as last_hike
    from public.recorded_trails rt
    left join public.profiles p on p.id = rt.user_id
    group by rt.user_id, p.display_name, p.username
    order by count(*) desc, sum(rt.distance_km) desc nulls last
    limit p_limit;
end;
$$;

revoke all on function public.admin_trailtether_top_hikers(int) from public;
grant execute on function public.admin_trailtether_top_hikers(int) to authenticated;

-- ---------------------------------------------------------------------
-- Recent recorded hikes for the Trailtether map's "Recent hikes" layer.
-- Returns the bbox centroid as a representative pin location — the GPX
-- is in storage; fetching it for every pin would be slow and we only
-- need "roughly where did this hike happen". Default window 30 days.
-- ---------------------------------------------------------------------
create or replace function public.admin_trailtether_recent_hikes(p_days int default 30)
returns table (
  id           uuid,
  user_id      uuid,
  team_id      uuid,
  name         text,
  distance_km  double precision,
  ascent_m     int,
  duration_sec int,
  point_count  int,
  centroid_lat double precision,
  centroid_lon double precision,
  display_name text,
  created_at   timestamptz
)
language plpgsql security definer
set search_path = public, pg_temp
stable
as $$
declare
  d int := greatest(1, least(coalesce(p_days, 30), 3650));
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;
  return query
    select
      rt.id, rt.user_id, rt.team_id,
      rt.name, rt.distance_km, rt.ascent_m, rt.duration_seconds, rt.point_count,
      (rt.min_lat + rt.max_lat) / 2.0  as centroid_lat,
      (rt.min_lon + rt.max_lon) / 2.0  as centroid_lon,
      p.display_name,
      rt.created_at
    from public.recorded_trails rt
    left join public.profiles p on p.id = rt.user_id
    where rt.created_at > now() - make_interval(days => d)
      and rt.min_lat is not null and rt.min_lon is not null
    order by rt.created_at desc
    limit 500;
end;
$$;

revoke all on function public.admin_trailtether_recent_hikes(int) from public;
grant execute on function public.admin_trailtether_recent_hikes(int) to authenticated;
