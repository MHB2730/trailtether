---
tags: [type/module, layer/frontend, status/stable, domain/state]
aliases: [Providers]
source_paths: [trailtether_app/lib/providers]
---

# Flutter Providers Module

State management layer. All 17 are `ChangeNotifier` subclasses wired via [[provider]] in [[main.dart]].

## Provider registration

In [[main.dart]] `TrailtetherRoot.build()`, in this order (some depend on others via `ChangeNotifierProxyProvider`):

```
ChangeNotifierProvider(AppStateProvider)
ChangeNotifierProvider(ap.AuthProvider)
ChangeNotifierProvider(StaticDataProvider, lazy: false)
ChangeNotifierProvider(GpxProvider, lazy: false)
ChangeNotifierProvider(RecordingProvider)
ChangeNotifierProvider(RoutingProvider..init())
ChangeNotifierProvider(TeamProvider)
ChangeNotifierProvider(ChatProvider)
ChangeNotifierProvider(CommunityProvider)
ChangeNotifierProvider(ReviewProvider)
ChangeNotifierProvider(HikeHistoryProvider)
ChangeNotifierProvider(RecordedTrailsProvider)
ChangeNotifierProvider(ProfileProvider)
ChangeNotifierProvider(UnitsProvider)
ChangeNotifierProvider(WeatherProvider)
ChangeNotifierProxyProvider2<Recording, Team, TeamTracking>(...)
ChangeNotifierProxyProvider<Recording, Safety>(...)
```

`SafetyProvider` receives the current GPS position from [[recording_provider.dart]] via the proxy so it can filter incident alerts by proximity. `TeamTrackingProvider` receives both recording + team so it can stamp outbound location pings with the right team_id + hike_id.

## Providers

| Provider | Role | Key methods | Key file |
|---|---|---|---|
| [[auth_provider.dart]] | Auth + admin flag | `signIn()`, `signOut()`, `isAdmin` getter | `lib/providers/auth_provider.dart` |
| [[app_state_provider.dart]] | Favorites, completed trails, recent searches, active safety plan, theme | `toggleFavorite`, `toggleCompleted`, `setSafetyPlan` | `lib/providers/app_state_provider.dart` |
| [[static_data_provider.dart]] | Trails + caves + accommodations (read-only) | `load()`, `refreshTrails()` | `lib/providers/static_data_provider.dart` |
| [[gpx_provider.dart]] | User-imported GPX tracks | `add`, `remove`, `syncWithCloud` | `lib/providers/gpx_provider.dart` |
| [[recording_provider.dart]] | The recording state machine | `start()`, `pause()`, `stop()`, `clear()`, `toSavedHike()` | `lib/providers/recording_provider.dart` |
| [[routing_provider.dart]] | Waypoint planning | `addWaypoint`, `recalculate` | `lib/providers/routing_provider.dart` |
| [[team_provider.dart]] | Team CRUD + selected team | `listenForUser()`, `createTeam`, `joinByCode` | `lib/providers/team_provider.dart` |
| [[chat_provider.dart]] | Realtime chat with reconnection | `send()`, `vote()`, `toggleTodo()` | `lib/providers/chat_provider.dart` |
| [[community_provider.dart]] | Leaderboard + activity feed | `refresh()` | `lib/providers/community_provider.dart` |
| [[review_provider.dart]] | Trail review CRUD | `submit`, `update`, `delete` | `lib/providers/review_provider.dart` |
| [[hike_history_provider.dart]] | Local + Supabase sync of completed hikes | `add()` returns `HikeSaveResult` | `lib/providers/hike_history_provider.dart` |
| [[recorded_trails_provider.dart]] | The user's promoted-to-shareable trails | `promoteFromHike`, `setSharing`, `delete` | `lib/providers/recorded_trails_provider.dart` |
| [[profile_provider.dart]] | Hiker profile + achievements | `unlockAchievement`, `uploadPhoto` | `lib/providers/profile_provider.dart` |
| [[units_provider.dart]] | Metric ↔ Imperial | `setImperial`, `formatDistance`, `elevationFromM` | `lib/providers/units_provider.dart` |
| [[weather_provider.dart]] | Custom weather locations + severe alerts | `addLocation`, `removeLocation` | `lib/providers/weather_provider.dart` |
| [[team_tracking_provider.dart]] | Outbound live GPS publisher | (auto-runs on recording start) | `lib/providers/team_tracking_provider.dart` |
| [[safety_provider.dart]] | Incident stream + proximity-filtered alerts | `setUserLocation()`, `incidents` getter | `lib/providers/safety_provider.dart` |

## Depends on

- [[Flutter Services Module]] — every provider calls services for actual I/O
- [[Flutter Models Module]] — every provider operates on typed models
- [[Supabase Migrations Module]] — the tables they read/write
- [[supabase_flutter]] — the client SDK they use

## Used by

- [[Flutter Screens Module]] — `context.watch<T>()` everywhere
- [[Flutter Widgets Module]] — provider consumption in nested widgets

## Conventions

- Always `extends ChangeNotifier`, never `Stream`-only.
- Persist to SharedPreferences for offline-first; sync to Supabase as opportunistic background.
- `notifyListeners()` after every state mutation. Many use `unawaited(...)` for fire-and-forget writes.
- Logged via [[logger_service.dart]] — search for `LoggerService.log` in any provider.

> [!note] Naming
> The codebase uses `ap.AuthProvider` (aliased import) because Flutter has its own `AuthProvider` name collisions. Look for `import '../providers/auth_provider.dart' as ap;` in screen files.
