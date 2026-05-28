---
tags: [type/component, layer/frontend, status/stable, domain/recording]
aliases: [start_hike_ramp]
source_paths: [trailtether_app/lib/widgets/start_hike_ramp.dart]
---

# StartHikeRamp

The deliberate pre-recording ritual. Two stages — slide + countdown — so the app never auto-starts a hike from a mistap.

## Public surface

```dart
static Future<bool> show(
  BuildContext context, {
  String? title,
  String? subtitle,
})
```

Returns `true` if the user completed both stages, `false` if they cancelled or hit back.

## Stages

1. **SLIDE** — user drags a thumb left → right. Release past ~85% commits; release before snaps back.
2. **COUNTDOWN** — 3-2-1-GO with a pulsing hex graphic. Tapping the screen during the countdown cancels and returns to the slide stage.

## Why not just a button?

A button is too easy to tap accidentally. Recording starts background GPS + foreground service + battery drain — needs a deliberate gesture. Slide-then-countdown is friction by design.

## Animations

- `_heartbeat` controller: 1500ms reversing pulse on the hero hex (while idle)
- `_countdown` controller: 3s linear from 0→1 during countdown
- Haptic feedback on slide threshold (medium impact), per-second beat (light), and GO (heavy)

## Caller pattern

```dart
final confirmed = await StartHikeRamp.show(context);
if (!confirmed) return;
final ok = await context.read<RecordingProvider>().start();
if (!ok) showSnack('Location permission required');
```

## Used by

- [[TTHomeScreen]] Quick Action "Start Hike"
- [[TTMapScreen]] `_startRecording`

## Depends on

- [[TT Design Tokens]] only (no providers)

## Key file

- `lib/widgets/start_hike_ramp.dart` (~510 LOC)
