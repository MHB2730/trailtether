---
tags: [type/model, layer/frontend, status/stable, domain/recording]
aliases: [RecordingPoint Dart model]
source_paths: [trailtether_app/lib/models/recording_point.dart]
---

# RecordingPoint

Dart class — one GPS fix during a recording. Smallest unit of recorded data.

## Fields

```dart
class RecordingPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime timestamp;
  final double speed;     // m/s
  final double accuracy;  // m
}
```

## JSON shape

```dart
{
  'lat': 29.6205,
  'lon': -29.3204,
  'alt': 1990.7,
  'ts': '2026-05-27T10:23:14.000Z',
  'spd': 1.4,
  'acc': 8.3,
}
```

## Validation

`RecordingPoint.fromJson` throws `FormatException` for invalid lat/lon (out of range, NaN, missing). Caller decides whether to drop the row or fail the parse.

## Used by

- [[recording_provider.dart]] — `_points` list, persisted draft
- [[SavedHike]] — `points: List<RecordingPoint>` field
- [[recorded_trail_service.dart]] — GPX serialisation (`_buildGpx` writes `<trkpt>` elements)
- [[hike_history]] table — stored as jsonb array

## Related

- [[Trail Model]] uses its own `TrailCoord` (lon, lat, ele) — NOT this class. The two are deliberately separate (RecordingPoint has more fields).
