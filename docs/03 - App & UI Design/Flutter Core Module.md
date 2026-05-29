---
tags: [type/module, layer/frontend, status/stable, domain/core]
aliases: [Core]
source_paths: [trailtether_app/lib/core]
---

# Flutter Core Module

Foundation files shared across the entire Flutter app. 9 files in `lib/core/`.

## Files

| File | Role |
|---|---|
| `constants.dart` | Legacy brand colours (`kColorOrange = #E8541A`, `kColorCream`, `kColorBg`, `kColorPanel`, `kColorBorder`, Stitch cyan/purple variants), geometry (`kRadiusPremium`, `kRadiusCard`, `kPaddingScreen`), map tile styles (`kMapTileStyles`, `kNightTileUrl`, `kTileUrl`), `kWorldMapCenter`, Supabase table name constants (`kColReviews`, `kColGpxUploads`, `kColIncidents`, `kColTeams`, `kColHikePlans`, `kColChat`, `kColProfiles`), `difficultyColor()`, `kGpxColors`. Uses `'Inter'` font for legacy `kStyle*` text constants. |
| `design_tokens.dart` | **Primary design system.** The `TT` static class — surfaces (`TT.bg → TT.surf3`), lines (`TT.line → TT.line3`), text (`TT.text → TT.text4`), ember palette (`TT.ember = #FF6A2C`, `TT.ember2/3/Dim/Soft/Ink`), status colours (`TT.blue/green/amber/red`), radii (`TT.rSm → TT.rXl`), spacing (`TT.s1 → TT.s6`), shadows (`shadowCard`, `shadowEmber`), animation curves + durations. Typography: `GoogleFonts.manrope` for all text, `GoogleFonts.jetBrainsMono` for numeric/mono. |
| `theme.dart` | `appDarkTheme` — MaterialApp `ThemeData` wired to the TT palette. |
| `kalman_filter.dart` | One-dimensional Kalman filter for GPS smoothing (lat + lon smoothed independently). Consumed by [[location_service.dart]]. |
| `sun_utils.dart` | Sunrise/sunset calculation given lat/lon + date. Used by map/home screens for night-mode toggling. |
| `supabase_options.dart` | `kSupabaseUrl`, `kSupabaseAnonKey`, `kGoogleWebClientId`. Source of truth for Supabase connection. Anon key is safe-to-ship (public by design). |
| `runtime_config.dart` | `kSupabaseAvailable` mutable flag — set `false` if Supabase init fails; guards Supabase calls in offline mode. |
| `utils.dart` | `TrailUtils` — `getDeviceId()` (platform-aware stable ID via `device_info_plus`), `formatDuration()`, `haversineDistance()`, `simplifyPoints()` / `simplifyPointsWithElevations()` (Douglas-Peucker), `launchUrlSafe()`. |
| `app_messenger.dart` | Thin in-app overlay notification helper. Shows short-lived success / error / info banners without requiring a BuildContext in services. Providers call this to surface errors without crashing. |

## Design system note — two colour sets co-exist

| System | File | Primary colour | Font |
|---|---|---|---|
| Legacy | `constants.dart` | `kColorOrange = #E8541A` | `'Inter'` (constant strings only) |
| TT / Stitch | `design_tokens.dart` | `TT.ember = #FF6A2C` | Manrope + JetBrains Mono |

When editing screens, match whichever token set the file already imports. **New screens should use `TT.*` exclusively.**

## Depends on

- `google_fonts` — Manrope + JetBrains Mono
- `device_info_plus` — `getDeviceId()` in `utils.dart`
- `flutter` SDK

## Used by

Every other module (screens, providers, services, widgets) imports from here.
