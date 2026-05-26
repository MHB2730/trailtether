# The Berg, Live — design doc

**Status:** Draft, awaiting signoff
**Author:** Drafted 2026-05-26 in conversation with Matt
**Estimated build:** ~2 focused weeks (or ~3 days for "just the leaderboard" carve-out)

---

## 1. Summary

A public page (`/pulse/` or part of the homepage) that turns Trailtether's
private telemetry into a community-owned, POPIA-compliant snapshot of
what's happening on the Drakensberg right now. Three stacked panels:

1. **Live community totals** — distance, ascent, active parties, refreshed
   from real recorded hikes.
2. **Route heatmap** — a glow-on-dark map of the Berg, burnt-orange where
   Trailtether users have actually walked. Hex-binned (~50 m) with a
   minimum-N threshold so individual tracks cannot be reconstructed.
3. **Opt-in team leaderboard** — top teams (by km / ascent / hikes), only
   for teams whose creator explicitly ticked "show publicly". Aggregate
   stats only; no member names, contacts, or per-hike timestamps.

The point of the feature is to turn the website from a static brochure
into a living mirror of the app — a data loop only Trailtether can build,
which both promotes the app to website visitors AND gives the brand a
defensible content moat against generic SA hiking sites.

## 2. Why this, why now

Hilltrek has two assets that currently don't talk to each other:

- A **website** that's marketing + merch + admin
- A **Flutter app** (Trailtether) generating high-quality telemetry —
  recorded GPX, completion times, signal patterns, weather encountered,
  SOS events, group composition

Right now, the website tells visitors *"we make an app and write about
routes."* After this page ships, the website tells visitors *"this is
what the Drakensberg actually looks like, walked by hundreds of hikers
this month."* That's a category change — defensible because no static
hiking-blog competitor can replicate it, and it compounds (more app
users → richer page → more app users).

## 3. Out of scope (V1)

- Individual-user leaderboards (V1 = team-only — simpler POPIA story)
- Per-hike timestamps published live (V1 = month/season granularity)
- Real-time animation of moving parties on the heatmap (V1 = nightly
  snapshot + a separate "currently active" count)
- AI summaries / generated trip narratives (separate feature, later)
- Comparison to historical years / decade-long trends (need more data)

## 4. POPIA position

POPIA Sections 11, 17 and 18 govern lawful processing, minimality, and
data-subject rights. The dashboard is designed to be lawful by default:

| Data class | Public on dashboard? | Lawful basis |
|---|---|---|
| Aggregate community totals (km, ascent, hikes, active count) | Yes | Not personal info — fully anonymized cohort statistics |
| Hex-binned route density (min 3 distinct users per cell) | Yes | De-identified; binning + min-N defeats re-identification |
| Team display name + team-level stats | Yes, **opt-in only** | Consent (`teams.is_public = true` set by team creator) |
| Team member names / emails / phones / FCM tokens | **No, never** | Already excluded by `profiles_public()` view |
| Individual hike timestamps tied to a person | **No, never** | Identifying; rolled up into team-level or community-level totals |
| Raw GPX track of any individual hike | **No, never** | Identifying; hex aggregation only |

**Consent ramp:** when this ships, every existing team's `is_public`
flag is `false`. No team appears on the leaderboard until its creator
opts in via the Trailtether app team-settings toggle. New teams default
to `false` too; consent is always a deliberate action.

**Right to withdraw:** flipping `is_public` back to `false` removes
the team from the next leaderboard refresh (within ~24h). Documented
on `/privacy/` as a numbered POPIA right.

**Privacy policy update:** add a section "Trailtether app data on
hilltrek.co.za" describing exactly what is aggregated, what is opt-in,
and how to withdraw consent. Two paragraphs, link from the dashboard
footer.

## 5. Data sources (all already exist)

- `public.recorded_trails` — completed hike rows (user_id, start_time,
  end_time, distance_m, ascent_m, sharing flag, team_id)
- `public.team_member_track_points` — high-resolution track points
  during live hikes (uid, ts, lat, lon)
- `public.gpx_uploads` — user-uploaded GPX routes
- `public.teams` — team_id, team_name, member_uids, created_by
- `public.team_stats` — pre-aggregated km / ascent / peaks / member_count
- `public.team_member_locations` — last known location per user (used
  to count active parties)

