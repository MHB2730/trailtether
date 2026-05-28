---
tags: [type/component, layer/frontend, status/stable, domain/map]
aliases: [trail_marker_layer]
source_paths: [trailtether_app/lib/widgets/map/trail_marker_layer.dart]
---

# TrailMarkerLayer

Dot-marker fallback rendering for trail polylines. Renders trails as point clouds (not polylines) to bypass occasional flutter_map PolylineLayer issues on release builds.

## Behaviour

- Iterates `trails` and for each, draws one Marker per Nth point:
  - `step = 2` if selected (dense)
  - `step = 10` if not (sparse — every 10th point)
- Marker is a 3-4 px circle, coloured by [[Trail Model]] `isCave` flag
- Selected trail at full opacity; others at 0.4

## Used by

- [[TrailMapWidget]] — included alongside the PolylineLayer as a fallback rendering

## Depends on

- [[Trail Model]]
- [[constants.dart]] (kColorOrange)

## Why both polyline + markers?

In some release builds, flutter_map's `PolylineLayer` had stale-buffer issues that made polylines disappear. The marker layer gives a guaranteed visible fallback. Both render simultaneously — if polylines work, markers are barely visible underneath; if polylines fail, the marker dots still trace the route.

## Key file

- `lib/widgets/map/trail_marker_layer.dart` (~55 LOC)
