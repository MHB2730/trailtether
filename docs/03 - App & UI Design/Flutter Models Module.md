---
tags: [type/module, layer/frontend, status/stable, domain/data]
aliases: [Models]
source_paths: [trailtether_app/lib/models]
---

# Flutter Models Module

Domain types. 16 model files in `lib/models/`. All are plain Dart classes with `fromMap()` / `toMap()` for Supabase row serialisation.

## Models

| File | Class(es) | Maps to |
|---|---|---|
| `trail.dart` | `Trail`, `TrailCoord`, `ElevationPoint` | `trails` table / bundled `routes_cleaned.json`. `fromJson` does RDP simplification + Chaikin smoothing. **Note:** `TrailCoord(lon, lat, ele)` — longitude first. |
| `recording_point.dart` | `RecordingPoint` | One GPS fix: lat/lon/alt/speed/accuracy/timestamp. Stored in `hike_history.points` JSONB. |
| `saved_hike.dart` | `SavedHike` | Completed hike — totals + full `RecordingPoint` list. Written by `RecordingProvider.toSavedHike()`. Feeds [[hike_history]] + [[recorded_trails]]. |
| `recorded_trail.dart` | `RecordedTrail` | Promoted shareable recording — metadata row in `recorded_trails` table; GPX stored in Storage. |
| `incident.dart` | `Incident`, `IncidentType`, `IncidentSeverity` | `incidents` table; community hazard reports. |
| `cave_waypoint.dart` | `CaveWaypoint` | Parsed from `assets/data/caves.gpx` — Drakensberg cave/shelter pins. |
| `gpx_track.dart` | `GpxTrack`, `UserGpxTrack` | User-imported GPX overlay; synced to `gpx_uploads` table. |
| `hiker_profile.dart` | `HikerProfile` | `profiles` table — username, bio, avatar URL, emergency contacts, `is_admin`. |
| `team.dart` | `Team`, `TeamMember`, `TeamMemberLocation` | `teams` table + `team_member_locations` for live positions. |
| `chat_message.dart` | `ChatMessage` | `chat_messages` table row. |
| `community.dart` | `CommunityActivity`, `TeamLeaderboardStats` | `community_activities` table + leaderboard RPC results. |
| `review.dart` | `Review` | `reviews` table. |
| `accommodation.dart` | `Accommodation` | Bundled accommodation/lodge data (no live table). |
| `achievement.dart` | `Achievement`, `AchievementType` | In-memory achievement definitions; unlocked state tracked in `ProfileProvider`. |
| `weather.dart` | `WeatherData`, `HourlyWeather`, `DailyWeather`, `WeatherLocation` | Open-Meteo + Met Norway API responses. Consumed by [[weather_service.dart]] and [[weather_aggregator_service.dart]]. |
| `weather_warning.dart` | `WeatherWarning`, `WeatherWarningSeverity` | Alert objects emitted by [[weather_alert_service.dart]]. |

## Conventions

- `fromMap(Map<String, dynamic> m)` — Supabase/JSON deserialisation.
- `toMap()` — writing to Supabase.
- No business logic in models — all logic lives in providers or services.
- Nullable fields default to `null`; callers must guard.
- Lat/Lon: most models use `latlong2.LatLng`. `TrailCoord` is custom positional `(lon, lat, ele)`.

## Depends on

- `latlong2` for LatLng primitives
- `intl` for date formatting in some `toString` overrides
- Pure Dart — no Flutter or Supabase imports

## Used by

- [[Flutter Providers Module]] — providers hold lists of models
- [[Flutter Services Module]] — services return models from Supabase responses
- [[Flutter Screens Module]] / [[Flutter Widgets Module]] — display model data
