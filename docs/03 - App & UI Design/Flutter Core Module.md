---
tags: [type/module, layer/frontend, status/stable, domain/core]
aliases: [Core]
source_paths: [trailtether_app/lib/core]
---

# Flutter Core Module

9 files — global constants, design tokens, theme, utility functions, runtime config.

## Files

| File | What it owns |
|---|---|
| [[constants.dart]] | Legacy color/style constants (kColorOrange, kColorBg, kStyleHeader, kRadiusPremium…). Some still in use; gradually being migrated to [[TT Design Tokens]]. Also map tile-style configs and world map center constants. |
| [[TT Design Tokens]] (`design_tokens.dart`) | The current design system. `TT` class with namespaced statics: surfaces, lines, text, ember, semantic, radii, spacing, shadows, animation, typography helpers. |
| [[theme.dart]] | Material 3 ThemeData (`appDarkTheme`) — primary kColorOrange, NavigationBar, ElevatedButton styling, AppBar transparent. Uses GoogleFonts.outfit. |
| [[runtime_config.dart]] | Two process-wide flags: `kSupabaseAvailable` (set at startup), `kAllowDemoMode` (dart-define). Lets services gate Supabase calls without circular imports. |
| [[supabase_options.dart]] | `kSupabaseUrl` + `kSupabaseAnonKey` — public constants compiled into the binary. **See [[Supabase Client Config]] for security note.** |
| [[utils.dart]] | `launchUrlSafe()` (URL scheme whitelist), `getDeviceId()` (per-platform), `simplifyPoints()` + `simplifyPointsWithElevations()` (Douglas-Peucker), TrailUtils class |
| [[kalman_filter.dart]] | Kalman 1D filter for lat/lon GPS smoothing. State-machine class with `process(lat, lon)` and `reset()`. Used by [[location_service.dart]] `smooth()`. |
| [[sun_utils.dart]] | Sunrise/sunset calculations + `formatDuration` helper used across the app |
| (potentially more files) | — |

## Depends on

- `flutter`, `google_fonts`, `intl`, `latlong2`, `device_info_plus`, `url_launcher`

## Used by

- **Every module.** Core is the foundation.

## Conventions

- `TT.foo` for tokens. Use `TT.ember`, not `Color(0xFFFF6A2C)`.
- `kColorOrange` etc. remain in [[constants.dart]] for backward compat — prefer [[TT Design Tokens]] in new code.
- `runtime_config.dart` is for **deciding at runtime** whether Supabase is up (`kSupabaseAvailable`). Code can check it before making a call to avoid throws when offline.

> [!warning] Verify
> [[supabase_options.dart]] hardcodes the anon key. That's safe (anon keys are public by design), but if it ever ships a service-role key, that'd be a P0 leak. Worth a quick read.
