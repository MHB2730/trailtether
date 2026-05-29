---
tags: [type/module, layer/frontend, status/stable, domain/io]
aliases: [Services]
source_paths: [trailtether_app/lib/services]
---

# Flutter Services Module

Stateless I/O wrappers. 29 service files in `lib/services/` — most are static-method classes (no instance state).

## Supabase / data services

| Service | Role |
|---|---|
| [[trail_service.dart]] | Curated trail catalogue loader — Supabase → cache → bundle fallback (`routes_cleaned.json`) |
| [[trail_repository.dart]] | Supabase CRUD + on-disk cache for `trails` table; used directly by [[PcTrailsScreen]] |
| [[recorded_trail_service.dart]] | Upload `SavedHike` → `recorded_trails` table + GPX to Storage; `increment_recorded_trail_downloads` RPC |
| [[incident_service.dart]] | Stream / create / update incidents, photo upload to `incident-photos` bucket |
| [[gpx_service.dart]] | Parse + upload GPX files, fetch shared cloud tracks from `gpx_uploads` |
| [[review_service.dart]] | CRUD on `reviews` table |
| [[cave_waypoint_service.dart]] | Loads `assets/data/caves.gpx` into `CaveWaypoint` objects |
| [[accommodation_service.dart]] | Loads bundled accommodation data (no live table) |
| [[routing_service.dart]] | Dijkstra over trail graph for waypoint routing |
| `chat_service.dart` | `ChatService.streamMessages(roomId)` — Supabase Realtime stream of last 60 `chat_messages` rows |
| `community_service.dart` | `CommunityService.fetchActivities()` + `fetchLeaderboard()` — `community_activities` table + leaderboard RPC |
| `team_service.dart` | `TeamService` — fetch teams for user, create team, invite/remove members, `join_team_by_invite_code` RPC |
| `auth_service.dart` | `AuthService` — auth state stream, Google sign-in, sign-out. Wraps `google_sign_in` + `supabase_flutter` auth |

## Location + recording

| Service | Role |
|---|---|
| [[location_service.dart]] | Geolocator wrapper. Defines `recordingLocationSettings`, `liveLocationSettings`, `batterySaverSettings`. Owns the Kalman-smoothed position stream. |
| [[offline_track_queue.dart]] | SharedPreferences FIFO buffer for GPS tracking points when offline |
| [[offline_incident_queue.dart]] | SharedPreferences FIFO buffer for off-trail alert submissions — retries on reconnect (4 unit tests) |

## Weather + alerts

| Service | Role |
|---|---|
| [[weather_service.dart]] | Open-Meteo primary + BigDataCloud reverse geocode |
| `weather_aggregator_service.dart` | Fetches Open-Meteo (primary) + Met Norway (secondary) in parallel; folds secondary into current reading via median/mean so one bad reading can't poison the forecast |
| [[weather_alert_service.dart]] | Proactive 6-hour lookahead; dedupes alerts per `(uid, severity-band)` |
| [[hazard_service.dart]] | Generates GeoJSON hazard zones from weather codes |

## Notifications + cross-cutting

| Service | Role |
|---|---|
| [[notification_service.dart]] | `flutter_local_notifications` wrapper — singleton |
| [[logger_service.dart]] | File logger (rotates at 2 MB) + Supabase `app_logs` sync. Exposes `LoggerService.log()` / `LoggerService.error()` |
| [[telemetry_service.dart]] | Sentry init (`TelemetryService.init(dsn:)`) + error reporting |

## Update + deep links + platform

| Service | Role |
|---|---|
| [[update_service.dart]] | Android: polls `app_releases` table. Windows: polls GitHub. Downloads + SHA-256 verify + sideload via `open_filex`. |
| [[deep_link_service.dart]] | Handles `trailtether://login-callback?code=...` for desktop OAuth; wired in `main.dart` |
| [[offline_map_service.dart]] | FMTC tile cache init (ObjectBox backend) |
| `local_map_server.dart` | `LocalMapServer` — spins up a local `HttpServer` on a random port to serve `assets/map/map3d.html` + MapLibre assets for the WebView 3D viewer. Needed on Android because `webview_flutter` can't load raw asset paths. |
| `device_service.dart` | `DeviceService.getDeviceId()` — stable anonymous device ID across platforms; falls back to persisted UUID. Thin wrapper over `TrailUtils.getDeviceId()`. |
| `health_connect_service.dart` | `HealthConnectService` — writes completed hikes to Google Health Connect / HealthKit via the `health` package. Returns `HealthConnectStatus` enum on each write attempt. |

## Patterns

- Most services are **static method classes** (no instance) — testing requires mocking globals.
- `Future<T>` returns are wrapped in try/catch; failures logged via [[logger_service.dart]] then returned as `null` or empty list. Caller decides how to surface.
- `Stream<T>` returns come from `supabase.from(...).stream(...)` (e.g. [[incident_service.dart]], `chat_service.dart`).
- Storage uploads via `_db.storage.from('bucket').uploadBinary(...)`.

## Service ↔ provider mapping

| Provider | Services it calls |
|---|---|
| [[recording_provider.dart]] | [[location_service.dart]], [[logger_service.dart]], [[weather_alert_service.dart]], `health_connect_service.dart` |
| [[hike_history_provider.dart]] | [[recorded_trail_service.dart]], [[logger_service.dart]] |
| [[recorded_trails_provider.dart]] | [[recorded_trail_service.dart]] |
| [[static_data_provider.dart]] | [[trail_service.dart]] → [[trail_repository.dart]] |
| [[gpx_provider.dart]] | [[gpx_service.dart]] |
| [[team_tracking_provider.dart]] | Supabase directly + [[offline_track_queue.dart]] |
| [[safety_provider.dart]] | [[incident_service.dart]], [[notification_service.dart]], [[offline_incident_queue.dart]] |
| [[weather_provider.dart]] | [[weather_service.dart]], `weather_aggregator_service.dart` |
| [[routing_provider.dart]] | [[routing_service.dart]] |
| [[chat_provider.dart]] | `chat_service.dart` |
| [[community_provider.dart]] | `community_service.dart` |
| [[review_provider.dart]] | [[review_service.dart]] |
| [[team_provider.dart]] | `team_service.dart` |
| [[auth_provider.dart]] | `auth_service.dart` |
| [[profile_provider.dart]] | `device_service.dart` |

## Used by

- [[Flutter Providers Module]] (primary consumer)
- Some screens call services directly for one-shot operations (e.g. [[PcTrailsScreen]] uses [[trail_repository.dart]] directly)

## Depends on

- `supabase_flutter` for DB + Storage
- `geolocator`, `flutter_local_notifications`, `gpx`, `http`, `path_provider`, `health`, `google_sign_in` — see [[Tech Stack]]
