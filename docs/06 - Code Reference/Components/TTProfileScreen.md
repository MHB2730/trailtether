---
tags: [type/component, layer/frontend, status/stable, domain/mobile, domain/profile]
aliases: [tt_profile_screen, Profile tab]
source_paths: [trailtether_app/lib/screens/tt_profile_screen.dart]
---

# TTProfileScreen

Mobile Profile tab. Shows hiker stats, achievements, and account controls.

## Sections

- Avatar + name + edit profile entry
- Lifetime stats (total km, total ascent, hike count, peaks) — derived from [[hike_history_provider.dart]]
- Achievements gallery (30 conditions defined in [[profile_provider.dart]])
- Hike History list (pushes HikeHistoryScreen)
- Recorded Trails list (pushes RecordedTrailsScreen)
- Settings: units toggle ([[units_provider.dart]]), theme, ghost mode, battery saver
- Sign out

## Achievements

[[profile_provider.dart]] defines 30 achievement unlock conditions ranging from distance milestones, peak counts, time-of-day, team participation, named-trail challenges. Each unlock writes back to [[profiles]] + shows a [TTAchievementMedallion](Flutter Widgets Module#design-primitives-widgetsdesign) toast.

## Depends on

- [[auth_provider.dart]], [[profile_provider.dart]], [[hike_history_provider.dart]], [[recorded_trails_provider.dart]], [[units_provider.dart]]
- [[TT Design Tokens]], `TTAchievementMedallion`

## Used by

- [[AppShell]] (tab 5)

## Key file

- `lib/screens/tt_profile_screen.dart`
