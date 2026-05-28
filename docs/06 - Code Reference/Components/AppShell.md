---
tags: [type/component, layer/frontend, status/stable, domain/mobile, domain/navigation]
aliases: [app_shell, mobile shell]
source_paths: [trailtether_app/lib/screens/app_shell.dart]
---

# AppShell

The mobile (Android) navigation shell. 6 bottom-tabs.

## Public surface

- `AppShell({ super.key })` — built by [[AuthGate]] when on mobile

## Tabs

| Index | Tab | Component |
|---|---|---|
| 0 | Home | [[TTHomeScreen]] |
| 1 | Map | [[TTMapScreen]] |
| 2 | Community | TTCommunityScreen |
| 3 | Tools | [[TTToolsScreen]] |
| 4 | Teams | [[TTTeamScreen]] |
| 5 | Profile | [[TTProfileScreen]] |

State: `_active` (current tab index), `_navigate(int)` callback passed down to children so they can switch tabs (e.g. Home's "Start Hike" → switches to Map).

## Side effects

- Listens for app lifecycle changes (foreground/background) to pause/resume realtime listeners as needed
- Wraps children in `WillPopScope` to intercept back button on mobile

## Used by

- [[AuthGate]]

## Depends on

- All `tt_*_screen.dart` files in [[Flutter Screens Module]]
- [[TT Design Tokens]] — bottom nav styling

## Key file

- `lib/screens/app_shell.dart` (~80-150 LOC)
