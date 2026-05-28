---
tags: [type/component, layer/frontend, status/stable, domain/design]
aliases: [tt_app_bar, page header]
source_paths: [trailtether_app/lib/widgets/design/tt_app_bar.dart]
---

# TTPageAppBar

Page-level app bar primitive. Used by mobile screens (`TTHomeScreen`, `TTMapScreen`, etc.) as the title bar.

## Props

```dart
TTPageAppBar({
  required String title,
  String? eyebrow,
  List<Widget>? trailing,
})
```

- `eyebrow` — small uppercase label above the title (e.g. "EXPLORE", "RECORD")
- `trailing` — list of action buttons / icons aligned to the right (typically `TTIconBtn`)

## Sibling: TTIconBtn

`TTIconBtn(icon: ..., size: 36, onTap: ...)` — circular icon button used in app bar trailing.

## Layout

Adapts to safe-area inset (status bar height). Eyebrow + title stack vertically; trailing actions row at the right edge.

## Used by

- [[TTHomeScreen]], [[TTMapScreen]], [[TTToolsScreen]], [[TTProfileScreen]] — pretty much every mobile screen

## Depends on

- [[TT Design Tokens]]

## Key file

- `lib/widgets/design/tt_app_bar.dart`
