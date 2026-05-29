---
tags: [type/component, layer/frontend, status/stable, domain/mobile, domain/navigation]
aliases: [app_shell, mobile shell]
source_paths: [trailtether_app/lib/screens/app_shell.dart]
---

# AppShell

The mobile (Android) navigation shell. **6 bottom-tabs** using `_LazyTabStack` — tabs are kept alive once first visited via `Offstage`, so state persists across tab switches.

## Public surface

- `AppShell({ super.key })` — built by [[AuthGate]] when `MediaQuery.size.width <= 900`

## Tabs

| Index | Tab | Component |
|---|---|---|
| 0 | Home | [[TTHomeScreen]] |
| 1 | Map | [[TTMapScreen]] |
| 2 | Tools | TTToolsScreen |
| 3 | Community | TTCommunityScreen |
| 4 | Teams | TTTeamScreen |
| 5 | Profile | [[TTProfileScreen]] |

Navigation bar: `TTBottomNav` (`widgets/design/tt_bottom_nav.dart`).

## Initialisation side effects

On first build (when user is signed in):
- Calls `TeamProvider.listenForUser(user)` — starts Realtime team subscription
- Calls `TeamTrackingProvider.reportOnceOnLaunch()` — one-shot GPS ping so the PC command centre sees the hiker on app open (no background drain until Start Hike)

## IME / keyboard handling

- Wraps the body in a `GestureDetector(HitTestBehavior.translucent)` that calls `FocusManager.instance.primaryFocus?.unfocus()` on tap — dismisses keyboard when tapping dead space
- `_goTo(i)` also calls `unfocus()` before switching tabs so the IME doesn't hang over new tab content

## Used by

- [[AuthGate]]

## Depends on

- All `tt_*_screen.dart` files — see [[Flutter Screens Module]]
- `TTBottomNav` — [[Flutter Widgets Module]]
- [[team_provider.dart]], [[team_tracking_provider.dart]]
