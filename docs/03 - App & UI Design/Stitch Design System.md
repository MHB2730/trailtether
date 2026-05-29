---
type: design-system
status: current
area: design
aliases:
  - Stitch Design System
---

# Stitch Design System

Trailtether's custom design system, implemented as the `TT` class in `lib/core/design_tokens.dart`. Optimised for outdoor visibility and night hiking.

See [[TT Design Tokens]] for the full token reference.

## Colour palette

Two colour sets co-exist during the migration from legacy to TT:

| Role | Legacy (`constants.dart`) | TT (`design_tokens.dart`) |
|---|---|---|
| Root background | `kColorBg #0D0D0D` | `TT.bg #07090C` |
| Primary accent | `kColorOrange #E8541A` | `TT.ember #FF6A2C` |
| Text / cream | `kColorCream #E8DFC8` | `TT.text #EEF1F4` |
| Panel surface | `kColorPanel` (88% opacity) | `TT.surf #131820` |
| Border | `kColorBorder` (12% opacity) | `TT.line (5.5% white)` |
| Cyan | `kColorCyan #00F2FF` | `TT.blue #5AA1D6` |
| Purple | `kColorPurple #9D00FF` | — |

**New code should use `TT.*` tokens only.**

## Typography

| Usage | Font | Weight |
|---|---|---|
| All body, labels, titles | **Manrope** (Google Fonts) | 600–900 |
| Numerals, coordinates, codes | **JetBrains Mono** (Google Fonts) | 700–800 |

> Legacy `kStyle*` constants in `constants.dart` still reference `'Inter'` (font family string). These are only used in screens not yet migrated to TT tokens.

## Night map mode

- **Base layer**: Stadia Alidade Smooth Dark (`kNightTileUrl`)
- **Visual treatment**: Red `ColorFiltered` overlay on the map widget
- **Purpose**: Preserves night vision while maintaining full topographic awareness

## Map tile providers

| Label | Source | Notes |
|---|---|---|
| Outdoor (default) | OpenTopoMap | Contour lines + trail markings, free, caps at zoom 17 |
| Standard | OpenStreetMap | Free, zoom 19 |
| Topo | Esri World Topo | Free, richer topo styling |
| Satellite | Esri World Imagery | Free satellite |
| MT Outdoor | MapTiler | Premium — only enabled when `MAPTILER_KEY` dart-define is provided |

## 3D map

MapLibre GL JS served via WebView — see [[TrailMap3DWidget]] and [[3D WebView Bridge]].
