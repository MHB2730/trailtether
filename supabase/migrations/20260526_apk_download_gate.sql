-- =====================================================================
-- APK download gate
--
-- Goal: stop bots/scrapers from grabbing the Trailtether APK off the
-- public site. The website button now goes through a gated edge function
-- (Turnstile + email + T&Cs). The in-app updater is untouched — it still
-- reads download_url from public.app_releases and fetches via the public
-- bucket URL, which keeps working because bucket.public = true bypasses
-- RLS on /object/public/<path>.
--
-- Two changes:
--   1. New apk_downloads table — one row per gated download attempt.
--   2. Drop the anon SELECT policies on storage.objects for app-releases
--      so anon can no longer LIST the bucket. Direct object reads via
--      the public URL keep working (public-bucket bypass). Service role
--      (publish_release.ps1) bypasses RLS regardless.
--
-- Applied via Supabase MCP on 2026-05-26. Saved here for reproducibility.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. apk_downloads — one row per gated download
-- ---------------------------------------------------------------------
create table if not exists public.apk_downloads (
  id uuid primary key default gen_random_uuid(),

  email             citext not null,
  terms_accepted_at timestamptz not null,
  newsletter_opt_in boolean not null default false,

  -- Soft link to the subscriber row created (or matched) at gate time.
  -- ON DELETE SET NULL because a user unsubscribing shouldn't nuke
  -- their historical download record.
  subscriber_id uuid references public.site_subscribers(id) on delete set null,

  -- Which APK row from app_releases this attempt resolved to. Soft link
  -- so old downloads survive an app_releases purge.
  apk_release_id   uuid references public.app_releases(id) on delete set null,
  apk_filename     text,
  apk_version_name text,
  apk_version_code int,

  -- Audit / abuse-investigation fields. ip + ua are best-effort; CF
  -- supplies cf-connecting-ip when the site is behind Cloudflare.
  ip         text,
  ip_country text,
  user_agent text,

  created_at timestamptz not null default now()
);

create index if not exists apk_downloads_email_created_idx
  on public.apk_downloads (email, created_at desc);
create index if not exists apk_downloads_ip_created_idx
  on public.apk_downloads (ip, created_at desc);
create index if not exists apk_downloads_created_at_idx
  on public.apk_downloads (created_at desc);

alter table public.apk_downloads enable row level security;

-- Admin-only visibility. Service role (used by the edge function)
-- bypasses RLS automatically, so it can insert + read freely.
drop policy if exists "apk_downloads_admin_read" on public.apk_downloads;
create policy "apk_downloads_admin_read"
  on public.apk_downloads
  for select
  using ((select public.is_admin()) or (auth.jwt() ->> 'role') = 'service_role');

-- ---------------------------------------------------------------------
-- 2. Public-safe metadata RPC for the website
--
-- The page used to enumerate the storage bucket to find the latest APK
-- (anon listing). Now that listing is gone, the page can still surface
-- the current version label by calling this RPC — which returns ONLY
-- the metadata fields (version, sha256, released_at), NOT download_url.
-- The in-app updater still queries app_releases directly via the anon
-- SELECT policy (it needs download_url); we deliberately don't touch
-- that policy so installed apps keep working.
-- ---------------------------------------------------------------------
create or replace function public.app_release_meta(p_platform text default 'android')
returns table (
  version_name text,
  version_code int,
  sha256       text,
  released_at  timestamptz
)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select version_name, version_code, sha256, released_at
  from public.app_releases
  where platform = p_platform
  order by released_at desc
  limit 1;
$$;

revoke all on function public.app_release_meta(text) from public;
grant execute on function public.app_release_meta(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. Lock down storage listing on app-releases
--
-- Existing policies allowed anon to call POST /storage/v1/object/list/
-- and enumerate every APK in the bucket — that's what the old discovery
-- script on hilltrek-site/trailtether/ relied on. We drop those SELECT
-- policies so listing returns nothing for anon. Direct downloads via
-- /object/public/app-releases/<path> keep working because the public
-- bucket flag bypasses RLS on that endpoint.
-- ---------------------------------------------------------------------
drop policy if exists "app_releases_storage_read" on storage.objects;
drop policy if exists "Allow anon read access to app-releases" on storage.objects;

-- Keep admins able to list the bucket from the admin SPA. Service role
-- (publish script) bypasses RLS regardless, so it doesn't need a policy.
drop policy if exists "app_releases_storage_admin_list" on storage.objects;
create policy "app_releases_storage_admin_list"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'app-releases'
    and (select public.is_admin())
  );
