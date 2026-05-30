---
tags: [type/endpoint, layer/backend, status/stable, domain/recording, hardware/garmin]
aliases: [watch-route edge function]
source_paths: [supabase/functions/watch-route/index.ts]
---

# watch-route

**POST** `/functions/v1/watch-route` — called by the [[Watch App Module|Garmin watch]] for both list mode (route picker population) and by-id mode (load a specific course into the watch's RouteCourse).

Unions the **curated catalogue** (`public.trails`, ~197 published rows with `coords` JSONB `[[lon,lat,ele]]`) with the user's **personal recordings** (`public.recorded_trails`, GPX in Storage) so the watch can pick any trail to follow.

## Auth

`verify_jwt: true` — anon JWT satisfies the gate. User resolved from `x-device-token` against [[watch_devices]] (service-role bypass inside the function).

## Modes

### 1. List (body `{action: "list"}`)

Returns the route picker's data:

```json
{
  "ok": true,
  "routes": [
    { "id": "0mnweni_marathon", "name": "0mnweni-marathon" },
    { "id": "apes_pass", "name": "Apes Pass" },
    ...
    { "id": "<uuid>", "name": "Hike (Watch)" }
  ]
}
```

180 bundled (alphabetical) + 20 most-recent personal. **Payload trimmed to `{id, name}` only** — fitting CIQ's ~16 KB HTTP buffer cap. (The fuller `{id, name, distance_km, ascent_m}` payload was 23 KB and triggered HTTP-402 "response too large" on the watch.) Distance + ascent come back on the by-id fetch.

### 2. By-id (body `{id: "<route_id>"}`)

Returns a single course downsampled for the watch:

```json
{
  "ok": true,
  "course": {
    "id": "apes_pass",
    "name": "Apes Pass",
    "total_m": 4005,
    "dist": [0, 84, 167, ...],   // cumulative metres (≤48 points)
    "elev": [2987, 2992, ...],
    "lat":  [-29.137488, ...],   // 6-decimal precision
    "lon":  [29.354079, ...]
  }
}
```

ID disambiguation is by **UUID regex**:
- UUID-shaped → `recorded_trails` filtered by `user_id` (user's own).
- Non-UUID → `trails` filtered by `published = true` (curated catalogue).

### 3. No body / `{}` (legacy)

Returns the user's `active_route_id` (set via [[set_watch_active_route]]) or, failing that, their most recent recorded trail. Used by `RouteService.fetch()` on launch + on MENU-hold.

## Downsampling

`downsamplePath(lats, lons, eles, N=48)` — bumped from 32 → 48 in v3 so the Map page polyline reads as a real route, not just a sparkline.

## Versions

- v2 (2026-05-29) — initial; dist + elev only, active-route or recent.
- v3 (2026-05-30) — added `action: "list"`, by-id mode, `lat`/`lon` in course.
- v5 (2026-05-30) — unions `trails` (curated) + `recorded_trails` (personal).
- v6 (2026-05-30) — list payload trimmed to `{id, name}` (HTTP-402 fix).

## Related

- [[Watch App Module]] — caller (`RouteService.fetchList` / `.fetchById` / `.fetch`)
- [[trails]] — curated catalogue (text id, `coords` JSONB)
- [[recorded_trails]] — personal recordings (UUID id, GPX in Storage)
- [[set_watch_active_route]] — phone-side RPC for the legacy active-route mode
