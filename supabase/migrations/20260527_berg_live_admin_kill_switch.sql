-- =====================================================================
-- Berg Live: admin-only RPCs for the public-leaderboard kill switch.
--
-- Two new functions, both gated on public.is_admin():
--
--   admin_trailtether_teams()       List of every team with current
--                                   is_public state + stats. Powers the
--                                   "Teams" card in the admin Trailtether
--                                   tab (was previously a direct
--                                   `from('team_stats').select('*')` —
--                                   replaced so the admin can see/flip
--                                   public state in one place).
--
--   admin_set_team_public(team_id,  Flips teams.is_public AND
--                         is_pub,   public_display_name in one shot.
--                         dn)       The audit trigger already stamps
--                                   _changed_at + _changed_by from
--                                   auth.uid().  Used as the admin
--                                   kill switch — POPIA spec §7 lets
--                                   us yank a team off /pulse/ in
--                                   one click if a member complains.
--
-- See docs/design/the-berg-live.md §6 + §10.
-- Applied via Supabase MCP on 2026-05-27.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Listing for the admin tab
-- ---------------------------------------------------------------------
create or replace function public.admin_trailtether_teams()
returns table (
  team_id              uuid,
  team_name            text,
  public_display_name  text,
  is_public            boolean,
  is_public_changed_at timestamptz,
  member_count         int,
  total_km             numeric,
  total_ascent         bigint,
  peaks_climbed        int,
  created_at           timestamptz
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
      t.id                                                  as team_id,
      t.name                                                as team_name,
      t.public_display_name                                 as public_display_name,
      t.is_public                                           as is_public,
      t.is_public_changed_at                                as is_public_changed_at,
      coalesce(array_length(t.member_uids, 1), 0)::int      as member_count,
      coalesce(ts.total_km, 0)::numeric                     as total_km,
      coalesce(ts.total_ascent, 0)::bigint                  as total_ascent,
      coalesce(ts.peaks_climbed, 0)::int                    as peaks_climbed,
      t.created_at                                          as created_at
    from public.teams t
    left join public.team_stats ts on ts.team_id = t.id
    order by coalesce(ts.total_km, 0) desc, t.created_at desc;
end;
$$;
revoke all on function public.admin_trailtether_teams() from public;
grant execute on function public.admin_trailtether_teams() to authenticated;

-- ---------------------------------------------------------------------
-- 2. Kill-switch + manual enable
--
-- Admin can:
--   * force a team off the public leaderboard (pass p_is_public := false)
--   * publish on a team's behalf if the creator asked us to (pass true
--     and supply a display name — required by teams_public_needs_display_name)
--   * rename the public display name without flipping is_public
--
-- The trigger stamps _changed_at + _changed_by so we have an audit
-- trail of admin overrides separately from creator opt-ins.
-- ---------------------------------------------------------------------
create or replace function public.admin_set_team_public(
  p_team_id      uuid,
  p_is_public    boolean,
  p_display_name text default null
)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  updated public.teams%rowtype;
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;

  update public.teams
     set is_public           = p_is_public,
         public_display_name = case
           when p_display_name is not null and length(trim(p_display_name)) > 0
             then trim(p_display_name)
           else public_display_name
         end
   where id = p_team_id
  returning * into updated;

  if not found then
    raise exception 'team % not found', p_team_id using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'team_id',             updated.id,
    'is_public',           updated.is_public,
    'public_display_name', updated.public_display_name,
    'changed_at',          updated.is_public_changed_at
  );
end;
$$;
revoke all on function public.admin_set_team_public(uuid, boolean, text) from public;
grant execute on function public.admin_set_team_public(uuid, boolean, text) to authenticated;
