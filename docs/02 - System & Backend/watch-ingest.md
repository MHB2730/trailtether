---
tags: [type/endpoint, layer/backend, status/stable, domain/recording, hardware/garmin]
aliases: [watch-ingest edge function]
source_paths: [supabase/functions/watch-ingest/index.ts]
---

# watch-ingest

**POST** `/functions/v1/watch-ingest` — called by the [[Watch App Module|Garmin watch]] after a hike is saved.

Writes a [[hike_history]] row, builds a GPX and uploads it to the `recorded-trails` Storage bucket, and inserts a parallel [[recorded_trails]] row so the hike appears in the user's gallery + maps the same as any phone-recorded hike.

## Auth

`verify_jwt: true` — anon JWT satisfies the gate. The user is resolved server-side from the **`x-device-token`** header against [[watch_devices]] using the service-role key. Unknown token → 403.

## Request body

```json
{
  "name": "Hike (Watch)",
  "distance_km": 7.8,
  "ascent_m": 804,
  "descent_m": 0,
  "duration_seconds": 16100,
  "activity_type": "hike",
  "points": [
    { "lat": -29.0, "lon": 29.3, "alt": 2400.0, "ts": 1747401600, "spd": 1.2, "acc": 0 },
    ...
  ]
}
```

`points[]` capacity is **capped at 10 000** server-side. The watch downsamples to 250 before sending; the cap is a defence ceiling against a compromised device-token bloating the Storage bucket. Over-cap requests return **413**.

## Response

```json
{
  "ok": true,
  "hike_id": "uuid",
  "points": 250,
  "trail": { "id": "uuid", "hike_id": "uuid", "gpx_path": "<user_id>/<hike_id>.gpx" },
  "trail_error": null
}
```

`trail` is null + `trail_error` is populated if the GPX upload or `recorded_trails` insert fails, but the `hike_history` row is still written so stats survive.

## Side effects

- INSERT [[hike_history]] (`accepted_fixes` set to `points.length`).
- UPLOAD GPX to `recorded-trails` Storage bucket at `${user_id}/${hikeId}.gpx`. Mirrors [[recorded_trail_service.dart|RecordedTrailService._buildGpx]] so the app's regex parser round-trips.
- UPSERT [[recorded_trails]] (`onConflict: user_id, hike_id`).
- UPDATE `watch_devices.last_seen_at`.

## Versions

- v5 (2026-05-29) — current GPX + recorded_trails plumbing.
- v6 (2026-05-30) — added `MAX_POINTS = 10000` cap; `lat`/`lon` formatted to `.toFixed(6)` for consistent GPX precision.

## Related

- [[Watch App Module]] — caller (`SyncService.upload`)
- [[watch_devices]] — token → user_id resolution
- [[hike_history]], [[recorded_trails]] — output rows
