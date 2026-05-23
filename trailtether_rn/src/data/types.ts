// Trailtether — UI domain types.
//
// Every entity surfaced in the design source as a TypeScript interface.
// camelCase, idiomatic for TS, decoupled from the Supabase row shapes
// in `schema.ts`. Adapters in `adapters.ts` translate between the two.
//
// Approved via TYPES_DIFF.md. Future shape changes go through the same
// diff document so reviewers can see the delta against the design.

import type { IconName } from '@components/Icon';
import type {
  Difficulty,
  EmergencyContactType,
  ExperienceLevel,
  NotificationKind,
  PostAttachmentKind,
  Rarity,
  ResponderStatus,
  Risk,
  TimelineStatus,
  TrailHazardKind,
  WaypointType,
  WeatherIconKind,
} from './enums';

// ─────────────────────────────── Trail ──────────────────────────────────

/** Single GPS sample on a trail's recorded line. */
export interface TrailCoord {
  lat: number;
  lon: number;
  /** Metres above sea level; 0 when source had no elevation. */
  elev: number;
}

/** One point on the trail's elevation profile, indexed by cumulative km. */
export interface ElevationPoint {
  km: number;
  metres: number;
}

/** Section of a trail with a uniform difficulty band. */
export interface TrailSegment {
  km0: number;
  km1: number;
  diff: Difficulty;
  name: string;
  body: string;
}

/** Point of interest or hazard along a trail. */
export interface TrailHazard {
  km: number;
  kind: TrailHazardKind;
  label: string;
  desc: string;
}

/** Free-form prep checklist shown on Trail Detail. */
export interface TrailPrep {
  water: string;
  food: string;
  layers: string;
  safety: string;
  permit: string;
  startBy: string;
  turnAround: string;
  cellSignal: string;
}

/**
 * Trail bundled in the asset catalog. 239 of these ship in
 * `assets/data/routes_cleaned.json`.
 */
export interface Trail {
  id: string;
  name: string;
  region: string;
  /** Total length in kilometres. */
  distanceKm: number;
  /** Total elevation gain in metres. */
  ascentM: number;
  /** Total elevation loss in metres. */
  descentM: number;
  /** Base / trailhead elevation in metres. */
  baseM: number;
  /** Canonical four-level difficulty. */
  difficulty: Difficulty;
  /** Estimated time in hours (decimal — `5.5` → "5–6 hrs" via formatter). */
  estTimeHours: number;
  /** Down-sampled elevation profile suitable for the design's chart (~28 samples). */
  elev: ElevationPoint[];
  /** Full raw polyline used for map rendering. */
  coords: TrailCoord[];
  /** Pre-computed bounding box (used for `fitCamera` and proximity hit tests). */
  bbox: { minLat: number; maxLat: number; minLon: number; maxLon: number };
  /** Human description (may be empty). */
  description: string;
}

/**
 * Server-side extras that DON'T ship in the bundle — pending the
 * `v_trail_metadata` view in BLOCKERS.md #10. Loaded lazily on the
 * Trail Detail screen; until the view exists `useTrailExtras()` returns
 * an error pointing at the blocker.
 */
export interface TrailExtras {
  trailId: string;
  techGrade: string;           // 'Class 3'
  rating: number;              // 0..5
  reportsCount: number;
  segments: TrailSegment[];
  hazards: TrailHazard[];
  prep: TrailPrep;
}

/** Lean shape rendered by the Trails-list card. */
export interface TrailListItem {
  id: string;
  name: string;
  region: string;
  difficulty: Difficulty;
  distanceKm: number;
  ascentM: number;
  /** Pre-formatted hours range string like '5–7'. */
  hoursLabel: string;
  /** 0..5 stars from the reviews view (null until BLOCKERS.md #10 ships). */
  rating: number | null;
  /** Count of community reports (null until #10 ships). */
  reportsCount: number | null;
  /** Optional badges like 'FEATURED', 'CAVES', 'PERMIT' (null until #10 ships). */
  tags: string[] | null;
  /** Hikers currently on this trail (null until BLOCKERS.md #10 view). */
  liveCount: number | null;
}

// ─────────────────────────────── Hike ───────────────────────────────────

