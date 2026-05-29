---
tags: [type/component, layer/frontend, status/stable, domain/design]
aliases: [TTAppBar, tt_app_bar, page header, TTPageAppBar]
source_paths: [trailtether_app/lib/widgets/design/tt_app_bar.dart]
---

# TTAppBar (TTPageAppBar)

Page-level app bar primitive. Used by mobile screens (`TTHomeScreen`, `TTMapScreen`, etc.) as the title bar. File: `widgets/design/tt_app_bar.dart`. Class: `TTAppBar` (alias: `TTPageAppBar` in older docs).

## Props

```dart
TTAppBar({
  required String title,
  String? eyebrow,        // small uppercase label above the title (e.g. "EXPLORE")
  List<Widget>? trailing, // action buttons aligned right (typically TTIconBtn)
})
```

## Sibling: TTIconBtn

`TTIconBtn(icon: ..., size: 36, onTap: ...)` — circular icon button used in app bar trailing. Defined in the same file.

## Layout

Adapts to safe-area inset (status bar height). Eyebrow + title stack vertically; trailing actions row at the right edge.

## Used by

- [[TTHomeScreen]], [[TTMapScreen]], TTToolsScreen, [[TTProfileScreen]] — essentially every mobile screen

## Depends on

- [[TT Design Tokens]]
