---
type: source-file
status: current
area: code
source_paths:
  - trailtether_app/lib/main.dart
aliases:
  - main.dart
---

# main.dart

App entry point. ~165 LOC.

## Boot sequence

1. `LoggerService.init()` — file logger
2. `TelemetryService.init(dsn:)` — Sentry (DSN injected via `--dart-define=SENTRY_DSN=...`)
3. `OfflineMapService.init()` — FMTC tile cache (ObjectBox)
4. `Supabase.initialize(url, anonKey)` — sets `kSupabaseAvailable = true` on success
5. `NotificationService.instance.init()` — local notifications
6. `DeepLinkService.init()` — `trailtether://` OAuth callback listener
7. `SystemChrome` — portrait lock + `immersiveSticky` full-screen + transparent overlays
8. `runApp(TrailtetherRoot())`

## TrailtetherRoot

Wraps `TrailtetherApp` in a `MultiProvider` with **16 ChangeNotifierProviders + 2 ChangeNotifierProxyProviders**:

- `AppStateProvider`, `AuthProvider`, `StaticDataProvider` (lazy:false), `GpxProvider` (lazy:false), `RecordingProvider`, `RoutingProvider`, `TeamProvider`, `ChatProvider`, `CommunityProvider`, `ReviewProvider`, `HikeHistoryProvider`, `RecordedTrailsProvider`, `ProfileProvider`, `UnitsProvider`, `WeatherProvider`
- `TeamTrackingProvider` ← proxy fed by `RecordingProvider + TeamProvider`
- `SafetyProvider` ← proxy fed by `RecordingProvider` (current GPS position)

## TrailtetherApp

`MaterialApp(theme: appDarkTheme, home: UpdateGate(child: AuthGate()))`.

`UpdateGate` sits above `AuthGate` so a critical update blocks even unauthenticated users.

## Used by

- [[Trailtether App Module]]

## Depends on

- [[Flutter Core Module]], [[Flutter Providers Module]], [[Flutter Services Module]], [[AuthGate]], [[update_banner.dart]]
