---
tags: [type/model, layer/frontend, status/stable, domain/recording]
aliases: [SavedHike Dart model]
source_paths: [trailtether_app/lib/models/saved_hike.dart]
---

# SavedHike

Dart class — a finished, ready-to-persist hike. Totals + the full point list.

## Fields (selected)

```dart
class SavedHike {
  final String id;                    // uuid
  final String name;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<RecordingPoint> points;
  final double distanceKm;
  final int durationSeconds;
  final int movingSeconds;
  final double averageSpeedKmh;
  final double movingSpeedKmh;
  final double maxSpeedKmh;
  final int ascentM;
  final int descentM;
  final double minElevationM, maxElevationM;
  final double averageAccuracyM;
  // ... GPS quality counters ...
  final int acceptedFixes, rejectedFixes;
  final String activityType;          // hike / walk / run
  final String activityContext;       // personal / team / training
  final String? benchmarkRouteId;     // → trails.id if recording against a curated trail
  final String? teamId;
  final int peaksClimbed;
}
```

## How it's built

`RecordingProvider.toSavedHike()` constructs from `_points` + activity metadata + computed totals. Then [[FinishHikeSheet]] may override `peaksClimbed` + `teamId` from form input before passing to `HikeHistoryProvider.add()`.

## JSON shape

[[SavedHike]] is the format persisted to SharedPreferences (key `saved_hikes_v1`). Also the wire format for [[hike_history]] inserts (points → jsonb).

## Used by

- [[FinishHikeSheet]]
- [[hike_history_provider.dart]] (`add`, `syncToSupabase`, `_postCommunityActivity`)
- [[recorded_trail_service.dart]] (`saveFromHike` reads totals + points to build GPX)
- [[Workflow - Record Hike]]

## Key file

- `lib/models/saved_hike.dart`
