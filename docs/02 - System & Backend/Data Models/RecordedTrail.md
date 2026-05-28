---
tags: [type/model, layer/frontend, status/stable, domain/recording]
aliases: [RecordedTrail Dart model, TrailSharing]
source_paths: [trailtether_app/lib/models/recorded_trail.dart]
---

# RecordedTrail

Dart class — metadata view of a row in the [[recorded_trails]] Supabase table. The actual track points live as a `.gpx` file in Storage; this class is just the row.

## Fields

```dart
class RecordedTrail {
  final String id;
  final String hikeId;
  final String userId;
  final String? teamId;
  final String name;
  final String? description;
  final double distanceKm;
  final int ascentM, descentM;
  final int durationSeconds;
  final String activityType;
  final int pointCount;
  final double? minLat, maxLat, minLon, maxLon;
  final String gpxPath;               // Storage path
  final String? thumbnailPath;
  final TrailSharing sharing;         // private / team / public
  final int shareCount, downloadCount;
  final DateTime createdAt, updatedAt;
  final String? ownerDisplayName;     // joined from profiles
}
```

## TrailSharing enum

```dart
enum TrailSharing { private, team, public }
```

With a `TrailSharingX` extension for `.key` (`'private'`/`'team'`/`'public'`) + `.label` + parse helper.

## Loading points

Points aren't in this class — they're downloaded on demand via `RecordedTrailService.downloadPoints(trail)`. First tries the local cache (`recorded_trails_cache/<gpx_path>`), falls back to Supabase Storage download.

## Used by

- [[recorded_trails_provider.dart]] (`mine`, `community` lists)
- [[recorded_trail_service.dart]] (all CRUD)
- `recorded_trails_screen.dart` (display)

## See also

- [[recorded_trails]] table — the row this maps to
- [[SavedHike]] — what gets promoted into a RecordedTrail
