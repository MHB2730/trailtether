---
tags: [type/module, layer/frontend, status/stable, domain/io]
aliases: [Services]
source_paths: [trailtether_app/lib/services]
---

# Flutter Services Module

Stateless I/O wrappers. 27 service files — most are static-method classes (no instance state).

## Categories

### Supabase / data services

| Service | Role | Key file |
|---|---|---|
| [[trail_service.dart]] | Curated trail catalogue loader (Supabase → cache → bundle fallback) | `lib/services/trail_service.dart` |
| [[trail_repository.dart]] | Supabase CRUD + on-disk cache for [[trails]] table | `lib/services/trail_repository.dart` |
| [[recorded_trail_service.dart]] | Upload SavedHike → [[recorded_trails]] table + GPX to Storage | `lib/services/recorded_trail_service.dart` |
| [[incident_service.dart]] | Stream / create / update incidents, photo upload | `lib/services/incident_service.dart` |
| [[gpx_service.dart]] | Parse + upload GPX, fetch shared cloud tracks | `lib/services/gpx_service.dart` |
| [[review_service.dart]] | CRUD on [[reviews]] table | `lib/services/review_service.dart` |
| [[cave_waypoint_service.dart]] | Loads `assets/data/caves.gpx` into [[CaveWaypoint]] objects | `lib/services/cave_waypoint_service.dart` |
| [[accommodation_service.dart]] | Loads bundled accommodation data | `lib/services/accommodation_service.dart` |
| [[routing_service.dart]] | Dijkstra over trail graph for waypoint routing | `lib/services/routing_service.dart` |

### Location + recording

| Service | Role |
|---|---|
| [[location_service.dart]] | Geolocator wrapper. Defines `recordingLocationSettings`, `liveLocationSettings`, `batterySaverSettings`. Owns the Kalman-smoothed position stream. |
| [[offline_track_queue.dart]] | SharedPreferences FIFO buffer for tracking points when offline |

### Notifications + alerts

| Service | Role |
|---|---|
| [[notification_service.dart]] | flutter_local_notifications wrapper |
| [[weather_service.dart]] | Open-Meteo + BigDataCloud reverse geocode |
| [[weather_alert_service.dart]] | Proactive 6-hour lookahead, dedupe per (uid, severity-band) |
| [[hazard_service.dart]] | Generates GeoJSON hazard zones from weather codes |

### Update + deep links

| Service | Role |
|---|---|
| [[update_service.dart]] | Android: poll [[app_releases]]. Windows: poll GitHub. Downloads + SHA-256 verify + sideload. |
| [[deep_link_service.dart]] | Handles `trailtether://login-callback?code=...` for desktop OAuth |
| [[offline_map_service.dart]] | FMTC tile cache (ObjectBox backend) |

### Cross-cutting

| Service | Role |
|---|---|
| [[logger_service.dart]] | File logger (rotates at 2MB) + Supabase `app_logs` sync |

## Patterns

- Most services are **static method classes** (no instance) → testing requires mocking globals.
- `Future<T>` returns are wrapped in try/catch; failures logged via [[logger_service.dart]] then returned as `null` or empty list. Caller decides how to surface.
- `Stream<T>` returns come from `supabase.from(...).stream(...)` (e.g. [[incident_service.dart]]).
- Storage uploads via `_db.storage.from('bucket').uploadBinary(...)`.

## Service ↔ provider mapping

| Provider | Services it calls |
|---|---|
| [[recording_provider.dart]] | [[location_service.dart]], [[logger_service.dart]], [[weather_alert_service.dart]] |
| [[hike_history_provider.dart]] | [[recorded_trail_service.dart]], [[logger_service.dart]] |
| [[recorded_trails_provider.dart]] | [[recorded_trail_service.dart]] |
| [[static_data_provider.dart]] | [[trail_service.dart]] (which calls [[trail_repository.dart]]) |
| [[gpx_provider.dart]] | [[gpx_service.dart]] |
| [[team_tracking_provider.dart]] | (Supabase directly) + [[offline_track_queue.dart]] |
| [[safety_provider.dart]] | [[incident_service.dart]], [[notification_service.dart]] |
| [[weather_provider.dart]] | [[weather_service.dart]] |
| [[routing_provider.dart]] | [[routing_service.dart]] |
| [[chat_provider.dart]] | (Supabase directly) |
| [[review_provider.dart]] | [[review_service.dart]] |

## Used by

- [[Flutter Providers Module]] (primary consumer)
- Some screens call services directly for one-shot operations (e.g. [[PcTrailsScreen]] uses [[trail_repository.dart]] directly)

## Depends on

- `supabase_flutter` for DB + Storage
- `geolocator`, `flutter_local_notifications`, `gpx`, `http`, `path_provider` — see [[Tech Stack]]
