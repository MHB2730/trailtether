# Types diff — design entities vs existing Supabase row types

Authored by reading every JSX file under
`.design_handoff/design_handoff_trailtether/design_source/screens/` (20
files) and diffing against the existing TypeScript types in
[`src/data/schema.ts`](src/data/schema.ts).

The **design source is the source of truth for UI shape**; the **Supabase
schema is the source of truth for persistence**. They almost never match
1:1, so the proposal at the end splits the types into two modules:

1. **`src/data/schema.ts`** (already exists) — raw DB row shapes. Names
   end in `Row`. snake_case to mirror Postgres.
2. **`src/data/types.ts`** (NEW, pending your approval) — UI-domain
   entities consumed by screens / components. camelCase. Each has a
   `fromRow(row)` adapter that pulls fields out of the Supabase row and
   normalises Date / number / enum types.

Read each entity section, then the **Resolution** at the bottom. Nothing
ships until you signal **"approve types"** or send edits.

---

## Legend

| Marker | Meaning |
|---|---|
| ✅ MATCH | Design field has an equivalent (possibly renamed) in `schema.ts`. |
| ➕ MISSING IN SCHEMA | Design needs it; schema doesn't have it. Needs a new column / view / RPC, OR derived client-side. |
| ⚠ CONFLICT | Both exist but with different types / cardinality / semantics. |
| 🟦 NEW IN SCHEMA | Schema has it but the design doesn't use it directly. Keep but don't surface in the UI type. |
| 🎨 DESIGN-ONLY | Pure visual hint (color, icon, SVG path). Lives in the UI type but does NOT exist in the database; computed from another field in the adapter. |

---

## 1. Trail — full detail entity

**Source:** `trail-detail.jsx:6` (the `TRAIL` constant).
**Used by:** trail-detail, plan-route.

### Design shape

```ts
interface Trail {
  name: string;
  region: string;          // 'Drakensberg N · Cathedral Peak'
  totalKm: number;
  ascent: number;          // metres
  duration: string;        // '5–7 hrs' — human-formatted
  difficulty: 'Easy' | 'Moderate' | 'Difficult' | 'Technical';
  techGrade: string;       // 'Class 3'
  rating: number;          // 0..5
  reports: number;
  base: number;            // base elevation in metres
  elev: [km: number, metres: number][];   // 28 samples
  segments: TrailSegment[];                // ~6 difficulty-banded sections
  hazards: TrailHazard[];                  // POI + danger markers
  mapPathD: string;                        // SVG path for aerial map
  prep: TrailPrep;
}
interface TrailSegment {
  km0: number; km1: number;
  diff: 'easy' | 'mod' | 'hard';   // ← three-level, not four
  name: string; body: string;
}
interface TrailHazard {
  km: number;
  kind: 'water' | 'shelter' | 'danger' | 'view' | 'summit';
  label: string; desc: string;
}
interface TrailPrep {
  water: string; food: string; layers: string; safety: string;
  permit: string; startBy: string; turnAround: string; cellSignal: string;
}
```

### Schema comparison

| Field | Status | Notes |
|---|---|---|
| `name`, `region`, `totalKm`, `ascent`, `base` | ➕ MISSING IN SCHEMA | No `trails` table. The Flutter app bundles 239 trails in `assets/data/routes_cleaned.json`. RN ships the same JSON. |
| `duration` | ⚠ CONFLICT | Design wants `string` (`'5–7 hrs'`); bundled JSON has numeric `estTimeHours`. Format in the adapter. |
| `difficulty` | ⚠ CONFLICT | Design uses capitalised words; bundled JSON uses `'Easy' \| 'Moderate' \| 'Hard' \| 'Extreme'`. Reconcile to lowercased four-level scale (matches `tokens.ts` `Difficulty`). Map `'Hard'` → `'difficult'`, `'Extreme'` → `'technical'`. |
| `techGrade`, `rating`, `reports` | ➕ MISSING IN SCHEMA | Not in bundled JSON either. `reviews` table exists (0 rows); could back rating once seeded. |
| `elev` | ⚠ CONFLICT | Bundled JSON has dense `profile: ElevationPoint[]`. Down-sample to ~28 in the adapter for the chart. |
| `segments` | ➕ MISSING IN SCHEMA | Bundled JSON has none. Either author per-trail JSON or derive from gradient. **Blocker.** |
| `hazards` | ✅ MATCH (semi) | `incidents` table exists — filter by `trail_id` and map `incidents.type` → `kind` enum. |
| `mapPathD` | 🎨 DESIGN-ONLY | Web prototype hard-coded one SVG path. In RN we render real polylines from `coords: [lat, lon][]`. **Drop from the resolved Trail.** |
| `prep` | ➕ MISSING IN SCHEMA | Free-text checklist. Could ship as JSONB column. **Blocker.** |

