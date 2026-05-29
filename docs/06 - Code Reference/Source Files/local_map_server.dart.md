---
tags: [type/source, layer/frontend, domain/map]
aliases: [local_map_server]
source_paths: [trailtether_app/lib/services/local_map_server.dart]
---

# local_map_server.dart

`LocalMapServer` — local HTTP server that serves `assets/map/map3d.html` and the bundled MapLibre GL assets to the Android WebView.

## Why it exists

`webview_flutter` on Android cannot load `flutter_assets://` URLs directly. The 3D viewer (`map3d.html`) loads `maplibre-gl.js` and `maplibre-gl.css` from relative paths. This local server bridges the gap: it listens on a random loopback port and serves those assets as HTTP responses.

## Key members

| Member | Role |
|---|---|
| `start()` | `Future<void>` — binds `HttpServer` on `InternetAddress.loopbackIPv4` port 0 (random). Stores assigned port in `_port`. |
| `port` | `int` — assigned after `start()`. Passed to [[TrailMap3DWidget]] as the base URL. |
| `stop()` | `Future<void>` — closes the server |

## Lifecycle

Started once by [[TrailMap3DAndroid]] when the 3D widget is first built. Port persists for the app session.

## Used by

- `widgets/map/trail_map_3d_android.dart` — passes `http://127.0.0.1:${LocalMapServer.port}/map3d.html` to `WebViewController`
