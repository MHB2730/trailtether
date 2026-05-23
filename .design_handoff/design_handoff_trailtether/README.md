# Handoff: Trailtether v2.0 — Mobile App

## Overview

**Trailtether** is a hiking-safety mobile app for the Drakensberg region of South Africa. Its core idea is *the tether*: while you're hiking, your phone broadcasts live position to a base-camp PC at home so someone who cares is always watching, without surveillance or social pressure. Around that core sit trail planning, navigation, hazard reporting, team tracking, SOS, hiking tools (compass / altimeter / torch), achievements, and a community feed.

This package contains the **complete v2.0 design** across 21 screens, organized by user flow.

---

## About the Design Files

The files in `design_source/` are **design references created in HTML** — pixel-fidelity prototypes showing intended look and behavior, **not production code to copy directly**.

The HTML prototypes use:
- React 18 + Babel-in-browser (so designs run as a single-page artboard canvas)
- Inline SVG for icons, animations, charts, and topographic illustrations
- A custom `<DesignCanvas>` wrapper that lays out the 21 screens as a pannable artboard grid — **not part of the final app**

Your task is to **recreate these designs in the target mobile codebase** using its established patterns, components, and styling system.

### Recommended Target Stack

If no mobile codebase exists yet, **React Native** is the strongest fit:
- The visual treatment leans heavily on inline SVG (use `react-native-svg`)
- Many animations are continuous SVG `<animate>` declarations — these port cleanly via `react-native-reanimated` or `react-native-svg`'s animated APIs
- Two custom fonts (`Manrope` and `JetBrains Mono`) — load via `expo-font` or `react-native-asset`
- Targets Android primarily (412×892 design viewport matches a Pixel 7–class device)

**Expo + React Native** is the path of least resistance. If you go native iOS/Android instead, the components map 1:1 — nothing here requires the web.

---

## Fidelity

**High-fidelity (hifi).** All colors, spacing, type, animation curves, and interactions are final. Recreate pixel-perfectly using the target codebase's libraries and component patterns.

---

## Design Tokens

All tokens are declared at the top of `design_source/index.html` as CSS custom properties on `:root`. Mirror them as a typed theme object (or design tokens file) in the target codebase.

### Color palette

```
/* Backgrounds (graphite stack — bottom to top of UI hierarchy) */
--tt-bg:        #07090c       // app background, lowest level
--tt-bg-2:      #0b0e12       // bottom-nav, modals
--tt-bg-3:      #0f1318       // recessed surfaces

/* Surfaces (cards, rows, buttons) */
--tt-surf:      #131820       // primary card
--tt-surf-2:    #1a2029       // secondary card / inset
--tt-surf-3:    #232a35       // active states

/* Lines (borders, dividers) */
--tt-line:      rgba(255,255,255,0.055)  // hairline
--tt-line-2:    rgba(255,255,255,0.10)   // visible divider
--tt-line-3:    rgba(255,255,255,0.16)   // emphasized divider

/* Text */
--tt-text:      #eef1f4    // primary text
--tt-text-2:    #98a1ac    // secondary text, labels
--tt-text-3:    #5a6470    // tertiary text, captions
--tt-text-4:    #3d454d    // ultra-tertiary, watermarks

/* Brand — burnt ember (the singular accent color) */
--tt-ember:     #ff6a2c    // primary ember
--tt-ember-2:   #ff8a4d    // lighter ember (gradient stop, hover)
--tt-ember-3:   #ffb486    // softest ember (highlights, text-on-ember)

/* Semantic colors */
--tt-blue:      #5aa1d6    // info, water features, GPS state
--tt-green:     #4cc38a    // success, tethered, online, shelter
--tt-amber:     #f2a93b    // warning, moderate difficulty
--tt-red:       #e63d2e    // danger, SOS, technical difficulty
```

**Color-usage rules:**
- The ember orange is the ONLY brand accent. Never introduce another saturated hue. Semantic colors (blue/green/amber/red) are only for state.
- Difficulty grades use a fixed scale: `easy=#4cc38a`, `moderate=#f2a93b`, `difficult=#ff6a2c`, `technical=#e63d2e`.
- Achievement rarities: `common=#7a8390`, `rare=#5aa1d6`, `epic=#ff6a2c`, `legendary=#f2a93b`.

