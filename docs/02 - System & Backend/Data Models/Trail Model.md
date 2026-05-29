---
tags: [type/model, layer/frontend, status/stable, domain/trails]
aliases: [Trail, Trail Dart model]
source_paths: [trailtether_app/lib/models/trail.dart]
---

# Trail Model

Dart class for a curated trail (mirror of the [[trails]] table row).

## Fields

```dart
class Trail {
  final String id;
  final String name;
  final double distanceKm;
  final int elevationGainM, elevationDescentM;
  final double estTimeHours;
  final String difficulty;
  final int minEle, maxEle;
  final String description;
  final bool published;                 // mirrors trails.published (added 2026-05-29)
  final List<TrailCoord> coords;        // smoothed at parse time
  final List<ElevationPoint> profile;
  final double minLat, maxLat, minLon, maxLon;  // pre-computed bbox

  bool get isCave => name.toLowerCase().contains('cave');
  TrailCoord? get cavePin => coords.reduce((a, b) => a.elevation > b.elevation ? a : b);
  double get avgGradePct;
  double naismithHours(double paceFactor);
}
```

## Sub-types

- `TrailCoord(lon, lat, elevation)` — positional args, NOT (lat, lon). Stored as `[lon, lat, ele]` triples in JSON.
- `ElevationPoint(distanceKm, elevationM)` — for the chart

## fromJson does heavy work

Not a simple deserialiser. On parse:
1. RDP simplify with 1.5m tolerance
2. Chaikin smoothing (1 iteration) if `processedCoords.length` in (3, 500)
3. 5-point moving-average smoothing on elevations
4. Compute distance, gain, descent, min/max ele, difficulty (objective formula based on gradient + total effort)
5. Build downsampled elevation profile (≤200 points)

> [!note] Stored values now win (2026-05-29)
> `difficulty` and `elevation_gain_m` are taken from the stored [[trails]] row when present, so PC Trails admin edits to those fields **persist**. The gradient/effort formula (difficulty) and coord-derived gain are only a **fallback** when the row carries no value. Previously both were *always* recomputed on parse, so admin edits to difficulty/gain never stuck. `published` is read from the row too.

Fallback difficulty (when no stored label): flatness rule (`<50m gain → Easy`), then `max(gradeLevel, effortLevel)`.

## isCave

`isCave => name.toLowerCase().contains('cave')` — drives the brown/dotted styling in [[TrailMapWidget]] + [[TrailMarkerLayer]]. Source of the Aasvoelkrans visibility complaint (see [[Audit Findings]]).

## Used by

- [[trail_service.dart]] — `loadTrails()` builds list
- [[static_data_provider.dart]] — holds the list
- [[TrailMapWidget]], [[TrailMarkerLayer]] — render
- [[PcTrailsScreen]] — display + edit form initial values
- [[trail_repository.dart]] — wraps to/from Supabase row

## Key file

- `lib/models/trail.dart` (~460 LOC — heavy on parse logic)
