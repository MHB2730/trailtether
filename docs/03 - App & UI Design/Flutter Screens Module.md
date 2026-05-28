---
tags: [type/module, layer/frontend, status/stable, domain/ui]
aliases: [Screens]
source_paths: [trailtether_app/lib/screens]
---

# Flutter Screens Module

Page-level UI. 23 screen files after cleanup (was 39 pre-purge).

## Two shells, two UX

| Shell | Platform | File |
|---|---|---|
| [[AppShell]] | Mobile (Android) | `lib/screens/app_shell.dart` |
| [[MainPcShell]] | Desktop (Windows / macOS / Linux) | `lib/screens/pc/pc_shell.dart` |

Branching happens in [[AuthGate]] based on `MediaQuery.size`.

## Mobile screens (under [[AppShell]] tabs)

| Screen | Tab | File |
|---|---|---|
| [[TTHomeScreen]] | Home | `tt_home_screen.dart` |
| [[TTMapScreen]] | Map / Peak Tracker | `tt_map_screen.dart` |
| [[TTTeamScreen]] | Teams | `tt_team_screen.dart` |
| [[TTToolsScreen]] | Tools | `tt_tools_screen.dart` |
| [[TTProfileScreen]] | Profile | `tt_profile_screen.dart` |
| TTCommunityScreen | Community | `tt_community_screen.dart` |

Plus secondary mobile screens pushed as routes:
- [[LiveTrackingScreen]] — used by Teams "View Live Map" + recording UI fallback
- `recorded_trails_screen.dart` — RecordedTrailsScreen
- `hike_history_screen.dart` — HikeHistoryScreen
- `create_hike_plan_screen.dart` / `hike_plan_detail_screen.dart`
- `trail_detail_screen.dart`
- `team_detail_screen.dart`
- `chat_screen.dart`
- `sos_screen.dart` — SOS emergency
- `welcome_screen.dart`, `welcome_features_screen.dart`, `tt_welcome_screen.dart` — onboarding sequence
- `tt_welcome_*` variants
- `offline_download_screen.dart` — pre-trail offline tile download
- `incident_detail_sheet.dart`, `cave_detail_sheet.dart`, `field_intel_sheet.dart`, `accommodation_detail_sheet.dart` — bottom sheets

## Desktop screens (under [[MainPcShell]])

Each is a `_PcSection` enum tag, dispatched in `_PcContent`:

| Section | Content | File |
|---|---|---|
| dashboard | [[MissionControlTab]] | `screens/admin/mission_control_tab.dart` |
| watch | `_PcHikeWatch` (private to pc_shell.dart) | `screens/pc/pc_shell.dart` |
| hikers | `_PcHikersList` (private) | `screens/pc/pc_shell.dart` |
| history | `_PcHistory` (private — wraps HikeHistoryScreen) | `screens/pc/pc_shell.dart` |
| **trails** | [[PcTrailsScreen]] (admin-only) | `screens/pc/pc_trails_screen.dart` |
| alerts | `_PcAlerts` (private) | `screens/pc/pc_shell.dart` |
| pair | `PcPairDeviceScreen` | `screens/pc/pc_shell.dart` |
| **settings** | [[AdminSettingsTab]] (admin-only) | `screens/admin/admin_settings_tab.dart` |

Admin-only sections are filtered by `AuthProvider.isAdmin` — see [[Workflow - Auth]] and the `adminOnly` flag in `_NavSpec` of [[MainPcShell]].

## Recording UX surfaces

- [[StartHikeRamp]] — slide-to-start + 3-2-1 countdown, returns `true` from `show()` on confirm
- [[FinishHikeSheet]] — shared Save / Discard / Resume sheet (the Strava-style flow). Called from both [[TTMapScreen]] (Map sheet STOP) and [[LiveTrackingScreen]] (FINISH button).
- [[LiveTrackingScreen]] — full-screen recording UI (legacy route, still wired from Teams "View Live Map")
- [[TTMapScreen]] — the live recording UX during a hike, with bottom sheet stats

## Depends on

- [[Flutter Providers Module]] — `context.watch<X>()` everywhere
- [[Flutter Widgets Module]] — every screen composes design primitives ([[TTGlass]], [[TTPill]], etc.)
- [[Flutter Services Module]] — direct service calls for one-off ops
- [[TT Design Tokens]] — surface colours, radii, typography

## Used by

- [[AuthGate]] dispatches to one of [[AppShell]] / [[MainPcShell]]
- Some screens push other screens via `Navigator.push`