### Typography

Two fonts only:

```
--tt-font:  'Manrope', sans-serif   // all UI text
--tt-mono:  'JetBrains Mono', monospace   // numbers, labels, badges, timestamps
```

**Weight conventions in Manrope:**
- `400` body
- `500` secondary body
- `600` emphasized body, sub-labels
- `700` row titles, secondary headings
- `800` titles, primary headings, stat values
- `900` h1, big numbers, summit signage

**Mono is reserved for:**
- All numeric values (`5.4 km`, `1,205 m`, `10:09`)
- ALL-CAPS micro-labels (`UPCOMING HIKE · IN 2 DAYS`, `KM 5.4 · 1,650m`)
- Mono should always have `letter-spacing: 0.06em–0.18em` for that "tactical readout" feel

**Type sizes used:**
- 9–10px: micro-labels, badge text
- 11–13px: body, row titles
- 14–17px: card titles
- 18–24px: section/screen titles
- 26–34px: hero copy ("John D.", "Welcome back.")
- 38–56px: hero numbers (altitude, temperature)

### Spacing scale

There's no strict 4/8 grid — used values are `4, 6, 8, 10, 12, 14, 16, 18, 22, 24, 28` px. Outer screen padding is consistently `18px`. Card internal padding is `12–16px` vertical, `14–16px` horizontal.

### Radius scale

```
--tt-r-sm: 8px    // small chips, pills
--tt-r-md: 12px   // input fields, icon buttons
--tt-r-lg: 16px   // cards
--tt-r-xl: 22px   // hero containers, large bottom sheets
phone frame: 48px (outer), 40px (inner screen)
```

### Shadows

```
--tt-shadow-card:  0 8px 24px -12px rgba(0,0,0,0.6), 0 2px 6px -2px rgba(0,0,0,0.4)
--tt-shadow-ember: 0 10px 30px -8px rgba(255,106,44,0.45)
```

Ember shadow is reserved for the primary CTA and active brand elements only.

---

## Visual Language Rules

The aesthetic is **graphite + ember at dusk on a topographic map**. Strict rules:

1. **No emoji.** A single weather card uses `💧 WATER` and `🔥 kcal` glyphs inside mono-typed micro-labels — that's the entire emoji budget. Everywhere else, use SVG icons or the geometric glyphs in `HAZARD_META` (`~`, `⌂`, `!`, `◉`, `▲`).
2. **No gradients except ember-on-ember.** Backgrounds, surfaces, and dividers are flat. The only gradients are:
   - Primary CTA: `linear-gradient(135deg, #ff8a4d, #ff6a2c)`
   - Ambient ember glow (radial-gradient on hero corners + ridges)
   - Elevation-chart fill (vertical `#ff6a2c` 0.55→0)
3. **Topographic motif everywhere.** Aerial maps, charts, even some empty states draw subtle stacked contour curves. There's a reusable `.topo-overlay` background built from inline SVG.
4. **Reticle / tactical cues.** Corner brackets, mil-tick dial markings, `pathLength=1` dashed trails — Trailtether reads more like a survey instrument than a social app.
5. **Animation budget.** Every screen has *some* idle motion (pulse, draw-in, comet, breath) but it's always slow (2–6s loops) and never blocks interaction. Build animations as continuous SVG `<animate>` declarations or React Native Reanimated worklets.

---

## Screen Inventory

The 21 screens, grouped by the same sections used in the design canvas (`design_source/index.html`):

### Entry
| # | Name | File | Purpose |
|---|---|---|---|
| 00 | Welcome | `screens/welcome.jsx` | First-run carousel of 5 brand pillars (Tether, Plan, Navigate, Aware, SOS). Auto-rotating with manual paging. |
| 00b | Sign In | `screens/sign-in.jsx` | Magic-link auth + Google/Apple SSO. Atmospheric hero photo behind a glassy form card. Mode toggle: Sign In ↔ Create Account. |