### Resolution proposal

Split into `Trail` (bundled asset shape — 239 entries) + `TrailDetailsExtra` (segments/hazards/prep loaded from a server view that doesn't exist yet — Blocker). Adapter `trailFromAsset(json)` lives in `src/data/adapters.ts`. Trail Detail screen renders the base `Trail` immediately and shows `LoadingState` over the extras region until `TrailDetailsExtra` resolves.

---

## 2. TrailListItem — list card on the Trails screen

**Source:** `trails.jsx:4` (`TRAILS_LIST`).

```ts
interface TrailListItem {
  id: string; name: string; region: string;
  diff: 'easy' | 'mod' | 'hard' | 'xhard';   // four-level (note xhard, not hard like Trail.segments)
  km: number; ascent: number;
  hrs: string;           // '5–7'
  rating: number; reports: number;
  tags: string[];        // ['FEATURED', 'CAVES']
  live: number;          // hikers on trail right now
  miniD: string;         // signature SVG path for the thumbnail
  accent: string;        // hex color
}
```

| Field | Status | Notes |
|---|---|---|
| `id`, `name`, `region`, `km`, `ascent` | ✅ MATCH | From bundled JSON. |
| `diff` | ⚠ CONFLICT | Design's four-level (`xhard`) clashes with `Trail.segments.diff` three-level (`hard`). Canonicalise to tokens.ts `Difficulty` (`easy \| moderate \| difficult \| technical`). Map `xhard` → `technical`, `mod` → `moderate`, `hard` → `difficult`. |
| `hrs` | ⚠ CONFLICT | Pre-formatted string; JSON has numeric. Format in the adapter. |
| `rating`, `reports` | ➕ MISSING IN SCHEMA | Same as Trail. |
| `tags` | ➕ MISSING IN SCHEMA | Free-form badges. **Blocker.** |
| `live` | ➕ MISSING IN SCHEMA | Live count derivable from `team_member_locations WHERE timestamp > now() - interval '30 min'` joined against trail proximity. **Blocker** (new view `v_trail_live_hikers`). |
| `miniD`, `accent` | 🎨 DESIGN-ONLY | Compute from polyline + difficulty colour. |

---

## 3. HikeRecord — row on Hike History, Activity, Profile stats

**Source:** `history.jsx:6` (`HIKES`).

```ts
interface HikeRecord {
  id: number | string;
  name: string;
  date: string;          // 'OCT 26' pre-formatted
  km: number;
  gain: number;          // metres ascent
  hrs: string;           // '5:14' h:mm
  score: 'A' | 'B' | 'C' | 'D' | 'F';   // letter grade
  diff: 'easy' | 'mod' | 'hard' | 'xhard';
  region: string;
}
```

vs `HikeHistoryRow`:

| Design | DB | Status |
|---|---|---|
| `id` | `id` (uuid) | ✅ MATCH |
| `name` | `name` (nullable) | ✅ MATCH |
| `date` | `created_at` | ⚠ CONFLICT — adapter formats `created_at` → 'OCT 26'. Domain holds a `Date`. |
| `km` | `distance_km` | ✅ MATCH |
| `gain` | `ascent_m` | ✅ MATCH |
| `hrs` | `duration_seconds` | ⚠ CONFLICT — adapter computes `h:mm`. Domain stores `durationSeconds: number`. |
| `score` | — | ➕ MISSING IN SCHEMA — **Blocker** (`hike_history.score`). |
| `diff` | — | ➕ MISSING IN SCHEMA — derived from linked `Trail` (via `trail_id`); null when free-form. |
| `region` | — | ➕ MISSING IN SCHEMA — also derived from linked `Trail`. |

---

## 4. Achievement — the hex medallion

**Source:** `achievements.jsx:5` (the `all` array) + `profile.jsx:135`.

```ts
interface Achievement {
  id: string;
  icon: IconName;
  label: string;
  sub: string;
  rarity: 'common' | 'rare' | 'epic' | 'legendary';
  progress: number;         // 0..1 (1 when unlocked)
  unlocked: boolean;
  earned?: string;          // 'OCT 24'
  desc?: string;            // longer description, present on the latest-unlock hero only
  newest?: boolean;
}
```

| Field | Status | Notes |
|---|---|---|
| All fields | ➕ MISSING IN SCHEMA | No `achievements` table. **BLOCKERS.md #5 already covers it.** Catalog ships static; per-user progress needs a view. |

---

## 5. ForecastDay + ForecastHour + ForecastAlert + ForecastDetailTile

**Source:** `forecast.jsx:4` (`days` array), `:90+` (HourlyGraph), `:100` (alerts), `:88` (FxTile).

```ts
interface ForecastDay {
  day: string;           // 'TODAY' | 'MON' | …
  date: string;          // 'OCT 27' pre-formatted
  icon: 'sun' | 'cloud' | 'rain';
  hi: number; lo: number;   // °C
  wind: number;             // km/h
  score: number;            // 0..10
  label: string;            // 'Perfect window' | 'Storm forecast' | …
}
interface ForecastHour { time: Date; tempC: number; }
interface ForecastAlert { color: string; icon: IconName; title: string; sub: string; }
interface ForecastDetailTile { icon: IconName; label: string; value: string; unit?: string; sub: string; }
```

| Field | Status | Notes |
|---|---|---|
| All fields | ➕ MISSING IN SCHEMA | Fetched live from Open-Meteo, same as Flutter. `useCurrentWeather` already shipped — needs siblings `useForecast(location)` returning the full 7-day + hourly + alerts. |
| `icon` enum | 🎨 DESIGN-ONLY | WMO weather code 0-99 → `sun` / `cloud` / `rain`. |
| `score`, `label` | 🎨 DESIGN-ONLY | Derived. `score` is the existing `hikeScore` formula; `label` is bucketed from score. |

---

## 6. Notification

**Source:** `notifications.jsx:5` (`NOTIFS`).

```ts
interface Notification {
  id: number | string;
  kind: 'weather' | 'hazard' | 'team' | 'mention' | 'achievement' | 'system' | 'review';
  urgent?: boolean;
  time: string;          // '2m ago' relative
  title: string;
  sub: string;
  action: string;        // CTA label
  read: boolean;
}
```

| Field | Status | Notes |
|---|---|---|
| All fields | ➕ MISSING IN SCHEMA | No `notifications` table. `notification_settings` exists for per-channel toggles, not delivered events. **Blocker.** |

---

## 7. FeedPost (Community feed)

**Source:** `community.jsx:79-101` + `:136` (props).

```ts
interface FeedPost {
  id: string;
  user: { name: string; initials: string; color: string };
  time: string;                                                   // '14m ago'
  location: string;
  text: string;
  stats?: { dist: string; gain: string; time: string };           // optional rich stats
  likes: number;
  comments: number;
  hazard?: boolean;                                               // amber stripe + HAZARD pill
  attached?: AttachedElev | AttachedGpx | null;
}
interface AttachedElev { kind: 'elev'; samples: number[]; }
interface AttachedGpx  { kind: 'gpx';  filename: string; waypoints: number; bytes: number; }
```

| Field | Status | Notes |
|---|---|---|
| All fields | ➕ MISSING IN SCHEMA | `community_activities` exists (0 rows, columns not introspected). **Blocker** — extend or replace with `posts` + `post_likes` + `post_comments`. |

---

## 8. ChatMessage (team chat + community chat)

**Source:** `community.jsx:294-303`.

```ts
interface ChatMessage {
  id: string;
  time: Date;
  sender: { id: string; name: string; initials: string; color: string };
  mine: boolean;        // computed: sender.id === currentUid
  text: string;
  reaction?: string;    // emoji
  roomId: string;
}
```

| Field | Status | Notes |
|---|---|---|
| All fields | ✅ MATCH (partial) | `chat_messages` table exists with REPLICA IDENTITY FULL. Flutter `ChatMessage` covers `senderId`, `senderName`, `text`, `timestamp`, `type`, `todo`, `poll`, `roomId`. |
| `reaction` | ➕ MISSING IN SCHEMA | Need to introspect — if absent, add `reactions: jsonb`. **Research item before chat screen lands.** |

---

## 9. TeamMemberLive — live team-tracking row

**Source:** `team.jsx:53-56`.

```ts
interface TeamMemberLive {
  uid: string;
  name: string;
  initials: string;
  color: string;
  loc: string;            // 'Sunrise Camp' — named place
  distanceKm: number;
  altitudeM: number;
  speedKmh: number;
  batteryPct: number;
  connectivity: 'wifi' | 'mobile' | 'none' | null;
  lead: boolean;          // team.created_by === uid
  alert: boolean;         // batteryPct <= 15 || connectivity === 'none' || age > 30min
  lastSeen: Date;
}
```

vs `TeamMemberLocationRow`:

| Design | DB | Status |
|---|---|---|
| `uid`, `name` | `uid`, `display_name` | ✅ MATCH |
| `initials`, `color` | — | 🎨 DESIGN-ONLY |
| `loc` (named place) | — | ➕ MISSING IN SCHEMA — reverse geocoding. **Blocker.** Fallback: `${distanceKm} km` until geocoder lands. |
| `distanceKm` | — | 🎨 DESIGN-ONLY — distance into active hike, computed client-side from `team_member_locations` history. |
| `altitudeM` | `altitude` | ✅ MATCH (rename) |
| `speedKmh` | `speed` | ✅ MATCH (DB stores m/s, convert) |
| `batteryPct` | `battery_pct` | ✅ MATCH |
| `connectivity` | `connectivity` | ✅ MATCH |
| `lead` | derived from `teams.created_by` | 🎨 DESIGN-ONLY |
| `alert` | derived | 🎨 DESIGN-ONLY |
| `lastSeen` | `timestamp` | ✅ MATCH |

---

## 10. ActiveSafetyPlan

**Source:** `safety.jsx:43` (`ActivePlanCard`).

```ts
interface ActiveSafetyPlan {
  trailName: string;
  expectedReturn: Date;
  backpack: string;       // 'Orange · 65L'
  tent: string | null;    // '—' when none
  watcherCount: number;
  lastPing: Date;
  gear: GearChecklistItem[];
}
interface GearChecklistItem { id: string; label: string; sub: string; done: boolean; }
```

| Field | Status | Notes |
|---|---|---|
| All fields | ➕ MISSING IN SCHEMA | Flutter stores plans in SharedPreferences. **Blocker** for server-side sharing. Mirror locally via Zustand + AsyncStorage for now. |

---

## 11. EmergencyContact

**Source:** `safety.jsx:134-141`.

```ts
interface EmergencyContact {
  id: string;
  name: string;
  sub: string;                  // 'Spouse' | 'Hiking partner' | '24/7 · Drakensberg'
  phone: string;
  type: 'rescue' | 'ambulance' | 'personal';
}
```

vs `ProfileRow`:

| Design | DB | Status |
|---|---|---|
| `name`, `sub`, `type` | — | ➕ MISSING IN SCHEMA |
| `phone` | `emergency_contact_phone` | ⚠ CONFLICT — only ONE phone on `profiles`, but the design supports multiple. **Blocker** — new `emergency_contacts` child table. |

Rescue / ambulance entries (MSAR, ER24) ship as a **static constant** keyed by region in `src/data/rescue_services.ts` — not user-editable.

---

## 12. SOSIncident + SOSResponder + IncidentTimelineEvent + NearbyHazard

**Source:** `sos.jsx:28`, `:146`, `:230`, `:187-189`.

```ts
interface SOSIncident {
  id: string;              // 'INCIDENT #7731'
  beacon: string;          // 'BEACON ALPHA-7'
  startedAt: Date;
  lat: number; lon: number;
  altitudeM: number; accuracyM: number;
  responder?: SOSResponder;
  nearbyHazards: NearbyHazard[];
  timeline: IncidentTimelineEvent[];
}
interface SOSResponder {
  name: string;            // 'RESCUE TEAM #4'
  status: 'en route' | 'on scene' | 'cleared';
  etaMinutes: number;
  distanceMetres: number;
  signalBars: number;      // 0..4
}
interface NearbyHazard {
  id: string;
  iconName: IconName;
  title: string;
  sub: string;             // distance + cardinal + street
  risk: 'low' | 'moderate' | 'high' | 'info';
  reportedAt: Date;
}
interface IncidentTimelineEvent {
  at: Date; label: string;
  status: 'done' | 'active' | 'pending';
}
```

vs `IncidentRow`:

| Design | DB | Status |
|---|---|---|
| `id`, `lat`, `lon` | ✅ MATCH | |
| `beacon` | — | ➕ MISSING IN SCHEMA — **Blocker** (`incidents.beacon_id text`). |
| `startedAt` | `reported_at` | ✅ MATCH (rename) |
| `altitudeM`, `accuracyM` | — | ➕ MISSING — stash in existing `incidents.metadata: jsonb`. |
| `responder` (partial) | `assigned_to_uid` + `assigned_to_name` | ✅ MATCH (partial) — status / ETA / distance / signal not in DB. |
| `nearbyHazards` | — | ➕ COMPUTED — `incidents` within 500m of incident point. Needs PostGIS or app-side filter. |
| `timeline` | — | ➕ MISSING IN SCHEMA — **Blocker** (`incident_events` child table). |

---

## 13. Waypoint + RoutePlan (Plan Route)

**Source:** `plan-route.jsx:44-47`.

```ts
interface Waypoint {
  num: string;              // 'A' | '1' | '2' | …
  type: 'start' | 'poi' | 'shelter' | 'end';
  name: string;
  sub: string;              // 'km 5.8 · water · 6 sleepers'
  km: number;
}
interface RoutePlan {
  id: string | null;        // null when unsaved
  name: string;             // 'Cathedral Peak · solo · Saturday'
  date: Date;
  startTime: string;        // 'HH:mm'
  waypoints: Waypoint[];
  tetherWatcherId: string | null;
  totalKm: number;
  ascentM: number;
  durationMinutes: number;
}
```

| Field | Status | Notes |
|---|---|---|
| All fields | ➕ MISSING IN SCHEMA | No `route_plans`. **Blocker** — mirror `hike_plans` with `waypoints: jsonb`, or full `route_plans` + `route_waypoints` tables. |

---

## 14. WelcomeFeature

**Source:** `welcome.jsx:4` (`FEATURES`).

```ts
interface WelcomeFeature {
  id: 'tether' | 'plan' | 'navigate' | 'aware' | 'sos';
  eyebrow: string; title: string; body: string;
  color: string;
}
```

| Field | Status | Notes |
|---|---|---|
| All | 🎨 DESIGN-ONLY | Pure marketing copy. Stays in `src/data/welcome_features.ts` static constant. |

---

## 15. SearchResult (4 variants)

**Source:** `search.jsx:7-25` (`ALL`).

```ts
type SearchResult =
  | { kind: 'trail';  id: string; name: string; region: string; km: number; diff: Difficulty }
  | { kind: 'person'; id: string; name: string; sub: string; initials: string; color: string }
  | { kind: 'cave';   id: string; name: string; km: number; capacity: string }
  | { kind: 'report'; id: string; title: string; who: string; reportedAt: Date };
```

| Kind | Source |
|---|---|
| `trail` | ✅ Bundled `routes_cleaned.json` |
| `person` | ✅ `profiles` table |
| `cave` | ✅ Bundled `caves.gpx` (same as Flutter) |
| `report` | ✅ `incidents` table |

Recent searches → Zustand + AsyncStorage slice (BLOCKERS.md #8).

---

## 16. SettingsRow + SettingsGroup

**Source:** `settings.jsx:20-64`.

```ts
type SettingsRow =
  | { kind: 'value';  icon: IconName; label: string; value: string; href?: string; badge?: Badge }
  | { kind: 'toggle'; icon: IconName; label: string; storageKey: string; defaultOn: boolean }
  | { kind: 'link';   icon: IconName; label: string; href: string };
interface Badge { label: string; color: string; }
interface SettingsGroup { title: string; rows: SettingsRow[]; }
```

| Field | Status | Notes |
|---|---|---|
| All | 🎨 DESIGN-ONLY | Row config in code; actual stored values come from `notification_settings` + `weather_locations` + AsyncStorage. |

---

## 17. EditableProfile

**Source:** `edit-profile.jsx:55-100`.

```ts
interface EditableProfile {
  fullName: string;
  username: string;
  email: string;           // disabled, set by auth
  region: string;          // 'Cape Town, ZA'
  bio: string;             // max 140
  experienceLevel: 'beginner' | 'intermediate' | 'advanced' | 'expert';
  interests: string[];
}
```

vs `ProfileRow`:

| Design | DB | Status |
|---|---|---|
| `fullName` | `display_name` | ✅ MATCH (rename) |
| `username` | `username` | ✅ MATCH |
| `email` | `email` | ✅ MATCH (read-only) |
| `region` | — | ➕ MISSING IN SCHEMA |
| `bio` | — | ➕ MISSING IN SCHEMA |
| `experienceLevel` | — | ➕ MISSING IN SCHEMA |
| `interests` | — | ➕ MISSING IN SCHEMA |

Single migration adds: `profiles.region`, `profiles.bio`, `profiles.experience_level`, `profiles.interests`. **Blocker.**

---

## 18. Cross-cutting enums

| Enum | Authoritative values | Used by | Decision |
|---|---|---|---|
| `Difficulty` | `'easy' \| 'moderate' \| 'difficult' \| 'technical'` (matches `tokens.ts`) | Trail, TrailListItem, HikeRecord, SearchResult trail, TrailSegment | **Keep tokens.ts.** Adapters translate `'mod'/'hard'/'xhard'` → canonical. |
| `Rarity` | `'common' \| 'rare' \| 'epic' \| 'legendary'` (matches `tokens.ts`) | Achievement | **Keep tokens.ts.** |
| `HazardKind` | `'water' \| 'shelter' \| 'danger' \| 'view' \| 'summit'` | Trail.hazards | **New.** Distinct from `IncidentRow.type` which is broader (`'rockfall' \| 'weather' \| 'sos' \| …`); adapters map between them. |
| `Risk` | `'low' \| 'moderate' \| 'high' \| 'info'` | NearbyHazard (SOS) | **New.** Derived from `IncidentRow.severity`. |
| `NotificationKind` | `'weather' \| 'hazard' \| 'team' \| 'mention' \| 'achievement' \| 'system' \| 'review'` | Notification | **New** — needs DB enum once `notifications` ships. |
| `ResponderStatus` | `'en route' \| 'on scene' \| 'cleared'` | SOSResponder | **New** — `incidents.responder_status`. |
| `ExperienceLevel` | `'beginner' \| 'intermediate' \| 'advanced' \| 'expert'` | EditableProfile | **New** — `profiles.experience_level` with CHECK. |

---

## Resolution proposal — summary

### New files to create (pending approval)

1. **`src/data/types.ts`** — every entity above as a TypeScript interface (camelCase, UI-shaped).
2. **`src/data/adapters.ts`** — `fromRow(row: XRow): XDomain` for every entity. Snake_case → camelCase, timestamp → Date, units, derived fields (`accent`, `mine`, `lead`/`alert`).
3. **`src/data/enums.ts`** — canonical enums + map functions for inbound design strings.
4. **`src/data/achievements.ts`** — static 16-entry catalog mirroring `achievements.jsx:all`.
5. **`src/data/welcome_features.ts`** — 5-entry onboarding pillars.
6. **`src/data/rescue_services.ts`** — static MSAR + ER24 by region.

### BLOCKERS.md additions (extending the existing 8)

- **#9** Trails catalog bundled asset (copy `routes_cleaned.json` + `caves.gpx` from `../trailtether_app/assets/data/`).
- **#10** `v_trail_metadata` view — rating, reports, tags, segments, hazards, prep per trail.
- **#11** `hike_history.score` column (letter grade).
- **#12** `notifications` table + `mark_read` RPC.
- **#13** `community_activities` schema audit & extension.
- **#14** `chat_messages.reactions` column or child table.
- **#15** `safety_plans` table for server-side sharing.
- **#16** `emergency_contacts` child table (multi-row per user).
- **#17** SOS extras: `beacon_id`, responder ETA/distance/signal, `incident_events` child table, PostGIS proximity.
- **#18** `route_plans` + `route_waypoints` tables.
- **#19** Profile extras migration: `region`, `bio`, `experience_level`, `interests`.
- **#20** Reverse geocoding for team-member `loc` strings.

### Existing BLOCKERS.md entries that resolve now

- #1 Upcoming hikes → wired
- #2 Last hike → wired
- #3 Weather location → wired
- #5 Achievements → resolved by static catalog
- #6 Trails catalog → replaced by #9 above
- #8 Recent searches → resolved by `useSearch` hook + AsyncStorage slice

---

## ⛳ Awaiting your approval

Reply **"approve types"** to author `src/data/types.ts` + `adapters.ts` + `enums.ts` + the three static catalogs, OR send edits:

- Disagree with an enum value? Tell me which.
- Want a field renamed / merged / split? Say which.
- Want me to push back on a "DESIGN-ONLY" call and persist something server-side? Say which.
- Different BLOCKERS.md priority? Reorder.

No types module ships until I hear back.
