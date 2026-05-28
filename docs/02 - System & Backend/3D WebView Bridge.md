---
type: architecture
status: current
area: architecture
aliases:
  - 3D WebView Bridge
---

# 🌉 3D WebView Bridge

The core of the 3D Mission Control is a bridge between the **Dart** environment and the **MapLibre JS** environment.

## 📡 Communication Flow
1. **Initialization**: Flutter loads `assets/map/map3d.html` into a WebView.
2. **Data Injection**: Flutter reads `routes_cleaned.json` and injects it into the JS context using `runJavaScript`.
3. **Telemetry Sync**: Real-time GPS coordinates from the `geolocator` plugin are passed to the WebView to update marker positions on the 3D map.

## 📂 Asset Structure
- **`map3d.html`**: The HTML container.
- **`maplibre-gl.js`**: Local copy of the map engine to ensure offline availability.
- **`maplibre-gl.css`**: Styling for map controls.

## 🛠️ Logic Unification
By using a WebView for 3D, we maintain a single JS-based map logic that works on both Windows and Android, while keeping the UI shell native and fast.
