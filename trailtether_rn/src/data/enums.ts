// Trailtether — canonical UI enums + translators.
//
// The design prototype uses several short enum strings inconsistently
// (`'mod' | 'hard' | 'xhard'` on trails, `'easy' | 'mod' | 'hard'` on
// segments, etc.). This module declares the canonical enum once, then
// gives a `normalize*()` function for every place the inbound string
// might be sloppy.
//
// Canonical scales are intentionally aligned with `theme/tokens.ts` so
// difficulty / rarity colours pick up directly from `difficultyColor()`
// and `rarityColor()`.

import type { Difficulty, Rarity } from '@theme/tokens';
export type { Difficulty, Rarity } from '@theme/tokens';

// ── Hazard kinds on trails ────────────────────────────────────────────
// Five points-of-interest the Trail Detail aerial map renders as
// coloured pips. Matches `HAZARD_META` in trail-detail.jsx.
export type TrailHazardKind =
  | 'water'     // stream / refill
  | 'shelter'   // cave or hut
  | 'danger'    // scramble, scree, fall risk
  | 'view'      // photo spot
  | 'summit';   // peak

// Risk pill on SOS NearbyHazard rows ('LOW RISK', 'MODERATE RISK', etc).
export type Risk = 'low' | 'moderate' | 'high' | 'info';

// Notification kinds (from notifications.jsx filter chips + NOTIFS array).
export type NotificationKind =
  | 'weather'
  | 'hazard'
  | 'team'
  | 'mention'
  | 'achievement'
  | 'system'
  | 'review';

// Editable Profile experience radio.
export type ExperienceLevel =
  | 'beginner'
  | 'intermediate'
  | 'advanced'
  | 'expert';

// SOS responder lifecycle.
export type ResponderStatus = 'en route' | 'on scene' | 'cleared';

// SOS timeline event state.
export type TimelineStatus = 'done' | 'active' | 'pending';

// Plan Route waypoint markers.
export type WaypointType = 'start' | 'poi' | 'shelter' | 'end';

// Feed-post attachment variants.
export type PostAttachmentKind = 'elev' | 'gpx' | null;

// Weather icon bucket (sun / cloud / rain) derived from WMO code.
export type WeatherIconKind = 'sun' | 'cloud' | 'rain';

// EmergencyContact type → drives the icon + accent (red MSAR, amber
// ambulance, ember personal).
export type EmergencyContactType = 'rescue' | 'ambulance' | 'personal';

// ── Translators ───────────────────────────────────────────────────────

/**
 * Normalize any difficulty string the upstream data uses (Flutter JSON
 * uses `'Easy' | 'Moderate' | 'Hard' | 'Extreme'`, design source uses
 * `'easy' | 'mod' | 'hard' | 'xhard'`) into the canonical four-level
 * scale declared in tokens.ts.
 */
export function normalizeDifficulty(raw: unknown): Difficulty {
  const s = String(raw ?? '').toLowerCase().trim();
  switch (s) {
    case 'easy':
      return 'easy';
    case 'mod':
    case 'moderate':
      return 'moderate';
    case 'hard':
    case 'diff':
    case 'difficult':
      return 'difficult';
    case 'xhard':
    case 'tech':
    case 'technical':
    case 'extreme':
      return 'technical';
    default:
      return 'moderate';
  }
}

/** Normalise rarity strings into the canonical four-level scale. */
export function normalizeRarity(raw: unknown): Rarity {
  const s = String(raw ?? '').toLowerCase().trim();
  if (s === 'rare' || s === 'epic' || s === 'legendary' || s === 'common') {
    return s;
  }
  return 'common';
}

/** WMO weather code → `sun | cloud | rain` icon bucket. */
export function weatherIconKind(code: number): WeatherIconKind {
  if (code <= 1) return 'sun';
  if (code <= 48) return 'cloud';
  return 'rain';
}

/** IncidentRow.severity (low/med/high) → SOS NearbyHazard.risk. */
export function normalizeRisk(raw: unknown): Risk {
  const s = String(raw ?? '').toLowerCase().trim();
  if (s === 'low' || s === 'info') return s;
  if (s === 'med' || s === 'moderate' || s === 'medium') return 'moderate';
  if (s === 'high' || s === 'critical' || s === 'severe') return 'high';
  return 'info';
}

/**
 * Map IncidentRow.type (rockfall / weather / water / shelter / sos / …)
 * into the design's five-bucket TrailHazardKind. Unknown / SOS types
 * fall through to 'danger'.
 */
export function normalizeHazardKind(raw: unknown): TrailHazardKind {
  const s = String(raw ?? '').toLowerCase().trim();
  if (s === 'water') return 'water';
  if (s === 'shelter' || s === 'cave' || s === 'cabin') return 'shelter';
  if (s === 'view' || s === 'viewpoint') return 'view';
  if (s === 'summit' || s === 'peak') return 'summit';
  return 'danger';
}

/** Free-form notification kind string → canonical enum. */
export function normalizeNotificationKind(raw: unknown): NotificationKind {
  const s = String(raw ?? '').toLowerCase().trim();
  switch (s) {
    case 'weather':
    case 'hazard':
    case 'team':
    case 'mention':
    case 'achievement':
    case 'review':
      return s;
    default:
      return 'system';
  }
}
