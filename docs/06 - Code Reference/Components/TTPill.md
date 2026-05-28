---
tags: [type/component, layer/frontend, status/stable, domain/design]
aliases: [tt_pill]
source_paths: [trailtether_app/lib/widgets/design/tt_pill.dart]
---

# TTPill

Status pill / chip widget. Small rounded badge with optional icon and one of several semantic variants.

## Props

```dart
TTPill({
  required String label,
  TTPillVariant variant = TTPillVariant.neutral,
  IconData? leadingIcon,
})
```

## Variants

| Variant | Use |
|---|---|
| `neutral` | Generic info (e.g. "PAUSED") |
| `live` | Active state (e.g. "IN PROGRESS" — pulsing) |
| `success` | Positive (e.g. "ON TRAIL") |
| `danger` | Warning / off-trail / urgent |
| `ember` | Brand-accented (e.g. "RECORDING") |

## Used by

- [[LiveTrackingScreen]] situation bar ("ON TRAIL" / "OFF TRAIL")
- [[TTMapScreen]] recording panel ("IN PROGRESS" / "PAUSED")
- [[MainPcShell]] nav (live pulse on "Hike Watch")
- Most screens use at least one

## Depends on

- [[TT Design Tokens]]

## Key file

- `lib/widgets/design/tt_pill.dart`