export interface HikeRecord {
  id: string;
  name: string;
  createdAt: Date;
  distanceKm: number;
  ascentM: number;
  durationSeconds: number;
  /** A..F letter grade (null until BLOCKERS.md #11 ships). */
  score: 'A' | 'B' | 'C' | 'D' | 'F' | null;
  /** Difficulty inherited from the linked trail (null when free recording). */
  difficulty: Difficulty | null;
  /** Region inherited from the linked trail (null when free recording). */
  region: string | null;
}

// ─────────────────────────── Achievement ────────────────────────────────

export interface Achievement {
  id: string;
  icon: IconName;
  label: string;
  /** One-line description shown below the medallion. */
  sub: string;
  rarity: Rarity;
  /** 0..1, where 1 = unlocked. */
  progress: number;
  unlocked: boolean;
  /** Pre-formatted date string like 'OCT 24' (null when not earned). */
  earnedLabel: string | null;
  /** Longer prose shown on the LatestUnlock hero only. */
  desc?: string;
}

// ───────────────────────────── Forecast ─────────────────────────────────

export interface ForecastDay {
  /** 'TODAY' | 'MON' | 'TUE' | … */
  dayLabel: string;
  /** 'OCT 27' pre-formatted. */
  dateLabel: string;
  /** Underlying ISO date. */
  date: Date;
  icon: WeatherIconKind;
  hiC: number;
  loC: number;
  windKmh: number;
  /** 0..10 hike score (drier + calmer = higher). */
  hikeScore: number;
  /** Bucketed prose label like 'Perfect window' / 'Avoid summit'. */
  hikeLabel: string;
}

export interface ForecastHour {
  time: Date;
  tempC: number;
  weatherCode: number;
  precipProb: number;
  windKmh: number;
}

export interface ForecastAlert {
  id: string;
  severity: 'amber' | 'red';
  iconName: IconName;
  title: string;
  sub: string;
}

export interface ForecastDetailTile {
  iconName: IconName;
  label: string;
  /** Pre-formatted value like '18' or '05:47'. */
  value: string;
  unit?: string;
  sub: string;
}

// ─────────────────────────── Notification ───────────────────────────────

export interface Notification {
  id: string;
  kind: NotificationKind;
  urgent: boolean;
  /** Pre-formatted relative time like '2m ago'. */
  timeLabel: string;
  receivedAt: Date;
  title: string;
  sub: string;
  /** CTA label like 'View forecast'. */
  action: string;
  read: boolean;
}

// ─────────────────────────── Feed / Chat ────────────────────────────────

export interface FeedPostStats {
  distLabel: string;     // '8.4 km'
  gainLabel: string;     // '+3,950 m'
  timeLabel: string;     // '5:42'
}

export interface FeedPostAttachment {
  kind: PostAttachmentKind;
  /** When kind === 'elev', a small array of elevations for the inline chart. */
  samples?: number[];
  /** When kind === 'gpx'. */
  filename?: string;
  waypoints?: number;
  bytes?: number;
}

export interface FeedAuthor {
  id: string;
  name: string;
  initials: string;
  /** Hex accent for the gradient avatar. */
  color: string;
}

export interface FeedPost {
  id: string;
  author: FeedAuthor;
  /** Pre-formatted relative time like '14m ago'. */
  timeLabel: string;
  postedAt: Date;
  location: string;
  text: string;
  stats?: FeedPostStats;
  likes: number;
  comments: number;
  hazard: boolean;
  attachment: FeedPostAttachment | null;
}

export interface ChatSender {
  id: string;
  name: string;
  initials: string;
  color: string;
}

export interface ChatMessage {
  id: string;
  sentAt: Date;
  /** Pre-formatted 'HH:mm'. */
  timeLabel: string;
  sender: ChatSender;
  /** True when sender.id === current user id. */
  mine: boolean;
  text: string;
  /** Optional emoji reaction. */
  reaction?: string;
  roomId: string;
}

// ───────────────────────── Team & live tracking ─────────────────────────

export interface TeamMemberLive {
  uid: string;
  name: string;
  initials: string;
  color: string;
  /**
   * Named place (e.g. 'Sunrise Camp') from reverse geocoding. Falls back
   * to `${distanceKm} km` while BLOCKERS.md #20 is pending.
   */
  locationLabel: string;
  distanceKm: number | null;
  altitudeM: number;
  speedKmh: number;
  batteryPct: number | null;
  connectivity: 'wifi' | 'mobile' | 'none' | null;
  lead: boolean;
  alert: boolean;
  lastSeen: Date;
  lat: number;
  lon: number;
}

