---
tags: [type/dep, layer/frontend, status/stable, domain/recording]
aliases: [geolocator package]
source_paths: [trailtether_app/pubspec.yaml]
---

# geolocator

`geolocator: ^13.0.1`

GPS + permissions for Flutter. The foundation of every recording feature.

## Primitives used

- `Geolocator.getCurrentPosition(locationSettings: ...)` — one-shot fix
- `Geolocator.getPositionStream(locationSettings: ...)` — continuous stream
- `LocationSettings` / `AndroidSettings` — platform-specific config (distance filter, accuracy, interval, foreground notification)
- `Geolocator.distanceBetween(...)` — haversine
- `Geolocator.bearingBetween(...)` — heading

## App-specific wrappers

[[location_service.dart]] exposes three pre-configured `LocationSettings`:
- `recordingLocationSettings` — full accuracy, 2m filter, foreground notification on Android
- `liveLocationSettings` — best accuracy
- `batterySaverSettings` — medium accuracy, 30m filter, 30s interval

[[kalman_filter.dart]] smooths the lat/lon stream before consumers see it.

## Permissions

Requested via [[location_service.dart]] `requestPermission(background: true)`:
- `LocationPermission.always` (Android)
- `Permission.notification` (Android 13+)
