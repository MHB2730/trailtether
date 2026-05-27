-- =====================================================================
-- Berg Live: opt-in flag + audit trail on teams for the public
-- /pulse/ leaderboard.
--
-- Default OFF for every existing team. No team appears on the public
-- page until the creator explicitly toggles is_public via the
-- Trailtether app (see lib/screens/team_detail_screen.dart, Berg-Live
-- branch of the rollout).
--
-- See docs/design/the-berg-live.md §6 for the design rationale.
-- Applied via Supabase MCP on 2026-05-27.
-- =====================================================================

alter table public.teams
  add column if not exists is_public            boolean not null default false,
  add column if not exists public_display_name  text,
  add column if not exists is_public_changed_at timestamptz,
  add column if not exists is_public_changed_by uuid references auth.users(id);

-- Public teams MUST have a sanitized display name (separate from
-- team_name which may contain inside jokes / real names). Enforced
-- at the DB layer so the app can't accidentally publish a team
-- without one.
alter table public.teams
  drop constraint if exists teams_public_needs_display_name;
alter table public.teams
  add constraint teams_public_needs_display_name
  check (is_public = false or (public_display_name is not null and length(trim(public_display_name)) > 0));

-- Audit trigger: stamps _changed_at + _changed_by whenever is_public
-- flips. Useful evidence if a team member later disputes the opt-in.
create or replace function public.teams_track_public_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if (tg_op = 'UPDATE' and old.is_public is distinct from new.is_public) then
    new.is_public_changed_at := now();
    new.is_public_changed_by := auth.uid();
  elsif (tg_op = 'INSERT' and new.is_public = true) then
    new.is_public_changed_at := now();
    new.is_public_changed_by := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_teams_track_public_change on public.teams;
create trigger trg_teams_track_public_change
  before insert or update on public.teams
  for each row execute function public.teams_track_public_change();
