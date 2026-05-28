---
tags: [type/component, layer/frontend, status/stable, domain/map, domain/recording]
aliases: [speed_path_layer]
source_paths: [trailtether_app/lib/widgets/map/speed_path_layer.dart]
---

# SpeedPathLayer

Draws the currently-recording route polyline with **speed-coloured** segments. Slower segments tint blue/green, faster tint amber/red. Visual cue for the user about their pace history.

## Input

`List<RecordingPoint>` — typically from `RecordingProvider.points`.

## Algorithm

Each segment between two consecutive points gets a colour based on the second point's `speed` field (m/s, supplied by Geolocator). Maps speed to a colour gradient — exact thresholds defined inline.

## Used by

- [[TrailMapWidget]] (renders active recording overlay)
- [[LiveTrackingScreen]] (2D map mode)

## Depends on

- [[RecordingPoint]] model (uses `latitude`, `longitude`, `speed`)
- flutter_map's `PolylineLayer`

## Key file

- `lib/widgets/map/speed_path_layer.dart`
