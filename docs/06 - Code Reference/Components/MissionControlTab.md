---
tags: [type/component, layer/frontend, status/stable, domain/desktop, domain/teams, domain/map]
aliases: [mission_control_tab, Mission Control]
source_paths: [trailtether_app/lib/screens/admin/mission_control_tab.dart]
---

# MissionControlTab

The "Mission Control" dashboard section in [[MainPcShell]]. Live team map: realtime hiker positions, incidents, recorded routes, 3D view toggle.

## Composition

- Full-screen map ([[TrailMapWidget]] or `TrailMap3DWindowsWidget`)
- Realtime channels:
  - `team_member_locations` INSERT/UPDATE → updates `_locations` map
  - `incidents` INSERT/UPDATE → SafetyProvider stream
  - `team_member_track_points` INSERT → appends to `_liveTracks` per-hiker route polylines
- Cave + accommodation marker layers
- Trail polylines from [[static_data_provider.dart]] `allTrails`
- Per-hiker label (name + ago timestamp)

## State

- `_locations`: Map<uid, TeamMemberLocation> — latest known positions
- `_liveTracks`: Map<uid, List<LatLng>> — last 60 min of track points per hiker
- `_tickTimer`: redraws "Nm ago" labels every 30s
- `_safetyRefreshTimer`: refreshes incidents periodically
- `_show3D`: toggle between 2D and 3D viewer
- `_selectedObject`: the currently-tapped marker (cave / track / incident)

## Trail tap → detail sheet

Tapping a trail polyline opens [[TrailDetailScreen]] in a modal bottom sheet. Caves open [[CaveDetailSheet]], incidents open [[IncidentDetailSheet]].

## Used by

- [[MainPcShell]] dashboard section (default-active)
- [[TeamDetailScreen]] (also opens this directly when the user wants a fullscreen team-tracking view)

## Depends on

- [[static_data_provider.dart]] (trails + caves)
- [[safety_provider.dart]] (incidents)
- [[team_tracking_provider.dart]] (location streams)
- [[gpx_provider.dart]] (user-imported GPX overlays)
- [[TrailMapWidget]] + 3D Windows widget
- [[TT Design Tokens]]

## Cave styling note

Per the [[Audit Findings]] / Aasvoelkrans diagnosis: trails with "cave" in the name are styled brown + dotted + 40% opacity, which makes them hard to see on the dark satellite map. Not a bug — design choice. See [[Workflow - Trails CRUD]] for the admin's path to rename/dedupe these.

## Key file

- `lib/screens/admin/mission_control_tab.dart`