No new data has to be collected from users to ship V1. We're publishing
de-identified projections of data they're already sending us.

## 6. Schema changes

```sql
-- Opt-in flag, with a sanitized display name distinct from internal
-- team_name (which may contain inside jokes, real names, etc.).
alter table public.teams
  add column is_public           boolean not null default false,
  add column public_display_name text;

-- Constraint: a public team must have a display_name set. Enforced at
-- the app layer too — the consent modal asks for it before flipping is_public.
alter table public.teams
  add constraint teams_public_needs_display_name
  check (is_public = false or (public_display_name is not null and length(trim(public_display_name)) > 0));

-- Audit who flipped it and when. Useful when a team member complains
-- later and we need to show consent was explicit.
alter table public.teams
  add column is_public_changed_at timestamptz,
  add column is_public_changed_by uuid references auth.users(id);

-- Trigger touches the audit fields when is_public changes.
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
  end if;
  return new;
end;
$$;

drop trigger if exists trg_teams_track_public_change on public.teams;
create trigger trg_teams_track_public_change
  before update on public.teams
  for each row execute function public.teams_track_public_change();
```

No changes to existing rows. Behavioural default for everything in the
table is unchanged (private).

## 7. Aggregate views + RPCs

All materialized views, refreshed by `pg_cron`. RPCs are SECURITY DEFINER
with locked `search_path` to keep the linter happy and pass the security
audit we did earlier.

### 7.1 `community_totals` (5-min refresh, cheap)

```sql
create materialized view public.berg_pulse_community_totals as
select
  count(*)                                         as total_hikes,
  count(distinct user_id)                          as unique_hikers,
  count(distinct team_id) filter (where team_id is not null) as teams_active,
  coalesce(sum(distance_m), 0)::bigint             as total_distance_m,
  coalesce(sum(ascent_m),   0)::bigint             as total_ascent_m,
  date_trunc('day', max(end_time))                 as last_hike_date
from public.recorded_trails
where end_time > now() - interval '30 days';
```

RPC:
```sql
create or replace function public.berg_pulse_stats()
returns table (...)  -- mirrors the view's shape
language sql security definer set search_path = public, pg_temp stable
as $$ select * from public.berg_pulse_community_totals $$;

revoke all on function public.berg_pulse_stats() from public;
grant execute on function public.berg_pulse_stats() to anon, authenticated, service_role;
```

### 7.2 `active_hikes_count` (live, no cache)

Counts users whose `team_member_locations.updated_at` is within the last
30 minutes. Plain SECURITY DEFINER function — no materialization, query
is fast on the indexed table.

```sql
create or replace function public.berg_pulse_active_count()
returns int
language sql security definer set search_path = public, pg_temp stable
as $$
  select count(distinct uid)::int
  from public.team_member_locations
  where updated_at > now() - interval '30 minutes';
$$;
```

### 7.3 `public_team_leaderboard` (nightly refresh)

```sql
create materialized view public.berg_pulse_team_leaderboard as
select
  t.id,
  t.public_display_name as team_name,
  array_length(t.member_uids, 1) as member_count,
  ts.total_km,
  ts.total_ascent,
  ts.peaks_climbed,
  rank() over (order by ts.total_km desc) as rank_by_distance,
  rank() over (order by ts.total_ascent desc) as rank_by_ascent
from public.teams t
join public.team_stats ts on ts.team_id = t.id
where t.is_public = true;
```

### 7.4 `route_stats_per_route` (nightly refresh)

For each route in `gpx_uploads` (or whatever your canonical route table
is — TBD in §11), aggregate the completion times, completion rates, and
seasonal pattern from `recorded_trails`. Returns:
- median completion time, p90 completion time
- completion % (started vs finished)
- popularity rank (count of completions)
- most-active month

### 7.5 `heatmap_hex_cells` (nightly refresh)

```sql
-- Bucket every track point into a ~50m hex cell. PostGIS provides
-- ST_HexagonGrid; we approximate via lat/lon bins for the V1 (cheaper,
-- no PostGIS dependency required).
create materialized view public.berg_pulse_heatmap as
select
  -- ~50m precision at Drakensberg latitudes: lat ≈ 0.00045°, lon ≈ 0.00055°
  round(lat::numeric * 2200) / 2200 as lat_cell,
  round(lon::numeric * 1820) / 1820 as lon_cell,
  count(distinct uid)              as hiker_count,
  count(*)                         as point_count
from public.team_member_track_points
where ts > now() - interval '12 months'
group by 1, 2
having count(distinct uid) >= 3;   -- min-N threshold for privacy
```

