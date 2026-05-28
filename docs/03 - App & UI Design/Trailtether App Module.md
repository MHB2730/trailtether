---
tags: [type/module, layer/frontend, status/stable, domain/mobile, domain/desktop]
aliases: [trailtether_app]
source_paths: [trailtether_app/lib/main.dart, trailtether_app/pubspec.yaml]
---

# Trailtether App Module

The Flutter project that ships as the **Android mobile app** and **Windows desktop "Base Camp" app** from a single codebase.

## Purpose

Hiker safety + recording for the user; live team-tracking command centre for the watcher. One binary per platform, one provider tree, branching UX at the shell layer ([[AppShell]] vs [[MainPcShell]]).

## Entry point

[[main.dart]] →
1. Init [[logger_service.dart]] → [[offline_map_service.dart]] FMTC → Supabase init → [[notification_service.dart]] → [[deep_link_service.dart]]
2. Sets full-screen UI mode (`immersiveSticky`)
3. Wraps `TrailtetherApp` in a `MultiProvider` with **16 ChangeNotifierProviders + 2 proxy providers** (see [[Flutter Providers Module]])
4. Renders `MaterialApp` → `UpdateGate` → [[AuthGate]] → shell

## Sub-modules

| Module | What it owns |
|---|---|
| [[Flutter Core Module]] | constants, design tokens, theme, utils, runtime config |
| [[Flutter Models Module]] | Domain types: Trail, RecordingPoint, SavedHike, Incident, etc. |
| [[Flutter Providers Module]] | State management (Provider + ChangeNotifier) |
| [[Flutter Screens Module]] | Page-level UI |
| [[Flutter Services Module]] | Supabase wrappers + GPS, weather, GPX, logging |
| [[Flutter Widgets Module]] | Reusable UI primitives (TT design, map layers) |

## Build targets

Per `pubspec.yaml`:

- **Android**: signed APK distributed via Supabase Storage + in-app updater
- **Windows**: MSIX signed, distributed same way; protocol activation for `trailtether://`
- **iOS**: build config exists but inactive (not currently shipped)
- **Web**: build config exists but not actively maintained

## Platform-conditional code

| Concern | Decision point |
|---|---|
| Background location | Android-only `LocationAlways` + foreground service ([[location_service.dart]]) |
| Compass | `flutter_compass` skipped on Windows/macOS/Linux ([[LiveTrackingScreen]] `_initCompass`) |
| Updates | Android → [[app_releases]] table; Windows → GitHub releases ([[update_service.dart]]) |
| Window chrome | `window_manager` on desktop, `SystemChrome` on mobile |
| OAuth callback | `app_links` deep-link scheme `trailtether://` ([[deep_link_service.dart]]) |

## Key files

- `lib/main.dart` — entry
- `lib/screens/auth_gate.dart` — [[AuthGate]]
- `lib/screens/app_shell.dart` — mobile shell ([[AppShell]])
- `lib/screens/pc/pc_shell.dart` — desktop shell ([[MainPcShell]])
- `pubspec.yaml` — see [[Pubspec Configuration]]
- `assets/data/routes_cleaned.json` — bundled 239-trail fallback for [[trail_service.dart]]

## Depends on

- [[Supabase Migrations Module]] (DB schema it reads/writes)
- [[Supabase Functions Module]] (calls [[apk-download-gate]], [[finalize-orphan-hikes]], etc.)
- [[supabase_flutter]], [[flutter_map]], [[provider]], [[geolocator]] — see [[Tech Stack]]

## Used by

- The end user (hiker on Android)
- The team watcher (Windows PC)
