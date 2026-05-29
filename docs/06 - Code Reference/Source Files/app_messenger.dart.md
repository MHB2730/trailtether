---
type: source-file
status: current
area: code
source_paths:
  - trailtether_app/lib/core/app_messenger.dart
aliases:
  - app_messenger
  - AppMessenger
---

# app_messenger.dart

`AppMessenger` — thin in-app overlay notification helper. Part of [[Flutter Core Module]].

## Purpose

Shows short-lived success / error / info banners without requiring a `BuildContext` inside services or providers. Providers call this to surface errors without crashing or needing to thread context through the call stack.

## Key members

| Member | Role |
|---|---|
| `AppMessenger.show(message, type)` | Static method — shows a banner at the top/bottom of the screen |
| `AppMessenger.init(context)` | Called once in the root widget to register the global context |

## Used by

- Providers (e.g. [[recording_provider.dart]], [[hike_history_provider.dart]]) to surface non-fatal errors
- Any service that needs to show a user-facing message without a BuildContext

## Depends on

- [[TT Design Tokens]] — for banner styling