### Main Tabs (the 6-tab app shell)
| # | Name | File | Notes |
|---|---|---|---|
| 01 | Home | `screens/home.jsx` | Hero photo with animated burnt trail, 4 quick actions, upcoming hike card, weather card, last-hike card, "Field Intel" hazard stream. The **snow easter egg** lives here. |
| 02 | Map | `screens/maps.jsx` | "Peak Tracker" — full-bleed topographic map with floating distance/time HUD, recording panel with elevation profile. |
| 03 | Tools | `screens/tools.jsx` | 6 sub-tools picked by horizontal scroll: Compass (highly stylized tactical dial), Level, Torch, Altimeter, Sun, Info tips. |
| 04 | Community | `screens/community.jsx` | Segmented Feed / Chat. Feed has compose prompt + posts with attached elevation profile or GPX file. Chat is a team-channel pinned at top + threaded messages with system events. |
| 05 | Teams | `screens/team.jsx` | Live team map with pulsing avatar pins + per-member rows showing position/elev/speed/battery. Floating "+ START HIKE" FAB. |
| 06 | Profile | `screens/profile.jsx` | Avatar header + 4 stat tiles + **Achievements** (the redesigned hex-topo medallions) + grouped settings rows. |

### Trails (the headline new flow)
| # | Name | File | Notes |
|---|---|---|---|
| 07 | Trails List | `screens/trails.jsx` | Filter chips by difficulty + sort dropdown + list cards each with a mini aerial-map thumbnail + live-hiker badge. |
| 08 | Trail Detail | `screens/trail-detail.jsx` | **Headline screen.** Interactive aerial map + synced elevation scrubber — see "Interactive Trail Explorer" below. |
| 09 | Plan Route | `screens/plan-route.jsx` | Top half = planning map with dashed proposed route. Bottom = draggable waypoint list + computed stats card + date/time/tether picker. |

### Activity & Data
| # | Name | File | Notes |
|---|---|---|---|
| 10 | Activity | `screens/stats.jsx` | Segmented My Hikes / Overall Stats. |
| 11 | Hike History | `screens/history.jsx` | YTD stat hero with sparkline + difficulty-filtered list of past hikes with letter-grade score chips. |
| 12 | Achievements (full) | `screens/achievements.jsx` | All 16 badges in a 3-col grid with sub + earned date + rarity tag. |
| 13 | Forecast | `screens/forecast.jsx` | Big day hero with weather icon + temp + circular hike-score gauge. 7-day strip below + hourly graph + detail tiles + alerts. |

### Safety & Emergency
| # | Name | File | Notes |
|---|---|---|---|
| 14 | Safety | `screens/safety.jsx` | Active plan card + giant SOS orb with concentric ripple ring + emergency contacts + gear checklist with progress bar + base-camp tether visualization. |
| 15 | SOS Active | `screens/sos.jsx` | Post-activation: incident header, responder ETA, hazards, event timeline. |

### Utility
| # | Name | File | Notes |
|---|---|---|---|
| 16 | Notifications | `screens/notifications.jsx` | Filter chips by kind + colored severity stripes per row + urgent/read states. |
| 17 | Search | `screens/search.jsx` | Top search bar + scope chips with counts + grouped result sections (trails / people / caves / reports) + recent searches. |
| 18 | Edit Profile | `screens/edit-profile.jsx` | Avatar editor, name/username/email/region fields, bio textarea, experience radio, interest chips, danger-zone delete. |
| 19 | Settings | `screens/settings.jsx` | 7 grouped settings sections (Display, Trail Recording, Maps & Data, Tether, Notifications, Privacy, About). |

---

## Cross-Screen Components

These appear everywhere and should become shared primitives:

### `<StatusBar time right>`
Black bezel status bar with time on left, custom right slot (typically a colored state pill like `LIVE`, `TETHERED`, `GPS`, `SOS`). Height `38px`, padding `8px 22px 0`.

### `<BottomNav active>`
6-tab bottom nav: home, map, tools, community, teams, profile. Height `84px`. Active tab gets:
- Ember-colored icon + label
- 28×3px ember "pip" indicator at the top edge
- All other tabs are `--tt-text-3`
Includes a `130×4px` rounded gesture bar at the very bottom.

