---
type: archive
status: archived
area: archive
aliases:
  - Legacy Architecture - Tech Stack
---

# 🏗️ Trailtether System Stack

Trailtether v2.0 is a hybrid high-performance application built with **Flutter** for the native shell and **JavaScript/MapLibre** for the 3D map engine.

## 📱 Native Layer (Flutter/Dart)
- **Framework**: Flutter 3.3+
- **Map (2D)**: `flutter_map` (Leaflet-based) with `latlong2`.
- **State Management**: `provider`.
- **Backend**: **Supabase** (PostgreSQL/Auth/Realtime). Replaces earlier Firebase implementations.
- **Offline Support**: `flutter_map_tile_caching` for map tiles and `shared_preferences` for local settings.

## 🌐 3D Map Engine (WebView)
- **Engine**: MapLibre GL JS.
- **Integration**: Loaded via `webview_flutter` (Android) and `webview_windows` (Windows).
- **Bridge**: Flutter communicates with the map using JavaScript injection to sync routes and telemetry.
- **Assets**: The 3D map code is located in `assets/map/map3d.html`.

## 🛠️ Native Plugins
- **Sensors**: Compass (`flutter_compass`) and Bubble Level (`sensors_plus`).
- **Health**: Integrates with device health data (steps, heart rate via `health` package).
- **Background**: `flutter_background_service` for persistent SOS listening and tracking.
- **Packaging**: **MSIX** for Windows distribution via Hilltrek (Cape Town).
