# 🗺️ Map Intelligence

Trailtether uses **MapLibre GL JS** (3D) and **flutter_map** (2D) combined with **MapTiler** and **Esri** for high-fidelity situational awareness.

## 🛰️ Satellite & Hybrid Integration
Satellite imagery is the primary tactical view for mission planning. It is implemented across both environments:
- **2D (Native)**: Uses **Esri World Imagery** as a base layer for high-resolution static satellite tiles.
- **3D (Mission Control)**: Uses **MapTiler Hybrid** (Satellite imagery + vector labels/roads).
- **Synergy**: The 3D view overlays **3D Terrain (DEM)** on top of the satellite imagery to provide a lifelike topographical perspective, while the 2D view provides a flat, high-contrast overhead for precise distance measurements.

## 🏔️ 3D Terrain & Atmosphere
- **DEM Source**: MapTiler Terrain-RGB v2.
- **Exaggeration**: Set to `1.5x` for better visualization of mountain passes.
- **Fog/Atmosphere**: Custom fog ranges are applied dynamically to simulate visibility conditions.

## ⛈️ 3D Weather System
The app features a "Storm Mode" that overlays real-time weather data.
- **Cloud Layer**: Fetched from MapTiler Weather Clouds.
- **Precipitation**: Precipitation radar tiles overlayed with a custom hue-rotate animation to simulate cloud movement.
- **Weather API**: Integrates **Open-Meteo API** for live temperature, wind speed, and precipitation metrics based on the map center.

## 📍 Coordinates Display
Coordinates are displayed in the footer in **DMS-style** (Degrees Decimal with N/S/E/W suffixes) for field navigation compatibility.