### `<PhoneAppBar>` / inline app bars
Each screen's top bar is either:
- **Tab screens**: small logo + `TRAIL` + ember `TETHER` wordmark, then optional `<h1>`, then right-aligned icon buttons
- **Detail screens**: back chevron-up button + tiny `mono` eyebrow + `<h1>` + right-aligned actions
- Right-aligned `icon-btn`s are 38×38px, `border-radius: 12px`, hairline border

### Card patterns
- **`.card`** — Standard surface card. `var(--tt-surf)`, 1px hairline border, `border-radius: 16px`, internal padding `14×16px`, has the dual-shadow.
- **`.glass`** — Floating-on-map card. `rgba(13,17,22,0.72)` + `backdrop-filter: blur(12px) saturate(140%)`, used for HUD overlays on top of maps.
- **`.pressable`** — Any tappable surface. Adds hover/active scale (`active: scale(0.985)`) and a transition. Apply to cards, rows, buttons.

### Pills & badges
- **`.pill`** — `22px` tall, mono `9.5px 700` text, all-caps with `0.12em` letter-spacing. Variants: `.ember`, `.live` (pulsing green dot), `.danger`.
- **Difficulty chip** — `2–3px 7–9px` padding, color from the difficulty scale, mono `8.5–9.5px 800` text.

### Segmented control
`.segmented` — Tab control. Hairline-bordered container with a sliding ember-tinted indicator that animates between tabs (`transition: left/width 350ms cubic-bezier(0.2,0.7,0.2,1)`). Used in Community (Feed/Chat), Stats (My Hikes/Overall), Achievements (All/Unlocked/Locked), Sign In (Sign In/Create).

### Icon system
`<Icon name size color strokeWidth>` — A switch statement in `screens/shared.jsx` covers ~45 icons (mountain, layers, compass, plus, minus, crosshair, route, filter, search, settings, alert, shield, radio, pin, flame, heart, check, chevron-*, send-fill, sos, people, eye, clock, arrow-up, menu, more, wind, rock, home, history, user, phone, map, play, pause, stop, bell, message, navigation, tether). All are stroke-based at viewBox `0 0 24 24`. Recreate as a single `<Icon>` component with the same API and the same SVG path data.

---

## Headline Component: Interactive Trail Explorer

This is in `screens/trail-detail.jsx` and is the most important new pattern. Read it carefully.

**Composition (top-to-bottom inside a single `.card`):**

1. **Header row** — "TRAIL EXPLORER" label + "DRAG TO PREVIEW" mono caption right-aligned.
2. **Aerial map** (`200px` tall, full-width, `border-radius: 11px`):
   - Stylized topographic terrain (radial-gradient bg + two layered curving contour-line groups)
   - Lakes (small filled ellipses), forest patches (filled circles), a river (a blue-tinted Bézier)
   - The trail itself drawn twice: a wide soft `#ff6a2c` glow path (filtered) + a sharp `#ff8a4d` top stroke
   - km labels (2, 4, 6, 8, 10) placed at sampled points along the trail using a `pointAlongTrail(t)` helper
   - Hazard pips at each `TRAIL.hazards[i].km` — colored circle with mono glyph (`~ ⌂ ! ◉ ▲`)
   - Trailhead marker (rotated square) at start, summit marker (triangle) at end
   - **The walking marker** — concentric pulsing rings + a center white dot + a directional arrowhead rotated to match the trail's tangent at the current scrub position. Position computed via `getPointAtLength()` on a ref'd `<path>` element.
   - N-arrow + scale bar in glass tiles at the corners
3. **Readout row** — colored difficulty icon tile + km value + elevation value + segment name + "near hazard" pill if within `0.4km` of any hazard.
4. **Elevation scrubber** (`120px` tall):
   - Difficulty bands as colored 6px strips at the bottom of the chart
   - Three reference grid lines + right-aligned `m` labels at `800/1200/1600`
   - Filled elevation area (`#ff6a2c` 0.55→0 vertical gradient)
   - Elevation polyline drawn on top
   - Hazard pips along the bottom edge of the chart at each hazard km
   - **Vertical scrub indicator** — dashed white line full-height + solid white line from top to elevation curve
   - **Floating elevation tag** above the cursor showing current elevation in meters (mono, bordered, ember-bordered)
   - **Thumb** — white circle 5/6.5px radius (grows on drag), 2px ember stroke, ember drop-shadow that intensifies on drag

