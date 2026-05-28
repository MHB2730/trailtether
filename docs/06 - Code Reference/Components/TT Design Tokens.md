---
tags: [type/component, layer/frontend, status/stable, domain/design]
aliases: [design_tokens, TT, design system]
source_paths: [trailtether_app/lib/core/design_tokens.dart]
---

# TT Design Tokens

The Trailtether 2.0 design system. All static constants on a single class `TT` in `lib/core/design_tokens.dart`. Replaces the older `kColor*` / `kStyle*` constants from [[constants.dart]] (which still exist for backward compat).

## Categories

### Surfaces (background layers)

`TT.bg` · `TT.bg2` · `TT.bg3` · `TT.surf` · `TT.surf2` · `TT.surf3`

Deep slate to mid-grey. `bg` is the darkest (root window). `surf*` are card surfaces.

### Lines

`TT.line` · `TT.line2` · `TT.line3`

5.5%, 10%, 16% white — subtle dividers.

### Text

`TT.text` (high contrast) · `TT.text2` · `TT.text3` · `TT.text4` (most muted)

### Burnt Ember (brand accent)

`TT.ember` · `TT.ember2` · `TT.ember3` · `TT.emberDim` (14% bg) · `TT.emberSoft` (6%) · `TT.emberInk` (text-on-ember)

The signature Trailtether orange (~`#FF6A2C`). Used for CTAs, active state, recording-active indicators.

### Status semantics

`TT.blue` · `TT.green` · `TT.amber` · `TT.red`

For OK / success / warning / danger respectively.

### Radii

`TT.rSm = 8` · `TT.rMd = 12` · `TT.rLg = 16` · `TT.rXl = 22`

### Spacing

`TT.s1 = 4` · `TT.s2 = 8` · `TT.s3 = 12` · `TT.s4 = 16` · `TT.s5 = 24` · `TT.s6 = 32`

### Shadows

`TT.shadowCard` — generic card shadow
`TT.shadowEmber` — orange glow used on primary CTAs

### Animation

`TT.easeOut` curve · `TT.dFast` / `TT.dMed` / `TT.dSlow` / `TT.dDraw` durations

### Typography

Static helpers around GoogleFonts:
- `TT.body(size, w, color, letterSpacing)` — Manrope text
- `TT.title(size, letterSpacing)` — Manrope w800
- `TT.label(size, color, letterSpacing)` — Manrope w700, uppercase-friendly
- `TT.mono(size, color, letterSpacing)` — JetBrains Mono for numerals
- `TT.numStyle(size, color, w, letterSpacing)` — Mono, w900 — used for stat tile numerals

## Used by

- Every screen in [[Flutter Screens Module]]
- Every widget in [[Flutter Widgets Module]]
- See backlinks for a near-complete list

## Depends on

- `google_fonts` (Manrope + JetBrains Mono)
- `flutter/material.dart` (Color, TextStyle, FontWeight)

## Key file

- `lib/core/design_tokens.dart` (~90 LOC)
