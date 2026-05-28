---
tags: [type/component, layer/frontend, status/stable, domain/map, domain/desktop]
aliases: [trail_map_3d, 3D viewer]
source_paths: [trailtether_app/lib/widgets/map/trail_map_3d_selector.dart, trailtether_app/assets/map/map3d.html]
---

# TrailMap3DWidget

3D map viewer powered by MapLibre GL JS via WebView. Renders a 3D terrain mesh + satellite tiles + user position + trail overlays. Same input data as [[TrailMapWidget]], different presentation.

## Platform branching

The class actually wraps **two implementations**:

| Platform | Implementation | WebView package |
|---|---|---|
| Android / iOS / macOS / Linux | `TrailMap3DWidget` | `webview_flutter` |
| Windows | `TrailMap3DWindowsWidget` | `webview_windows` |

`trail_map_3d_selector.dart` exports both; callers pick based on platform.

## HTML payload

The actual 3D scene lives in `assets/map/map3d.html` (loaded by the WebView). Uses MapLibre GL JS bundled in `assets/map/maplibre-gl.js` (no CDN — offline-capable). Esri World Imagery satellite tiles overlay on a terrain mesh.

## JS bridge

Flutter pushes JSON payloads to the WebView (`updatePosition`, `updateRoute`, `updateBearing`, etc.) via JS channel. The WebView calls back when the user taps a marker.

## Props

- `trails`, `selectedTrail`, `caves`, `incidents`, `recordingPoints` — same data sources as 2D
- `gpsLat`, `gpsLon` — current position
- `bearing` — current heading (rotates camera)
- `weatherCode`, `cloudCover` — affects sky shader

## Used by

- [[TTMapScreen]] (3D toggle)
- [[MissionControlTab]] (3D toggle)
- [[LiveTrackingScreen]] (3D mode index)

## Depends on

- `webview_flutter` / `webview_windows`
- `assets/map/map3d.html` + `maplibre-gl.js` + `maplibre-gl.css`
- [[Trail Model]], [[Incident]], [[CaveWaypoint]]

## Key file

- `lib/widgets/map/trail_map_3d_selector.dart`
- `assets/map/map3d.html` (the actual MapLibre scene)
