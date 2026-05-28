---
tags: [type/component, layer/frontend, status/stable, domain/design]
aliases: [tt_glass, TTGlassCard, frosted glass]
source_paths: [trailtether_app/lib/widgets/design/tt_glass_card.dart]
---

# TTGlass

Frosted-glass card primitive. Used as the surface for nearly every overlay in the app: stat tiles, situation bars, banners.

## Props

```dart
TTGlass({
  required Widget child,
  EdgeInsetsGeometry? padding,
  double? radius,        // default TT.rMd
  Color? borderColor,    // default TT.line2
  ... 
})
```

## Style

- Background: low-alpha dark colour (`bg2`-derived)
- Border: 1px hairline (`TT.line2`)
- Optional rounded corners (default `TT.rMd`)
- Compatible with light + dark themes (currently dark-only)

## Used by

Heavily by [[LiveTrackingScreen]] (situation bar, stat overlays), [[TTHomeScreen]] (Quick Actions backgrounds), [[TTMapScreen]] (overlays). Most screens compose at least one.

## Depends on

- [[TT Design Tokens]] only

## Key file

- `lib/widgets/design/tt_glass_card.dart`
