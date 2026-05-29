---
type: source-file
status: current
area: code
source_paths:
  - trailtether_app/lib/core/theme.dart
aliases:
  - theme.dart
---

# theme.dart

Exports `appDarkTheme` — the `ThemeData` passed to `MaterialApp` in [[main.dart]].

## Key points

- Based on `ThemeData.dark()` seeded with the TT palette
- Primary colour: `TT.ember` (`#FF6A2C`)
- `NavigationBarTheme`, `ElevatedButtonTheme`, `AppBarTheme` all wired to TT tokens
- Background: `TT.bg` (`#07090C`)
- No Cupertino / Material 3 `useMaterial3: false` — check current file for status

## Used by

- [[main.dart]] — `MaterialApp(theme: appDarkTheme)`

## Depends on

- [[TT Design Tokens]] (`design_tokens.dart`)
