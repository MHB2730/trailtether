---
tags: [type/dep, layer/frontend, status/stable, domain/map]
aliases: [flutter_map package]
source_paths: [trailtether_app/pubspec.yaml]
---

# flutter_map

`flutter_map: ^7.0.1`

Leaflet-style map widget for Flutter. Underpins [[TrailMapWidget]] (the 2D map).

## Primitives used

- `FlutterMap` widget — root container
- `MapController` — programmatic camera
- `TileLayer` — raster tile rendering (combined with [[offline_map_service.dart]] for FMTC caching)
- `PolylineLayer` — trail + GPX + routing polylines
- `MarkerLayer` — incidents, caves, accommodations, user location
- `MapOptions(onTap: ..., initialCameraFit: ...)`

## Companion: `flutter_map_tile_caching`

The FMTC plugin provides offline tile caching backed by ObjectBox. See [[offline_map_service.dart]].

## See also

- [[TrailMapWidget]] — the main consumer
