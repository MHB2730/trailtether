-- =====================================================================
-- Curated trails catalogue (Hilltrek)
--
-- Replaces the bundled trailtether_app/assets/data/routes_cleaned.json
-- so admins can edit / add / delete trails from the PC app at runtime
-- without an app re-ship.
--
-- Read model:
--   • anon + authenticated   → only rows with published = true
--   • is_admin()             → all rows (so unpublished drafts show in
--                              the PC Trails admin section)
--
-- Write model:
--   • is_admin() only        → INSERT / UPDATE / DELETE all gated on the
--                              same public.is_admin() allowlist already
--                              used by site_orders, site_settings, etc.
--
-- The `coords` column keeps the existing JSON shape ([lon, lat, ele]
-- triples) so TrailService.fromJson can stay unchanged across the
-- migration. The cached bbox columns let TrailMapWidget filter by
-- viewport without re-iterating the coord array.
--
-- One-shot seed: admins run the in-app "Seed catalogue from bundle"
-- action in the PC Trails section, which iterates the bundled JSON and
-- upserts (id) into this table. Idempotent — safe to re-run.
-- =====================================================================

create table if not exists public.trails (
  id                    text primary key,
  name                  text not null,
  description           text not null default '',
  difficulty            text not null default 'Moderate'
                          check (difficulty in ('Easy','Moderate','Challenging','Hard','Extreme')),
  -- 'hike' | 'cave' | 'peak' | 'circular' — replaces the brittle
  -- name-substring "isCave" detection in trail.dart with an explicit tag.
  category              text not null default 'hike'
                          check (category in ('hike','cave','peak','circular','scramble')),
  distance_km           numeric not null default 0,
  elevation_gain_m      integer not null default 0,
  elevation_descent_m   integer not null default 0,
  est_time_hours        numeric not null default 0,
  min_ele               integer not null default 0,
  max_ele               integer not null default 0,
  coords                jsonb   not null default '[]'::jsonb,
  -- Pre-computed bbox so map viewport queries don't re-scan coords.
  min_lat               numeric,
  max_lat               numeric,
  min_lon               numeric,
  max_lon               numeric,
  published             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  created_by            uuid references auth.users(id)
);

create index if not exists trails_name_lower_idx
  on public.trails (lower(name));
create index if not exists trails_category_idx
  on public.trails (category);
create index if not exists trails_published_idx
  on public.trails (published);
create index if not exists trails_bbox_idx
  on public.trails (min_lat, max_lat, min_lon, max_lon);

-- updated_at auto-touch
create or replace function public.touch_trails_updated_at()
returns trigger
language plpgsql
-- Locked search_path so the function_search_path_mutable advisor stays
-- quiet — matches the pattern used by recent admin_trailtether RPCs.
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trails_touch_updated_at on public.trails;
create trigger trails_touch_updated_at
  before update on public.trails
  for each row execute function public.touch_trails_updated_at();

-- RLS
alter table public.trails enable row level security;

drop policy if exists "Public read published trails" on public.trails;
create policy "Public read published trails"
  on public.trails for select
  to anon, authenticated
  using (published);

drop policy if exists "Admins read all trails" on public.trails;
create policy "Admins read all trails"
  on public.trails for select
  to authenticated
  using (public.is_admin());

drop policy if exists "Admins write trails" on public.trails;
create policy "Admins write trails"
  on public.trails for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

comment on table public.trails is
  'Curated hike / cave / peak catalogue. Admin-writable, publicly readable for published rows. Seeded from routes_cleaned.json on first admin run.';
