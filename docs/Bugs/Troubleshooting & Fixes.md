# 🛠️ Troubleshooting & Fixes

This log tracks technical hurdles encountered during the development of Trailtether v2.0 and the solutions implemented.

## 🗺️ Map & UI Issues

### ❌ Inconsistent Detail Sheets (2D vs 3D)
- **Problem**: Clicking a route in the 2D Leaflet view didn't trigger the same info panel as the 3D MapLibre view, causing UI fragmentation.
- **Fix**: Centralized the `selectTrack(id)` function. Now, both map implementations call the same unified logic to populate the detail sheet, ensuring state parity across environments.

### ❌ MapLibre Style Loading Race Condition
- **Problem**: Adding layers before the style was fully loaded caused runtime errors (`Style is not loaded`).
- **Fix**: Wrapped layer initialization in `map.on('style.load')`. This ensures that even if the user toggles styles (Hybrid/Street), the tracks and weather layers are re-injected correctly.

## 💾 Data & Telemetry

### ❌ Large Data File Performance
- **Problem**: `routes.json` grew to ~4MB, causing a noticeable UI stutter on startup.
- **Fix**: Implemented a `loading-screen` with a CSS opacity transition. The `init()` function is now asynchronous, and the UI only reveals once `loadRoutes()` and `initMap()` have completed successfully.

### ❌ Invalid GPX Uploads
- **Problem**: User-uploaded GPX files with missing elevation data or malformed XML crashed the parser.
- **Fix**: Added a `DOMParser` check and filter for `Number.isFinite`. If elevation data is missing, it defaults to `0` instead of `NaN`, preventing chart crashes.

## 📦 Build & Environment

### ❌ WebView2 Missing on Windows
- **Problem**: The Electron app would launch to a white screen if the Microsoft Edge WebView2 runtime was missing.
- **Fix**: Added a check in the main process to prompt the user for a runtime installation and documented it in the [[Build/Windows Build Steps|Build Guide]].

### ❌ Background GPS Sleep (Android)
- **Problem**: Android OS would kill the telemetry service during long-duration tracking to save battery.
- **Fix**: Optimized the telemetry loop to reduce "fluff" and memory overhead. Configured Capacitor to request `ACCESS_BACKGROUND_LOCATION` permissions strictly.

## 🌡️ API Errors

### ❌ Weather Fetch Rate Limiting
- **Problem**: Rapidly moving the map triggered dozens of Open-Meteo API calls, leading to 429 (Too Many Requests) errors.
- **Fix**: Implemented a **Debounce** in the `moveend` listener. It now waits 1000ms after movement stops and checks if the map has moved at least 5km before fetching new weather data.
