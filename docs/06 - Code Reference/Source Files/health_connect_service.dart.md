---
tags: [type/source, layer/frontend, domain/health]
aliases: [health_connect_service]
source_paths: [trailtether_app/lib/services/health_connect_service.dart]
---

# health_connect_service.dart

`HealthConnectService` — writes completed hikes to Google Health Connect (Android) / HealthKit (iOS).

## Status enum

`HealthConnectStatus`: `success`, `unsupportedPlatform`, `sdkUnavailable`, `sdkUpdateRequired`, `permissionDenied`, `invalidHike`, `writeFailed`, `error`.

## Key members

| Member | Role |
|---|---|
| `writeSavedHike(SavedHike hike)` | `Future<HealthConnectStatus>` — checks platform, requests permissions, writes a workout record (distance, duration, route, calories) via the `health` package |

## Platform notes

- Android only for now (returns `unsupportedPlatform` on Windows/desktop).
- Uses `Health` singleton from the `health` package.
- Requires `ACTIVITY_RECOGNITION` + `health` permissions on Android.

## Dependencies

- `health` package (v12.2.0)
- `permission_handler`
- [[saved_hike.dart]] model

## Used by

- [[recording_provider.dart]] — called after a hike is successfully saved
