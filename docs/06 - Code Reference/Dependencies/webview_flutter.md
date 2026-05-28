---
tags: [type/dep, layer/frontend, status/stable, domain/map]
aliases: [webview_flutter, webview_windows]
source_paths: [trailtether_app/pubspec.yaml]
---

# webview_flutter (+ webview_windows)

`webview_flutter: ^4.10.0` (Android, iOS, macOS, Linux)
`webview_windows: ^0.4.0` (Windows — WebView2)

WebView wrappers used by the 3D map. Embeds `assets/map/map3d.html` running MapLibre GL JS.

## How it's used

[[TrailMap3DWidget]] picks one implementation per platform. The Flutter side pushes JSON via `runJavaScript` / channel; the HTML side calls back on user interaction.

## Why two packages?

`webview_flutter` doesn't (yet) support Windows. `webview_windows` provides a separate API. The selector widget in `trail_map_3d_selector.dart` exports both classes.

## Bundled assets

- `assets/map/map3d.html` — the 3D scene
- `assets/map/maplibre-gl.js`, `maplibre-gl.css` — bundled MapLibre (no CDN — offline-capable)