**Drag behavior:**

```js
const setFromEvent = (e) => {
  const rect = elevRef.current.getBoundingClientRect();
  const cx = e.touches ? e.touches[0].clientX : e.clientX;
  const p = Math.max(0, Math.min(1, (cx - rect.left) / rect.width));
  setProgress(p);
};
```

Wire `onMouseDown/Move/Up/Leave` + `onTouchStart/Move/End`. In React Native, replace with `PanResponder` or `react-native-gesture-handler`'s `Pan`.

**Marker sync:**

```js
useEffect(() => {
  const L = mapPathRef.current.getTotalLength();
  const p = mapPathRef.current.getPointAtLength(progress * L);
  const pa = mapPathRef.current.getPointAtLength(Math.min(progress + 0.002, 1) * L);
  const angle = Math.atan2(pa.y - p.y, pa.x - p.x) * 180 / Math.PI;
  setMarker({ x: p.x, y: p.y, angle });
}, [progress]);
```

In `react-native-svg` you have `getPointAtLength` on `<Path>` refs too — same approach works. If not available natively, pre-sample the path into a dense array of `{x, y}` points and interpolate.

**Trail data shape (single source of truth — in `TRAIL` constant):**

```js
{
  name, region, totalKm, ascent, duration, difficulty, techGrade, rating, reports, base,
  elev: [[km, meters], ...],          // 28 samples
  segments: [{km0, km1, diff, name, body}, ...],   // 6 sections, diff ∈ {easy, mod, hard}
  hazards:  [{km, kind, label, desc}, ...],         // kind ∈ {water, shelter, danger, view, summit}
  mapPathD: '<svg path d>',           // the aerial-map trail line
  prep: { water, food, layers, safety, permit, startBy, turnAround, cellSignal },
}
```

Helpers: `elevAtKm(km)` (linear interp), `segmentAtKm(km)`.

---

## Headline Component: Achievement Hex Medallion

In `screens/profile.jsx` → `TopoMedallion`. Used at `size=56` in the grid and `size=96` in the LatestUnlock hero.

**Structure (everything in one 100×100 viewBox SVG, clipped to a pointy-top hex):**

1. Hex clip path: `M 50,4 L 92,27 L 92,73 L 50,96 L 8,73 L 8,27 Z`
2. Vertical gradient background
3. 5 horizontal `Q`-curve contour lines (faint ember tint when unlocked, white-on-dark when locked)
4. **Two radar/sonar ping rings** (unlocked only) expanding from the summit point — `r: 3→46` over 3.2s, opacity 0.7→0, offset by 1.5s
5. **Ember "magma" fill** (locked-with-progress only) — bottom-anchored rect at `y = 100 - progress*92`, filled with a vertical magma gradient, with a curvy glowing wavefront on top
6. Mountain silhouette (a single jagged `<path>`), darker fill when unlocked, slightly stroked
7. **Switchback trail** (unlocked only) — drawn from `(18, 82)` to `(70, 32)`:
   - Wide blurred under-glow (`stroke-width: 3.2`, filtered)
   - Bright dashed core stroke (`pathLength=1`, `stroke-dasharray='1 1'`, animates `stroke-dashoffset 1→0` over 2.6s, looping)
   - A tracer dot riding the path via `<animateMotion>`
