// Trailtether — design tokens.
//
// 1:1 mirror of the CSS custom properties at the top of the design handoff's
// `design_source/index.html`. The web prototype declares them on `:root`;
// here they live as a typed `tt` object so every screen + component imports
// from a single source of truth.
//
// Color-usage rules from the handoff README:
//   - Ember orange (`tt.ember`) is the ONLY brand accent.
//   - Semantic colors (blue/green/amber/red) are for state only.
//   - Difficulty grades use the fixed scale exported as `difficultyColor()`.
//   - Achievement rarities use `rarityColor()`.
//   - No emoji except the tiny weather-card glyphs.
//   - No gradients except the ember-on-ember CTA + the elevation chart fill.

export const tt = {
  // ── Backgrounds (graphite stack, bottom → top of UI hierarchy) ─────
  bg: '#07090c',
  bg2: '#0b0e12',
  bg3: '#0f1318',

  // ── Surfaces (cards, rows, buttons) ────────────────────────────────
  surf: '#131820',
  surf2: '#1a2029',
  surf3: '#232a35',

  // ── Lines (borders, dividers) — alpha on white ─────────────────────
  // Stored as rgba strings because RN's StyleSheet accepts them directly.
  line: 'rgba(255,255,255,0.055)',
  line2: 'rgba(255,255,255,0.10)',
  line3: 'rgba(255,255,255,0.16)',

  // ── Text ───────────────────────────────────────────────────────────
  text: '#eef1f4',
  text2: '#98a1ac',
  text3: '#5a6470',
  text4: '#3d454d',

  // ── Brand — burnt ember (the singular accent) ──────────────────────
  ember: '#ff6a2c',
  ember2: '#ff8a4d',
  ember3: '#ffb486',
  emberDim: 'rgba(255,106,44,0.14)',
  emberSoft: 'rgba(255,106,44,0.06)',

  // ── Semantic state colours ─────────────────────────────────────────
  blue: '#5aa1d6',
  green: '#4cc38a',
  amber: '#f2a93b',
  red: '#e63d2e',
} as const;

// ── Typography ─────────────────────────────────────────────────────────
//
// Two fonts only. Manrope handles all UI text; JetBrains Mono is the
// "tactical readout" font used for numbers, ALL-CAPS micro-labels, badges
// and timestamps (always with letter-spacing 0.06–0.18em).
export const font = {
  ui: 'Manrope_400Regular',
  uiMed: 'Manrope_500Medium',
  uiSemi: 'Manrope_600SemiBold',
  uiBold: 'Manrope_700Bold',
  uiHeavy: 'Manrope_800ExtraBold',
  // Manrope tops out at 800; weight 900 in the handoff uses Manrope
  // ExtraBold in practice (Google Fonts doesn't ship a 900 cut).
  mono: 'JetBrainsMono_400Regular',
  monoMed: 'JetBrainsMono_500Medium',
  monoSemi: 'JetBrainsMono_600SemiBold',
  monoBold: 'JetBrainsMono_700Bold',
} as const;

// Type-size scale used across the design (in px, RN treats these as
// density-independent pixels which matches what the web designs expect).
export const fz = {
  micro: 9,    // micro-labels, badge text low end
  micro2: 10,
  caption: 11, // body small
  body: 12,    // body
  body2: 13,   // body emphasised
  rowTitle: 14,
  cardTitle: 16,
  sectionTitle: 18,
  screenTitle: 22,
  hero: 28,    // "John D.", "Welcome back."
  hero2: 32,
  heroNum: 44, // altitude, temperature
  heroNum2: 56,
} as const;

// Letter spacing presets — the handoff calls these out by name. Mono text
// gets a "tactical" spacing; UI uppercase eyebrows get a tighter version.
export const ls = {
  tight: -0.015,    // h1
  normal: 0,
  monoTight: 0.06,
  monoMed: 0.1,
  monoWide: 0.16,
} as const;

// ── Spacing scale ──────────────────────────────────────────────────────
// Per the handoff: no strict 4/8 grid — used values are these. Screens
// pad to 18 outside, cards pad 12–16 vertical / 14–16 horizontal.
export const sp = {
  s1: 4,
  s2: 6,
  s3: 8,
  s4: 10,
  s5: 12,
  s6: 14,
  s7: 16,
  s8: 18,
  s9: 22,
  s10: 24,
  s11: 28,
  // Named conveniences for the most-used values:
  screen: 18,
  card: 16,
} as const;

// ── Radius scale ───────────────────────────────────────────────────────
export const radius = {
  sm: 8,    // small chips, pills
  md: 12,   // input fields, icon buttons
  lg: 16,   // cards
  xl: 22,   // hero containers, large bottom sheets
  pill: 999,
} as const;

// ── Shadow presets ─────────────────────────────────────────────────────
// Web shadows port awkwardly to RN — `elevation` is android-only and
// shadowColor/shadowOffset/shadowOpacity/shadowRadius are iOS-only — but
// we provide style objects you can spread into a View.
export const shadow = {
  card: {
    // Approximation of `0 8px 24px -12px rgba(0,0,0,0.6)`.
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 4,
  },
  ember: {
    // `0 10px 30px -8px rgba(255,106,44,0.45)` — reserved for the primary
    // CTA and active brand elements only.
    shadowColor: tt.ember,
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.45,
    shadowRadius: 16,
    elevation: 8,
  },
} as const;

// ── Animation durations / easings ──────────────────────────────────────
// All animation values from the handoff's Motion table. Keep timings
// short and easings consistent so the app feels coherent.
export const motion = {
  fast: 180,
  med: 280,
  slow: 600,
  drawLine: 1800,
  pulse: 1500,
  ringRipple: 3000,
  shimmer: 4000,
  ambient: 14000,
  compassRadar: 4200,
  // Standard easing tuples for RN Reanimated `Easing.bezier(...)`.
  easeOut: [0.2, 0.7, 0.2, 1] as const,
  drawLineEase: [0.6, 0.2, 0.2, 1] as const,
} as const;

// ── Helpers ────────────────────────────────────────────────────────────
// Lookup tables for the two fixed scales called out in the README.

export type Difficulty = 'easy' | 'moderate' | 'difficult' | 'technical';

export function difficultyColor(d: Difficulty): string {
  switch (d) {
    case 'easy':
      return tt.green;
    case 'moderate':
      return tt.amber;
    case 'difficult':
      return tt.ember;
    case 'technical':
      return tt.red;
  }
}

export type Rarity = 'common' | 'rare' | 'epic' | 'legendary';

export interface RaritySpec {
  label: string;
  ring: string;
  fill: string;
  glow: string;
}

export const rarity: Record<Rarity, RaritySpec> = {
  common: {
    label: 'COMMON',
    ring: '#7a8390',
    fill: '#98a1ac',
    glow: 'rgba(152,161,172,0.55)',
  },
  rare: {
    label: 'RARE',
    ring: tt.blue,
    fill: '#7fbceb',
    glow: 'rgba(90,161,214,0.55)',
  },
  epic: {
    label: 'EPIC',
    ring: tt.ember,
    fill: tt.ember2,
    glow: 'rgba(255,106,44,0.75)',
  },
  legendary: {
    label: 'LEGENDARY',
    ring: tt.amber,
    fill: '#ffd07a',
    glow: 'rgba(242,169,59,0.85)',
  },
};

export function rarityColor(r: Rarity): RaritySpec {
  return rarity[r];
}
