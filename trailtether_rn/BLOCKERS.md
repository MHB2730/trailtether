# BLOCKERS — Trailtether RN

Every design surface that needs data the Supabase schema or local stores
can't satisfy. Don't invent shapes — pause here, document, then either
add a real endpoint or wire the screen to an existing one.

When you add a new entry, include:

* **Screen** — which file in `app/` it's for
* **Shape** — the minimum TypeScript interface the UI needs
* **Suggested endpoint** — Supabase view, RPC, edge function, or third-party
* **Notes** — why the existing schema doesn't already cover it

When you resolve an entry, move it to **Resolved** at the bottom with a
one-liner pointing at the commit / migration that closed it.

---

## Active blockers

### 5. Per-user achievement progress — remaining 8 catalog ids

* **Screen** — `app/achievements.tsx`, `(tabs)/profile.tsx`
* **Status** — **PARTIALLY RESOLVED.** Eight catalog ids now derive
  per-user from `v_user_achievement_progress`: `first`, `gpx`,
  `highrise`, `5k`, `centurion`, `lead`, `guide`, `sos`. The
  remaining 8 still need signals we don't track yet:
  - weather correlation (`rain`, `storm`, `winter`) — needs forecast
    snapshot stored alongside each hike
  - time-of-day (`dawn`, `allnight`) — needs hike start/end
    timestamps decoded from `hike_history.points`
  - shelter proximity (`cave`) — needs the route to be checked
    against the bundled shelters at insert time
  - paired-PC record (`tether`) — needs a `tether_pairings` table
  - route compliance (`navmaster`) — needs deviation metric vs
    target route
* Achievements screen surfaces this with a partial banner.

### 18. Tools-tab native sensors (compass / altimeter / level)

* **Screen** — `app/(tabs)/tools.tsx`
* **Need** — Compass needs `expo-sensors` Magnetometer; altimeter
  needs the barometer subscription; level needs the accelerometer.
* **Status** — **PENDING NATIVE INSTALL.** Map half of #18 is
  closed (`react-native-maps` installed; MapView wired to Map tab
  and Trail Detail).

---

## Resolved

* **#1 — Upcoming hikes:** `useUpcomingHikes` reads `hike_plans` via team
  filter; convenience view `v_upcoming_hikes_for_user` shipped in
  `v_upcoming_hikes_for_user_20260523`.
* **#2 — Last hike:** Wired via `useLastHike`.
* **#3 — Weather location:** Wired via `useHomeWeatherLocation` +
  `useCurrentWeather` (Open-Meteo).
* **#5 — Achievements catalog + 5 derived ids:** Catalog ships as
  `ACHIEVEMENTS_CATALOG`. Five ids derive per-user from
  `v_user_achievement_progress` (BLOCKERS #5 partial — see active
  block above for the rest).
* **#6 / #9 — Trails + caves bundle:** `assets/data/routes_cleaned.json`
  and `caves.gpx` copied from the Flutter app. `useTrailsCatalog()` +
  `useTrail()` load via `expo-asset`.
* **#7 — Hex medallion progress wavefront:** AchievementMedallion
  renders the magma fill from the catalog entry's `progress` prop.
* **#8 — Recent searches:** Local AsyncStorage Zustand slice.
* **#10 — Trail metadata view:** `trail_metadata` editorial table +
  `v_trail_metadata` view shipped in
  `trail_metadata_table_and_view_20260523`. `useTrailExtras()` reads it
  on the Trail Detail screen; segments / hazards / prep render when an
  editorial row exists, otherwise an inline note.
* **#11 — Hike letter grade:** `hike_history.score char(1)` + scoring
  trigger + backfill shipped in `hike_history_score_20260523`. History
  rows render the letter directly.
* **#12 — Notifications table + RPC:** Shipped in
  `notifications_table_20260523`. `useNotifications()` + the
  `mark_notification_read(uuid)` RPC back the Notifications screen.
* **#14 — Chat reactions:** `chat_messages.reactions jsonb` + GIN index
  shipped in `chat_messages_reactions_20260523`. Adapter parses
  `[{ emoji, by_uid, at }]` and surfaces the current user's reaction.
* **#15 — Safety plans:** `safety_plans` table + `ping_safety_plan(uuid)`
  RPC shipped in `safety_plans_table_20260523`. `useActiveSafetyPlan()`
  + Safety screen renders the active plan + gear checklist.
* **#16 — Emergency contacts:** `emergency_contacts` child table +
  one-shot backfill shipped in `emergency_contacts_table_20260523`.
  Safety screen reads via `useEmergencyContacts()`.
* **#17 — SOS extras + incident timeline:** Columns added to
  `incidents` + `incident_events` child shipped in
  `incidents_sos_extras_20260523`. SOS screen renders responder card
  + dispatch timeline via `useIncidentTimeline()`.
* **#18 — Route plans + waypoints:** `route_plans` +
  `route_waypoints` shipped in `route_plans_tables_20260523`. Plan
  Route saves a header row + start/end stub waypoint pair and
  mirrors into `hike_plans` so the Home upcoming-hike card sees it.
* **#13 — Community posts:** `posts` / `post_likes` / `post_comments`
  shipped in `community_posts_trio_20260523` with counter triggers.
  `usePosts()` + `togglePostLike()` wire the Community feed to the
  real table; `community_activities` stays untouched for Flutter
  compat.
* **#19 — Profile extras:** `profiles` got `region, bio,
  experience_level, interests` in `profiles_extras_20260523`. Edit
  Profile writes all four; Profile header surfaces region, bio, and
  experience badge.
* **#20 — Reverse geocoding via bundled shelters:** 125 caves parsed
  from `assets/data/caves.gpx` into `src/data/shelters.ts` (static
  array + haversine `nearestShelter`). `teamMemberLiveFromRow` now
  renders `Near <name> · <distance> km` for any team member within
  3 km of a shelter; falls back to a coord snippet otherwise.
* **#4 — Field intel proximity scoping:** `useFieldIntel({ center,
  radiusKm })` filters open incidents client-side via haversine from
  the user's first `weather_locations` row. Home Field-Intel card
  + Map tab hazard pins both scope to within 80–100 km. No schema
  change needed.
* **#18 (Map half) — Real tile renderer:** Installed
  `react-native-maps@1.18.0`. `src/components/design/TrailMap.tsx`
  renders trails (Polyline), team members (Marker), hazards
  (Marker) and optional shelter pins over the platform map. Map
  tab and Trail Detail both use it. Tools-tab sensors stay active
  above.
