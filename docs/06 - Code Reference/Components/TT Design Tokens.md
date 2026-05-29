---
tags: [type/component, layer/frontend, status/stable, domain/design]
aliases: [design_tokens, TT, design system]
source_paths: [trailtether_app/lib/core/design_tokens.dart]
---

# TT Design Tokens

The Trailtether 2.0 design system. Single `TT` static class in `lib/core/design_tokens.dart`. Replaces the older `kColor*` / `kStyle*` constants from [[constants.dart]] (which still exist for backward compat — do not use for new code).

## Surfaces (background layers)

`TT.bg (#07090C)` → `TT.bg2` → `TT.bg3` → `TT.surf` → `TT.surf2` → `TT.surf3 (#232A35)`

Deep graphite to mid-grey. `TT.bg` is the root window background. `TT.surf*` are card/panel surfaces.

## Lines

`TT.line (5.5% white)` · `TT.line2 (10%)` · `TT.line3 (16%)` — subtle dividers.

## Text

`TT.text (#EEF1F4)` · `TT.text2` · `TT.text3` · `TT.text4 (#3D454D)` — high-contrast to almost-invisible.

## Burnt Ember (brand accent)

| Token | Value | Use |
|---|---|---|
| `TT.ember` | `#FF6A2C` | Primary CTA, active state, recording indicator |
| `TT.ember2` | `#FF8A4D` | Hover / lighter variant |
| `TT.ember3` | `#FFB486` | Subtle tint |
| `TT.emberDim` | 14% ember | Background glow on ember buttons |
| `TT.emberSoft` | 6% ember | Very subtle ember wash |
| `TT.emberInk` | `#1A0D04` | Text on ember backgrounds (FAB labels) |

> Note: `TT.ember` (`#FF6A2C`) ≠ `kColorOrange` (`#E8541A`) from [[constants.dart]]. The ember palette is the canonical brand colour for TT-skinned screens.

## Status semantics

`TT.blue` · `TT.green` · `TT.amber` · `TT.red` — for info / success / warning / danger.

## Geometry

| Token | Value |
|---|---|
| `TT.rSm` | 8 |
| `TT.rMd` | 12 |
| `TT.rLg` | 16 |
| `TT.rXl` | 22 |
| `TT.s1–s6` | 4, 8, 14, 16, 24, 32 |

## Shadows

- `TT.shadowCard` — generic card drop shadow
- `TT.shadowEmber` — orange glow on primary CTAs

## Animation

- `TT.easeOut` (cubic) · `TT.drawCurve`
- `TT.dFast (200ms)` · `TT.dMed (350ms)` · `TT.dSlow (700ms)` · `TT.dDraw (1800ms)`

## Typography

All text uses **Manrope** (Google Fonts). All numerals/mono use **JetBrains Mono**.

| Helper | Font | Weight | Use |
|---|---|---|---|
| `TT.title(size)` | Manrope | w800 | Hero titles, screen headers |
| `TT.body(size)` | Manrope | w600 | Body copy |
| `TT.label(size)` | Manrope | w700 | Uppercase labels, tags |
| `TT.mono(size)` | JetBrains Mono | w700 | GPS coords, codes |
| `TT.numStyle(size)` | JetBrains Mono | w800 | Stat tile numerals |

## Used by

- Every TT-skinned screen in [[Flutter Screens Module]]
- Every design widget in [[Flutter Widgets Module]]

## Depends on

- `google_fonts` (Manrope + JetBrains Mono)