RPC accepts a bounding box (so we don't ship the whole Berg every page
load) and returns cells within it:

```sql
create or replace function public.berg_pulse_heatmap_cells(
  p_min_lat numeric, p_max_lat numeric,
  p_min_lon numeric, p_max_lon numeric
) returns table (lat_cell numeric, lon_cell numeric, hiker_count int) ...
```

### 7.6 pg_cron schedule

```sql
select cron.schedule('berg-pulse-5min',  '*/5 * * * *',  $$ refresh materialized view concurrently public.berg_pulse_community_totals $$);
select cron.schedule('berg-pulse-night', '17 2 * * *',   $$ refresh materialized view concurrently public.berg_pulse_team_leaderboard $$);
select cron.schedule('berg-pulse-heat',  '37 2 * * *',   $$ refresh materialized view concurrently public.berg_pulse_heatmap $$);
```

(02:17 / 02:37 UTC = 04:17 / 04:37 SAST. Off-peak.)

## 8. Frontend: `/pulse/` page

Single static page on `hilltrek-site`, brand-consistent (ember/mono), no
new dependencies except a map library.

**Layout (top to bottom):**

```
┌─────────────────────────────────────────────────────────┐
│  HERO STRIP                                              │
│    // The Berg, Live                                     │
│    Total km · total ascent · active parties             │
│    Last refreshed N min ago                              │
├─────────────────────────────────────────────────────────┤
│  HEATMAP                                                 │
│    MapLibre canvas, full bleed, burnt-orange glow       │
│    Hover any cell → "47 hiker-traversals here"          │
│    Footer note: "Hex cells of ~50m. Only cells with ≥3  │
│    distinct hikers are shown."                          │
├─────────────────────────────────────────────────────────┤
│  ROUTE STATS GRID                                        │
│    Most-hiked, toughest pace, fastest completion        │
│    Each card links to that route's existing /hikes/ page│
├─────────────────────────────────────────────────────────┤
│  LEADERBOARD                                             │
│    Top public teams by km / ascent / hikes              │
│    Footer: "Teams shown here have opted in. N of M      │
│    teams are public. Toggle in your Trailtether app."   │
└─────────────────────────────────────────────────────────┘
```

**Map library choice:** MapLibre GL JS (open, no API key, ~120KB).
Tiles from MapTiler / Stadia / open-meteo (free tier). Will need a
CSP allowlist update (`script-src`, `connect-src`, `img-src`,
`worker-src` for the map worker).

**Render strategy:** server-fetches the three RPCs on page load, then
the heatmap RPC again whenever the user pans/zooms (debounced to ~300ms).

## 9. Trailtether app: consent flow

One screen in the app, reachable from team settings:

```
[ Show this team on Hilltrek? ]   [ toggle: OFF ]

When ON, your team's display name + total km, ascent, and
hike count appear on hilltrek.co.za/pulse/ alongside other
opted-in teams. Member names, emails, FCM tokens, and
individual hike data stay private.

Display name on the leaderboard:
[ _________________________ ]   ← required when ON

Toggle off any time. Your team disappears from the next
nightly leaderboard refresh.
```

**Implementation**: ~4h of Flutter work — a single toggle + text
input in `lib/screens/team_detail_screen.dart` (or wherever team
settings live), wired to update `teams.is_public` and
`teams.public_display_name` via Supabase.

## 10. Rollout plan

1. **Schema migration** — apply via MCP, idempotent, default-OFF for
   existing teams. (½ day)
2. **Aggregate views + RPCs + pg_cron** — applied via MCP. Verify
   refresh runs nightly. (1 day)
