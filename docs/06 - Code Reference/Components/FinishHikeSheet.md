---
tags: [type/component, layer/frontend, status/stable, domain/recording]
aliases: [finish_hike_sheet]
source_paths: [trailtether_app/lib/widgets/finish_hike_sheet.dart]
---

# FinishHikeSheet

Shared **Strava-style** Save / Discard / Resume sheet. One source of truth for ending a recording — used by both [[TTMapScreen]] (Map sheet STOP) and [[LiveTrackingScreen]] (FINISH button).

## Public surface

```dart
static Future<void> show(
  BuildContext context,
  RecordingProvider rec, {
  VoidCallback? onSaved,
  VoidCallback? onDiscarded,
})
```

Pauses the recording (`rec.pause()`) and presents the sheet. Non-dismissable: the user must pick Save, Discard, or Keep Recording.

## Form fields

- **Activity name** (text)
- **Activity type** (HIKE / WALK / RUN, segmented)
- **Context** (PERSONAL / TEAM / TRAINING, segmented)
- **Team dropdown** (only when context == 'team')
- **Peaks recorded** (number stepper, default 0)

## Actions

| Action | What happens |
|---|---|
| Keep Recording | `rec.start()` + sheet pops. State preserved. |
| Discard | `rec.clear()` → resets `_startTime`, `currentHikeId`, `_points`, totals. Sheet pops. `onDiscarded` callback fires. |
| Save Activity | `rec.setActivityMetadata(...)` → `_saveActivity(...)` → `rec.clear()` → sheet pops → `onSaved` callback fires. |

## Save path (`_saveActivity`)

1. Build [[SavedHike]] from `rec.toSavedHike()` + form overrides (teamId, peaks)
2. Call `HikeHistoryProvider.add(savedHike, userId: auth.uid)` → returns `HikeSaveResult`
3. Show snack: green (full success), amber (saved offline-only or partial), red (failure)
4. If the hike was against a benchmark trail, toggle [[app_state_provider.dart]] `isCompleted` flag

## Result types ([[hike_history_provider.dart]] `HikeSaveResult`)

| Field | Meaning |
|---|---|
| `localSaved` | Wrote to SharedPreferences |
| `supabaseSynced` | [[hike_history]] upsert succeeded |
| `trailUploaded` | [[recorded_trails]] + GPX file to Storage succeeded |
| `offlineOnly` | userId was null (not signed in) |
| `error` | Last error message |

The snack picks its colour + copy based on which combination of flags is set.

## Why this exists

Before this refactor, [[TTMapScreen]]'s STOP button called `recording.stop()` **directly**, which set status to idle but never showed a save UI. Recordings sat in limbo — points still in memory but inaccessible. The next START would graft new points onto the dead session.

Now both surfaces use `FinishHikeSheet.show()`, both Save and Discard call `rec.clear()`, and the state machine is properly closed.

## Depends on

- [[recording_provider.dart]], [[hike_history_provider.dart]], [[auth_provider.dart]], [[app_state_provider.dart]], [[team_provider.dart]]
- [[SavedHike]] model
- [[TT Design Tokens]]

## Used by

- [[TTMapScreen]] (STOP button)
- [[LiveTrackingScreen]] (FINISH button)

## Key file

- `lib/widgets/finish_hike_sheet.dart` (~640 LOC including private form widgets)
