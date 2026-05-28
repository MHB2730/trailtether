---
tags: [type/module, layer/frontend, status/stable, domain/data]
aliases: [Models]
source_paths: [trailtether_app/lib/models]
---

# Flutter Models Module

Domain types: 16 Dart classes representing what the app reads/writes/computes.

## Models

| Model | File | What it is | Note |
|---|---|---|---|
| [[Trail Model]] | `trail.dart` | Curated trail catalogue entry (with TrailCoord + ElevationPoint sub-types) — heavy `fromJson` does RDP + Chaikin smoothing | [[trails]], [[trail_service.dart]] |
| [[RecordingPoint]] | `recording_point.dart` | One GPS fix during recording | persisted in [[recorded_trails]] GPX |
| [[SavedHike]] | `saved_hike.dart` | Finished hike — totals + full point list | feeds [[hike_history]] + [[recorded_trails]] |
| [[RecordedTrail]] | `recorded_trail.dart` | Metadata view of a recorded trail (GPX in Storage, row in DB) | [[recorded_trails]] |
| `Team` | `team.dart` | Team model | [[teams]] |
| `TeamMemberLocation` | `team.dart` (same file) | Last known team-member position | [[team_member_locations]] |
| `HikerProfile` | `hiker_profile.dart` | Local hiker profile with achievements | [[profiles]] |
| `Incident` | `incident.dart` | Hazard / SOS / weather event | [[incidents]] |
| `CaveWaypoint` | `cave_waypoint.dart` | A cave on the map | bundled in `caves.gpx` |
| `Accommodation` | `accommodation.dart` | Lodging waypoint | bundled |
| `GpxTrack` | `gpx_track.dart` | User-imported GPX track + UserGpxTrack | [[gpx_uploads]] |
| `Weather` (`WeatherData`) | `weather.dart` | Open-Meteo response shape | not stored |
| `Plan` (HikePlan) | `saved_hike.dart` (related) | Pre-trail safety plan | [[hike_plans]] |
| `Review` | `review.dart` | Trail review | [[reviews]] |
| `Achievement` | `achievement.dart` | Achievement definition | client-side only |
| `RouteWaypoint` | (within routing) | Waypoint for [[routing_provider.dart]] | — |

## Conventions

- Most models are immutable (`final` fields) with `fromJson` / `toJson`.
- `factory X.fromJson(Map<String, dynamic>)` is the standard constructor.
- Some (like [[Trail Model]]) do heavy work in `fromJson` (smoothing, distance calc, difficulty derivation).
- Lat/Lon storage: most use `latlong2.LatLng`. Trail's `TrailCoord` is custom (lon, lat, elevation tuple).

## Important: lat/lon ordering

[[Trail Model]] uses `TrailCoord(lon, lat, elevation)` positional args. The bundled JSON stores `[lon, lat, ele]` triples. Heads up if you ever migrate this data.

## Used by

- [[Flutter Providers Module]] — providers hold lists of models
- [[Flutter Services Module]] — services serialize/deserialize to/from Supabase
- [[Flutter Screens Module]] — UI binds to model fields

## Depends on

- `latlong2` for LatLng primitives
- `intl` for date formatting in `toString` overrides
- (no other deps — pure domain)
