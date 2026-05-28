---
tags: [type/component, layer/frontend, status/stable, domain/desktop, domain/navigation]
aliases: [pc_shell, Base Camp]
source_paths: [trailtether_app/lib/screens/pc/pc_shell.dart]
---

# MainPcShell

Desktop "Base Camp" shell. macOS-style traffic-light controls + 232-wide sidebar nav + main content. 8 sections (2 admin-only).

## Public surface

- `MainPcShell({ super.key })` — built by [[AuthGate]] when on desktop

## Sections (`_PcSection` enum)

| Section | Component | Admin-only |
|---|---|---|
| dashboard | [[MissionControlTab]] (live team map) | no |
| watch | `_PcHikeWatch` (private widget) | no |
| hikers | `_PcHikersList` (private widget) | no |
| history | `_PcHistory` (private wrapper around HikeHistoryScreen) | no |
| **trails** | [[PcTrailsScreen]] | **yes** |
| alerts | `_PcAlerts` (private widget) | no |
| pair | `PcPairDeviceScreen` (QR pairing) | no |
| **settings** | [[AdminSettingsTab]] | **yes** |

## Admin gate

`_NavSpec` has `adminOnly: bool` field. The sidebar filters `_kNav` by `AuthProvider.isAdmin` before rendering — admin-only tabs are completely hidden from non-admin users (cleaner than showing tabs that error on use server-side).

```dart
final isAdmin = context.watch<ap.AuthProvider>().isAdmin;
final visibleNav = _kNav.where((n) => isAdmin || !n.adminOnly).toList();
```

See [[Workflow - Auth]] and [[Audit Findings]] (A1 fix).

## Window chrome

Uses `window_manager` for close/minimize/maximize via custom traffic-light buttons in `_PCTitleBar`. macOS-style colour palette: red/yellow/green dots in upper-left.

## State

- `_active`: current `_PcSection` (default `dashboard`)
- TeamProvider listener registered in `initState` so teams + members load on app open

## Side effects

- Realtime channels managed by inner components ([[MissionControlTab]] subscribes to track points + incidents)
- Window manager calls (close, maximize, minimize)

## Used by

- [[AuthGate]]

## Depends on

- [[auth_provider.dart]] — for isAdmin
- [[team_provider.dart]] — sidebar shows "WATCHING · N HIKERS" pulse
- [[MissionControlTab]], [[PcTrailsScreen]], [[AdminSettingsTab]]
- `window_manager` package

## Key file

- `lib/screens/pc/pc_shell.dart` (~1800 LOC — includes private section widgets inline)