// ───────────────────────── Safety + emergency ───────────────────────────

export interface GearChecklistItem {
  id: string;
  label: string;
  sub: string;
  done: boolean;
}

export interface ActiveSafetyPlan {
  id: string;
  trailName: string;
  trailId: string | null;
  expectedReturn: Date;
  backpack: string;
  tent: string | null;
  watcherCount: number;
  lastPing: Date | null;
  gear: GearChecklistItem[];
}

export interface EmergencyContact {
  id: string;
  name: string;
  sub: string;
  phone: string;
  type: EmergencyContactType;
}

// ──────────────────────────────── SOS ───────────────────────────────────

export interface NearbyHazard {
  id: string;
  iconName: IconName;
  title: string;
  sub: string;
  risk: Risk;
  reportedAt: Date;
  /** Pre-formatted 'HH:mm'. */
  timeLabel: string;
}

export interface IncidentTimelineEvent {
  at: Date;
  /** Pre-formatted 'HH:mm'. */
  timeLabel: string;
  label: string;
  status: TimelineStatus;
}

export interface SOSResponder {
  name: string;
  status: ResponderStatus;
  etaMinutes: number;
  distanceMetres: number;
  /** 0..4 bars. */
  signalBars: number;
}

export interface SOSIncident {
  id: string;
  /** 'BEACON ALPHA-7' — pending BLOCKERS.md #17. */
  beacon: string | null;
  startedAt: Date;
  lat: number;
  lon: number;
  altitudeM: number;
  accuracyM: number;
  responder: SOSResponder | null;
  nearbyHazards: NearbyHazard[];
  timeline: IncidentTimelineEvent[];
}

// ─────────────────────────── Plan a route ───────────────────────────────

export interface Waypoint {
  /** Sortable label (A/1/2/…). */
  num: string;
  type: WaypointType;
  name: string;
  sub: string;
  km: number;
}

export interface RoutePlan {
  id: string | null;
  name: string;
  date: Date;
  /** 'HH:mm' start time. */
  startTimeLabel: string;
  waypoints: Waypoint[];
  tetherWatcherId: string | null;
  totalKm: number;
  ascentM: number;
  durationMinutes: number;
}

// ─────────────────────────────── Search ─────────────────────────────────

export type SearchResult =
  | { kind: 'trail'; id: string; name: string; region: string; distanceKm: number; difficulty: Difficulty }
  | { kind: 'person'; id: string; name: string; sub: string; initials: string; color: string }
  | { kind: 'cave'; id: string; name: string; km: number; capacity: string }
  | { kind: 'report'; id: string; title: string; who: string; reportedAt: Date; timeLabel: string };

// ─────────────────────────────── Profile ────────────────────────────────

export interface ProfileBadge {
  label: string;
  color: 'amber' | 'ember';
}

export interface ProfileHeaderData {
  displayName: string;
  email: string | null;
  initials: string;
  photoUrl: string | null;
  bio: string;
  badges: ProfileBadge[];
}

export interface ProfileStat {
  label: string;
  value: string;
  unit?: string;
  iconName: IconName;
  ember?: boolean;
}

export interface EditableProfile {
  fullName: string;
  username: string;
  email: string;
  region: string;
  bio: string;
  experienceLevel: ExperienceLevel;
  interests: string[];
}

// ─────────────────────────── Welcome + Settings ─────────────────────────

export interface WelcomeFeature {
  id: 'tether' | 'plan' | 'navigate' | 'aware' | 'sos';
  eyebrow: string;
  title: string;
  body: string;
  color: string;
}

export interface SettingsBadge {
  label: string;
  color: string;
}

export type SettingsRow =
  | { kind: 'value'; iconName: IconName; label: string; value: string; href?: string; badge?: SettingsBadge }
  | { kind: 'toggle'; iconName: IconName; label: string; storageKey: string; defaultOn: boolean }
  | { kind: 'link'; iconName: IconName; label: string; href: string };

export interface SettingsGroup {
  title: string;
  rows: SettingsRow[];
}
