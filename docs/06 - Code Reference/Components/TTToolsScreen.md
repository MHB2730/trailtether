---
tags: [type/component, layer/frontend, status/stable, domain/mobile, domain/tools]
aliases: [tt_tools_screen, Tools tab]
source_paths: [trailtether_app/lib/screens/tt_tools_screen.dart]
---

# TTToolsScreen

Mobile Tools tab. Field utilities for hikers.

## Tools

- Flashlight (uses `torch_light`)
- Bubble level (uses `sensors_plus` accelerometer)
- Compass (uses `flutter_compass`)
- Whistle / signal (audio)
- GPS coordinates display (raw lat/lon + accuracy)
- Sun times (sunrise/sunset for current location, computed by [[sun_utils.dart]])

## State

Holds a local `_ToolPrefs` ChangeNotifier (declared inside the same file) — sticky preferences for which tools are favourited / always-on.

> [!note] Pattern divergence
> `_ToolPrefs extends ChangeNotifier` directly without going through the [[Flutter Providers Module]] pattern. Inconsistent — could be hoisted to a proper provider but very small surface, low priority.

## Depends on

- `torch_light`, `sensors_plus`, `flutter_compass` (platform plugins)
- [[sun_utils.dart]]
- [[TT Design Tokens]]

## Used by

- [[AppShell]] (tab 3)

## Key file

- `lib/screens/tt_tools_screen.dart` (~1300 LOC)
