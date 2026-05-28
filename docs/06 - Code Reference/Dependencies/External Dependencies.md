---
tags: [type/dep, layer/infra, status/stable]
aliases: [Dependencies, Packages]
source_paths: [trailtether_app/pubspec.yaml, supabase/functions]
---

# External Dependencies

Index of all load-bearing external packages. Versions pinned per [[Pubspec Configuration]] + edge function imports.

## Flutter packages (load-bearing)

| Package | Role | Note |
|---|---|---|
| [[supabase_flutter]] | Auth, Postgres client, Storage, Realtime | The whole backend connection |
| [[provider]] | State management | 16 ChangeNotifier providers |
| [[flutter_map]] | 2D map | Underpins [[TrailMapWidget]] |
| [[geolocator]] | GPS + permissions | Foundation of recording |
| [[fl_chart]] | Charts | Elevation profile UI |
| [[gpx]] | .gpx parsing | Used by [[gpx_service.dart]] |
| [[webview_flutter]] | 3D MapLibre wrapper | Plus webview_windows on Windows |
| [[app_links]] | OAuth deep-link callback | `trailtether://login-callback` |
| [[flutter_local_notifications]] | Local notifications | Used by [[notification_service.dart]] |

## Edge function dependencies (Deno)

| Package | Role | Note |
|---|---|---|
| [[supabase-js]] | Backend client | Two import paths in use (jsr + esm.sh) |
| [[denomailer]] | SMTP send | Used by newsletter + subscriber-confirmation |

## Tier-2 (used but not foundational)

These are useful to know but secondary:

| Package | Role |
|---|---|
| `flutter_map_tile_caching` | FMTC + ObjectBox tile cache |
| `flutter_background_service` | Foreground service for background tracking |
| `flutter_compass`, `sensors_plus` | Compass + bubble level in [[TTToolsScreen]] |
| `battery_plus`, `connectivity_plus`, `device_info_plus` | Device telemetry |
| `shared_preferences` | Local persistence (recording draft, hike history, favorites) |
| `path_provider`, `file_picker`, `image_picker`, `share_plus` | File I/O |
| `google_sign_in` | Google OAuth SDK |
| `qr_flutter`, `mobile_scanner` | Device pairing |
| `torch_light`, `health` | Tools tab features |
| `google_fonts` | Manrope + JetBrains Mono |
| `crypto`, `uuid`, `intl`, `collection`, `http`, `url_launcher` | Standard utilities |
| `package_info_plus`, `open_filex` | Self-hosted update flow |
| `tray_manager`, `window_manager` | Desktop window chrome |
| `permission_handler` | Wrapper around platform permissions |
| `latlong2` | LatLng primitive |

## Web site / admin SPA

The static sites have no package manager — `marked` (markdown render) is pulled from CDN inside [[Hilltrek Admin Module]]. No other JS deps.

## See also

- [[Tech Stack]] — overview with versions
- [[Pubspec Configuration]] — exact pins
