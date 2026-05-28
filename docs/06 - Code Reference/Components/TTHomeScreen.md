---
tags: [type/component, layer/frontend, status/stable, domain/mobile]
aliases: [tt_home_screen, Home tab]
source_paths: [trailtether_app/lib/screens/tt_home_screen.dart]
---

# TTHomeScreen

Mobile Home tab. The user's overview surface: greeting + quick actions + weather + recent activity feed.

## Sections

| Section | What it shows | Source |
|---|---|---|
| Greeting + avatar | Profile photo, name, level/badges | [[profile_provider.dart]] |
| Quick Actions | Start Hike (via [[StartHikeRamp]]) · Plan Route · Live Track · SOS | local |
| Weather hero | 7-day Berg forecast with hike-score formula | [[weather_provider.dart]] |
| Recent Activities | Strava-style feed (community + own) | [[community_provider.dart]] + [[hike_history_provider.dart]] |
| Achievements teaser | Recently unlocked badges | [[profile_provider.dart]] |

## Quick Actions logic

```dart
if (recording.isRecording) primaryLabel = 'Recording';
else if (recording.isPaused) primaryLabel = 'Resume';
else primaryLabel = 'Start Hike';
```

When `Start Hike` is tapped:
1. [[StartHikeRamp]] modal pushed
2. On confirm, `rec.start()` runs
3. `onNavigate(1)` switches to Map tab so the user sees the live recording UI

## Hike-score formula

Lines ~1963-1972 (per agent reading). Mirrors [[weather.js]] on the public site. Multi-factor heuristic combining weather code, wind, precip, temp, daylight.

## Depends on

- [[auth_provider.dart]], [[profile_provider.dart]], [[recording_provider.dart]], [[weather_provider.dart]], [[community_provider.dart]], [[hike_history_provider.dart]]
- [[StartHikeRamp]]
- [[TT Design Tokens]], [[TTGlass]], [[TTPill]]

## Used by

- [[AppShell]] (tab 0)

## Key file

- `lib/screens/tt_home_screen.dart` (~2000 LOC)

## Side effects

- Watches multiple providers → rebuilds on any change
- One lint at line 520: `use_build_context_synchronously` after `await StartHikeRamp.show()`. Pre-existing, see [[Known Issues]].