8. **Summit pin** at `(70, 32)` — radial-gradient circle that pulses `r: 4→8→4` over 2s + a bright center dot
9. Four small reticle corner brackets at hex corners
10. Hex outline stroke (last so it's on top)
11. **Icon overlay** — DOM element positioned absolutely at hex center (54% top), tiny puck with the achievement icon, rarity-tinted glow shadow
12. **Lock chip** (locked only) — small padlock icon in a bordered circle at bottom-right corner
13. **Drifting embers** (hero only) — 4 absolutely positioned dots above the medallion animating `transform: translate()` upward + fading

**Rarity scale:**

```js
const RARITY = {
  common:    { label:'COMMON',    ring:'#7a8390', fill:'#98a1ac', glow:'rgba(152,161,172,0.55)' },
  rare:      { label:'RARE',      ring:'#5aa1d6', fill:'#7fbceb', glow:'rgba(90,161,214,0.55)'  },
  epic:      { label:'EPIC',      ring:'#ff6a2c', fill:'#ff8a4d', glow:'rgba(255,106,44,0.75)'  },
  legendary: { label:'LEGENDARY', ring:'#f2a93b', fill:'#ffd07a', glow:'rgba(242,169,59,0.85)'  },
};
```

---

## Snow Easter Egg

The Home hero swaps to a snowed-in mountain image when the Drakensberg forecast contains snow above 1,800m. Production behavior:

1. The forecast service is polled periodically.
2. If any of the next 7 days has `snowfall > 0` at the typical hiking altitude, set a global "snow predicted" flag.
3. `HomeHero` reads that flag and swaps:
   - **Image**: `assets/hero_mountain.png` → `assets/hero_snow.png`
   - **Filter**: `saturate(0.92) contrast(1.04)` for the snow shot (it's already brighter, doesn't need punch)
   - **Object position**: `center 50%` instead of `center 58%` (the snow shot composes differently)
4. Animated accents adjust:
   - Trail path is retraced as a diagonal switchback from upper-right peak to lower-left (matches the snow image's burned trail)
   - Comet, embers, and summit halo follow the new path
   - Ember count drops to 6 and opacity to 0.7 (cooler vibe in snow)
5. A `<SnowfallOverlay>` renders 36 SVG circles drifting downward at randomized speeds — `mix-blend-mode: screen` so they blend with the dark sky
6. A small ember-bordered tag `❄ SNOW · DRAKENSBERG · UP TO 14CM` appears at top-left of the hero

The current prototype uses a global hook `useTT()` defined in `screens/shared.jsx`. In production, source the flag from your forecast service.

---

## Animations & Motion

All animations in this design are either:

| Pattern | Duration | Easing | Used for |
|---|---|---|---|
| Fade up | 600–700ms | `cubic-bezier(0.2, 0.7, 0.2, 1)` | Card entry, section reveal |
| Fade in | 600ms | `ease` | Image swap, simple appear |
| Pop (scale) | 650ms | `cubic-bezier(0.2, 0.7, 0.2, 1)` | Avatars, markers, badges |
| Draw line | 1800ms | `cubic-bezier(0.6, 0.2, 0.2, 1)` | Trail paths, elevation lines |
| Pulse | 1.4–1.6s | `infinite ease-in-out` | Status dots (online, ember, red) |
| Ring ripple | 3s | `infinite ease-out` | SOS button, position markers |
| Shimmer | 4s | `infinite linear` | Primary CTA highlight |
| Float | 4s | `infinite ease-in-out` | Floating FAB |
| Ambient | 14s | `infinite alternate ease-in-out` | Hero background drift |
| Compass radar | 4.2s | `infinite linear` | Compass dial sweep |
| Snow drift | 4–9s | `infinite linear` (randomized per flake) | Snow overlay |

Use **stagger entry**: most lists wrap children in `<Stagger base={300} delay={70}>` which adds an incrementing `animation-delay` to each child (see `screens/shared.jsx`). Recreate this as a simple `Children.map`-based component or hand-roll with index-based delays.

---

## State Management

Per-screen state is minimal — most screens are stateless except:

| Screen | State |
|---|---|
| Home | None (reads `useTT().snow` from global) |
| Tools | `tool` selected (`'compass' | 'level' | 'torch' | 'altitude' | 'sun' | 'info'`) |
| Community | `tab` (`0 | 1` for Feed/Chat) |
| Stats | `tab` (`0 | 1` for My Hikes/Overall) |
| Trails | `sort`, `diffFilter` |
| Trail Detail | `progress` (0..1), `dragging` |
| Notifications | `filter` (kind) |
| History | `filter` (difficulty) |
| Achievements | `tab` (`all | unlocked | locked`) |
| Plan Route | (multiple field-level useStates) |
| Sign In | `mode` (`signin | signup`) |
| Forecast | `pick` (day index) |
| Search | `q`, `scope` |
| Toggles throughout | local `on` boolean per row |

**Global state needed at app level:**

1. **Current user** — name, avatar, region, experience level, interests, paired devices, emergency contacts
2. **Active hike** — if currently recording, the live trail, tether watchers, last ping time
3. **Team membership** — current team(s), live positions, recent chat
4. **Forecast** — 7-day per region, drives the snow easter egg
5. **Notifications feed**
6. **Offline-map cache** — list of downloaded regions
7. **Achievements progress**

Recommend Redux Toolkit or Zustand for this. The "tether" connection is realtime — use a WebSocket service for live team positions and tether ping ack.

---

## Assets

| File | Where it's used | Notes |
|---|---|---|
| `assets/logo.png` | Status bar, app bars, sign-in hero, profile | The Trailtether pin-with-mountain mark. 64×64+. Has built-in subtle drop shadow. |
| `assets/logo_fg.png` | Available, currently unused | Same mark, transparent foreground only |
| `assets/hero_mountain.png` | Home hero (default) | Hyper-real night mountain with ember switchback trail burned in. 1024×497 — provide 2x and 3x for mobile. |
| `assets/hero_snow.png` | Home hero (snow easter egg) | Snowed-in mountain panorama with ember trail + topo line overlay. Same idea but daytime/winter. Provide 2x and 3x for mobile. |
| `assets/feature_graphic.png` | Store listing | Play Store feature graphic, not used in app |

**Both hero images need 2x/3x mobile-density variants** for Retina/HDPI displays. Consider pre-darkening and pre-blurring the lower 30% to bake in the legibility gradient if you don't want to overlay it at runtime.

**No other raster assets** — every UI element including the entire compass, weather icons, mountain silhouettes, aerial maps, and hazard glyphs is rendered as inline SVG.

---

## Files Reference

```
design_source/
├── index.html                  # Master file — design tokens, design canvas mount, Tweaks panel
├── design-canvas.jsx           # The pan/zoom artboard wrapper — NOT for production
├── tweaks-panel.jsx            # Editor tooling — NOT for production
├── assets/
│   ├── logo.png
│   ├── logo_fg.png
│   ├── hero_mountain.png       # default Home hero
│   ├── hero_snow.png           # snow easter-egg Home hero
│   └── feature_graphic.png
└── screens/
    ├── shared.jsx              # Status bar, bottom nav, icon set, layout primitives, useTT() hook
    ├── welcome.jsx
    ├── sign-in.jsx
    ├── home.jsx
    ├── maps.jsx
    ├── tools.jsx
    ├── community.jsx
    ├── team.jsx
    ├── profile.jsx
    ├── trails.jsx
    ├── trail-detail.jsx        # Includes the InteractiveTrailExplorer
    ├── plan-route.jsx
    ├── stats.jsx
    ├── history.jsx
    ├── achievements.jsx
    ├── forecast.jsx
    ├── safety.jsx
    ├── sos.jsx
    ├── notifications.jsx
    ├── search.jsx
    ├── edit-profile.jsx
    └── settings.jsx
```

**To preview the design** on a machine that doesn't have a bundler:

1. From `design_source/`, run any static file server (e.g. `python3 -m http.server 8080`)
2. Open `http://localhost:8080/index.html`
3. The 21 screens render on a pan/zoom canvas. Scroll to zoom, drag to pan. Click an artboard label to focus it.
4. The toolbar "Tweaks" toggle in the top-right opens the snow easter-egg control.

---

## Implementation Order Suggestion

To stand up the app quickly, build in this order:

1. **Design tokens** — Port the color/type/spacing/radius/shadow tokens into the target codebase's theme system first. Everything else depends on them.
2. **Icon component + icon set** — Get the `<Icon>` switch working with all ~45 SVG paths.
3. **App shell** — Status bar, app bar, bottom nav, the 6 main tab routes.
4. **Card / pill / segmented primitives** — Everything in the rest of the app uses these.
5. **Home** — Easiest screen, gives you the visual foundation early.
6. **Profile + Achievements (hex medallion)** — Achievement medallion is reusable and high-impact.
7. **Trails list + Trail Detail (interactive explorer)** — The headline flow.
8. **The other tabs** — Map, Tools, Community, Teams.
9. **Safety + SOS** — Functional core but visually simpler.
10. **All utility screens** — Settings, Notifications, Search, Edit Profile, etc.

Keep the snow easter egg until the forecast service is real — wire it last.
