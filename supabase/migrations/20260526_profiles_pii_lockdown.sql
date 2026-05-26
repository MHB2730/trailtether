-- =====================================================================
-- Profiles PII lockdown
--
-- Before: profiles_authenticated_read (SELECT to authenticated using=true)
-- meant any signed-in Trailtether user could SELECT * FROM profiles and
-- harvest every other user's email, emergency_contact_email,
-- emergency_contact_phone, fcm_token, etc.  POPIA exposure + the FCM
-- tokens would also let an attacker spoof push notifications.
--
-- After: profiles is owner-only SELECT (plus is_admin() for the admin
-- panel). A profiles_public view exposes the genuinely-public fields
-- (id, username, display_name, photo_url, region, experience_level,
-- bio) to authenticated users, so future features can still surface
-- another user's name/photo without re-opening the base table.
--
-- Verified safe to apply on 2026-05-26: the Trailtether app reads
-- profiles in exactly two places (profile_provider.dart, auth_provider.dart)
-- and both filter by id = auth.uid() — owner-only.  No other client,
-- admin SPA, or edge function reads the profiles table directly.
--
-- Applied via Supabase MCP on 2026-05-26.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Replace the open SELECT policy with owner-only + admin
-- ---------------------------------------------------------------------
drop policy if exists "profiles_authenticated_read" on public.profiles;

drop policy if exists "profiles_owner_read" on public.profiles;
create policy "profiles_owner_read"
  on public.profiles
  for select
  using (auth.uid() = id);

drop policy if exists "profiles_admin_read" on public.profiles;
create policy "profiles_admin_read"
  on public.profiles
  for select
  to authenticated
  using ((select public.is_admin()));

-- ---------------------------------------------------------------------
-- 2. profiles_public — safe columns only, available to authenticated
--
-- This view exposes ONLY the columns that are intentionally public
-- (display name, handle, avatar, generic region/experience/bio). Email,
-- emergency contacts, FCM tokens, and the is_admin flag are deliberately
-- excluded.
--
-- Run as the view owner (security_invoker = false) so the view bypasses
-- the new owner-only RLS on the underlying table — the column allowlist
-- IS the access control here. Adding security_barrier=true so the
-- planner can't push WHERE-clause functions below the view boundary and
-- side-channel an excluded column (e.g. via row_to_json + a leaky cast).
-- ---------------------------------------------------------------------
drop view if exists public.profiles_public;
create view public.profiles_public
with (security_invoker = false, security_barrier = true)
as
  select
    id,
    username,
    display_name,
    photo_url,
    region,
    experience_level,
    bio
  from public.profiles;

revoke all on public.profiles_public from public;
grant select on public.profiles_public to anon, authenticated, service_role;

comment on view public.profiles_public is
  'Public-safe projection of profiles. Use this anywhere the app shows '
  'another user''s name/photo. Base table profiles is owner-only SELECT.';