3. **Trailtether consent toggle** — Flutter changes, ship in next
   release. **No team can opt in before this is in the field.**
   (4h dev + the user's normal `publish_release.ps1` flow)
4. **Build `/pulse/` page** — frontend work, no live data yet (mock
   from JSON fixtures so we can iterate visually). (3-4 days)
5. **Connect frontend to RPCs** — gated by step 3 having shipped, so
   the consent surface exists when the page goes live. (½ day)
6. **Privacy policy update** + link from `/pulse/` footer. (1h)
7. **Soft launch** — drop the page link in the next newsletter,
   measure how many teams opt in over the first 7 days. If healthy
   uptake, promote on Instagram + add to homepage nav. If low
   uptake, send a one-off email explaining the feature to existing
   Trailtether users.

**Hard dependency between steps 3 and 5.** If the page ships before
the consent toggle is in users' hands, the leaderboard is empty
(every `is_public = false`), which is honest but unimpressive. The
sequence above guarantees the page launches with at least the
community totals + heatmap populated, and the leaderboard fills in
as users opt in.

## 11. Open questions (decide before build)

These need a yes/no before any migration runs.

1. **What's the canonical "route" model?** Right now `recorded_trails`
   has free-form GPX. There's no `routes` table with named routes
   (Tugela Falls, Cathedral Peak, etc.). For §7.4 to work we either:
   - (a) Add a `routes` table that the app references when starting a
     hike (cleanest, but requires app change + content seeding)
   - (b) Auto-cluster recorded trails by similarity to derive routes
     (clever, but error-prone for V1)
   - (c) Skip §7.4 for V1 and only show community totals + heatmap +
     leaderboard (still a strong page, smaller scope)
   - **Recommendation:** (c) for V1, plan (a) for V2.

2. **Heatmap source: `recorded_trails` only, or also `team_member_track_points`?**
   Recorded trails = canonical post-hike, ~1 row per hike, big GPX
   blob. Track points = live position pings, dense, faster-flowing.
   For the heatmap, track points are richer but require a different
   schema query (and POPIA-wise are slightly more sensitive).
   - **Recommendation:** track points, with the min-N=3 threshold.
     The threshold is what makes the privacy story work, not the
     source table.

3. **Minimum-N hex threshold.** §7.5 uses ≥3 distinct users. Higher
   = safer privacy + sparser map. Lower = denser map + more re-id
   risk.
   - **Recommendation:** 3 for V1, with a config knob so we can
     tighten to 5 if anyone raises a concern.

4. **Refresh cadence for the leaderboard.** Nightly feels right;
   real-time would tempt people to optimize for the leaderboard rank
   in ways that distort hiking behavior. Slower is also kinder to
   POPIA (less surface for "real-time tracking" perception).
   - **Recommendation:** nightly.

5. **Backfill team_stats for opted-in teams.** `team_stats` is already
   computed via the `sync_team_hike_stats` trigger. If a team has
   historical hikes but the trigger never ran on them (e.g. the trigger
   was added later), their stats will be low. Verify trigger has
   backfilled before launch.

6. **Do we need a kill switch?** If a team complains, we need to be
   able to flip `is_public = false` for them from the admin SPA
   without their cooperation. (Yes, recommend adding to the existing
   Subscribers tab pattern — admin can override consent both ways.)

## 12. Effort estimate (revised)

| Step | Work | Person-time |
|---|---|---|
| Schema migration | DB only | 2h |
| Materialized views + RPCs + pg_cron | DB only | 1d |
| Trailtether consent toggle | Flutter | 4h |
| `/pulse/` page V1 (totals + heatmap) | Frontend | 3d |
| Leaderboard panel | Frontend | 1d |
| Privacy policy + consent copy | Copy | 1h |
| Testing, polish, soft launch | All | 2d |
| **Total** | | **~2 weeks focused** |

**Faster carve-out:** community totals + leaderboard only (no map),
~3 days. Loses the brand-defining visual but ships a real feature.

## 13. Decisions needed from you before I start

1. ✅ / ❌ POPIA model in §4 (opt-in for teams, never personal-level data)
2. ✅ / ❌ Schema changes in §6 (new columns + trigger)
3. ✅ / ❌ Map library = MapLibre + tiles from a free-tier provider
4. Pick one answer to each of §11 open questions
5. Pick scope: full V1 (~2 weeks) vs leaderboard-only carve-out (~3 days)

Once these are answered, I can apply the migration and start §7.

---

*This document lives at `docs/design/the-berg-live.md`. Update it as
decisions are made — the eventual implementation should match the
final state of this doc, not the original draft.*
