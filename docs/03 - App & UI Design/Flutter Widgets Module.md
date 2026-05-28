---
tags: [type/module, layer/frontend, status/stable, domain/ui]
aliases: [Widgets]
source_paths: [trailtether_app/lib/widgets]
---

# Flutter Widgets Module

Reusable UI primitives + map layers + form widgets. 36 widget files across 5 subfolders.

## Subfolders

| Path | Theme |
|---|---|
| `widgets/design/` | TT design-system primitives (cards, pills, buttons, app bars) |
| `widgets/map/` | flutter_map layers + 3D selector |
| `widgets/trail/` | Trail-specific UI (elevation chart, difficulty badge, weather card) |
| `widgets/review/` | Review form + card |
| `widgets/common/` | Shared utility widgets (glass panel) |
| (root of widgets) | One-offs: [[FinishHikeSheet]], [[StartHikeRamp]], [[update_banner.dart]] |

## Design primitives (`widgets/design/`)

| Widget | File | Role |
|---|---|---|
| [[TTPageAppBar]] | `tt_app_bar.dart` | Title + trailing actions + optional eyebrow |
| `TTIconBtn` | `tt_app_bar.dart` | 36-dot circular icon button |
| `TTBigButton` | (various) | CTA button with ember glow |
| [[TTGlass]] / `TTGlassCard` | `tt_glass_card.dart` | Frosted-glass panel (used everywhere) |
| [[TTPill]] | `tt_pill.dart` | Status pill with variants (neutral, live, danger, success) |
| `TTStat` | (various) | Stat tile primitive |
| `TTCountUp` | `tt_count_up.dart` | Animated number counter |
| `TTCard` | `tt_card.dart` | Bordered card primitive |
| `TTStagger` | (various) | Stagger-in animation wrapper |
| `TTAchievementMedallion` | `tt_achievement_medallion.dart` | Achievement unlock UI |
| `TTBtn` | `tt_btn.dart` | Standard button |
| `TTBadge` | `tt_badge.dart` | Notification badge |
| `TTTopo` | `tt_topo.dart` | Topographic-pattern background |

These rely on tokens from [[TT Design Tokens]].

## Map layers (`widgets/map/`)

| Widget | File | Role |
|---|---|---|
| [[TrailMapWidget]] | `trail_map_widget.dart` | 2D map composite (tiles + trails + caves + incidents + GPS + measurements) |
| [[TrailMarkerLayer]] | `trail_marker_layer.dart` | Dot-marker fallback for trail polylines |
| [[SpeedPathLayer]] | `speed_path_layer.dart` | Recorded points coloured by speed |
| [[TrailMap3DWidget]] | `trail_map_3d_selector.dart` | 3D MapLibre GL viewer via WebView |
| `CaveMarkerLayer` | `cave_marker_layer.dart` | Cave waypoints |
| `IncidentMarkerLayer` | `incident_marker_layer.dart` | Active incidents |
| `AccommodationMarkerLayer` | `accommodation_marker_layer.dart` | Lodging waypoints |
| `GpsLocationLayer` | `gps_location_layer.dart` | User's current GPS dot with accuracy ring |
| `TrailMap3DWindowsWidget` | inside `trail_map_3d_selector.dart` | Windows-specific WebView wrapper (webview_windows) |

## Trail UI (`widgets/trail/`)

| Widget | File | Role |
|---|---|---|
| `ElevationChart` | `elevation_chart.dart` | fl_chart line chart of elevation profile |
| `DifficultyBadge` | `difficulty_badge.dart` | Easy / Moderate / Hard / Extreme pill |
| `WeatherCard` | `weather_card.dart` | Weather panel for trail detail |

## Review UI (`widgets/review/`)

| Widget | File | Role |
|---|---|---|
| `ReviewForm` | (file) | Submit/edit review form |
| `ReviewCard` | (file) | Display review card |

## Top-level widgets (no subfolder)

| Widget | File | Role |
|---|---|---|
| [[FinishHikeSheet]] | `finish_hike_sheet.dart` | Strava-style Save / Discard / Resume sheet |
| [[StartHikeRamp]] | `start_hike_ramp.dart` | Slide-to-start + 3-2-1 countdown |
| `UpdateBanner` | `update_banner.dart` | In-app updater banner (read by `UpdateGate`) |
| `WeatherWarningsBanner` | `weather_warnings_banner.dart` | Drop-in banner for severe weather alerts |

## Depends on

- [[Flutter Providers Module]] — most widgets `context.watch<X>()` to listen to state
- [[Flutter Services Module]] — some widgets call services for one-off ops
- [[TT Design Tokens]] — design constants
- [[flutter_map]], [[fl_chart]], [[webview_flutter]] — see [[Tech Stack]]

## Used by

- [[Flutter Screens Module]] — every screen composes widgets
- [[Trailtether App Module]]
