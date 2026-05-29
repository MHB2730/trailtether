---
tags: [type/module, layer/frontend, status/stable, domain/ui]
aliases: [Widgets]
source_paths: [trailtether_app/lib/widgets]
---

# Flutter Widgets Module

Reusable UI primitives, map layers, bottom sheets, and form widgets. 36 widget files across `lib/widgets/`.

## Subfolders

| Path | Count | Theme |
|---|---|---|
| `widgets/design/` | 10 | TT design-system primitives |
| `widgets/map/` | 12 | flutter_map layers + 3D viewer wiring |
| `widgets/review/` | 3 | Review form + card + star input |
| `widgets/common/` | 2 | Shared utility widgets |
| `widgets/trail/` | 1 | Trail-specific UI |
| `widgets/` (root) | 8 | Bottom sheets + banners |

---

## Design primitives (`widgets/design/`)

All rely on tokens from [[TT Design Tokens]] (`design_tokens.dart`).

| File | Widget(s) | Role |
|---|---|---|
| `tt_app_bar.dart` | `TTAppBar`, `TTIconBtn` | Page title bar with trailing icon buttons |
| `tt_glass_card.dart` | `TTGlassCard` | Frosted-glass panel — the main card primitive |
| `tt_pill.dart` | `TTPill` | Status pill — neutral / live / danger / success variants |
| `tt_bottom_nav.dart` | `TTBottomNav` | 6-tab bottom navigation bar used in [[AppShell]] |
| `tt_count_up.dart` | `TTCountUp` | Animated number counter |
| `tt_elev_chart.dart` | `TTElevChart` | Inline elevation profile chart (fl_chart wrapper) |
| `tt_achievement_medallion.dart` | `TTAchievementMedallion` | Achievement unlock animation |
| `tt_ambient.dart` | `TTAmbient` | Animated ambient glow / background effect |
| `tt_segmented.dart` | `TTSegmented` | Segmented control selector |
| `tt_topo.dart` | `TTTopo` | Topographic-pattern decorative background |

---

## Map layers (`widgets/map/`)

| File | Widget(s) | Role |
|---|---|---|
| `trail_map_widget.dart` | `TrailMapWidget` | Main 2D map composite — tiles + trails + caves + incidents + GPS + measurement tools |
| `trail_marker_layer.dart` | `TrailMarkerLayer` | Dot markers for trail polylines |
| `speed_path_layer.dart` | `SpeedPathLayer` | Recorded GPS points coloured by speed |
| `cave_marker_layer.dart` | `CaveMarkerLayer` | Drakensberg cave/shelter pins |
| `incident_marker_layer.dart` | `IncidentMarkerLayer` | Active community hazard markers |
| `accommodation_marker_layer.dart` | `AccommodationMarkerLayer` | Lodge/accommodation pins |
| `gps_location_layer.dart` | `GpsLocationLayer` | Current GPS dot with accuracy ring |
| `trail_map_3d_widget.dart` | `TrailMap3DWidget` | MapLibre GL 3D viewer — platform dispatch |
| `trail_map_3d_selector.dart` | (selector logic) | Selects between Android / Windows / stub 3D implementations |
| `trail_map_3d_android.dart` | `TrailMap3DAndroid` | Android WebView (`webview_flutter`) serving 3D via [[local_map_server.dart]] |
| `trail_map_3d_android_export.dart` | (conditional export) | Platform-conditional export shim for Android 3D widget |
| `trail_map_3d_stub.dart` | `TrailMap3DStub` | No-op stub for unsupported platforms |

---

## Review UI (`widgets/review/`)

| File | Widget(s) | Role |
|---|---|---|
| `review_card.dart` | `ReviewCard` | Display a single trail review |
| `review_summary_bar.dart` | `ReviewSummaryBar` | Aggregate rating + count bar |
| `star_rating_input.dart` | `StarRatingInput` | Tappable star row for submitting ratings |

---

## Common utilities (`widgets/common/`)

| File | Widget(s) | Role |
|---|---|---|
| `user_avatar.dart` | `UserAvatar` | Circular avatar with initials fallback |
| `clear_chat_bar.dart` | `ClearChatBar` | Admin-only chat clear button bar |

---

## Trail UI (`widgets/trail/`)

| File | Widget(s) | Role |
|---|---|---|
| `elevation_chart.dart` | `ElevationChart` | Full elevation profile chart using `fl_chart` |

---

## Top-level widgets (`widgets/`)

| File | Widget(s) | Role |
|---|---|---|
| `finish_hike_sheet.dart` | `FinishHikeSheet` | Strava-style modal: Save / Discard / Resume. Called from [[TTMapScreen]] and [[LiveTrackingScreen]]. |
| `start_hike_ramp.dart` | `StartHikeRamp` | Slide-to-start bottom sheet with 3-2-1 countdown. Returns `true` on confirm. |
| `update_banner.dart` | `UpdateBanner`, `UpdateGate` | In-app update nag; `UpdateGate` wraps the entire app above [[AuthGate]]. |
| `weather_warnings_banner.dart` | `WeatherWarningsBanner` | Drop-in severe weather alert banner |
| `incident_detail_sheet.dart` | `IncidentDetailSheet` | Bottom sheet — hazard detail + verify/flag actions |
| `cave_detail_sheet.dart` | `CaveDetailSheet` | Bottom sheet — cave/shelter info |
| `field_intel_sheet.dart` | `FieldIntelSheet` | Bottom sheet — field intel (conditions, notes) |
| `accommodation_detail_sheet.dart` | `AccommodationDetailSheet` | Bottom sheet — lodge/accommodation info |

---

## Depends on

- [[Flutter Providers Module]] — most widgets `context.watch<X>()` to listen to state
- [[TT Design Tokens]] — `TT.*` tokens from `design_tokens.dart`
- `flutter_map`, `fl_chart`, `webview_flutter` — see [[Tech Stack]]

## Used by

- [[Flutter Screens Module]] — every screen composes widgets
