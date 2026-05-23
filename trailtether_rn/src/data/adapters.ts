// Trailtether — row → domain adapters.
//
// Every adapter takes a raw Supabase row (or bundled asset JSON object)
// and returns the camelCase UI domain type from `types.ts`. Adapters are
// the only place where snake_case ↔ camelCase translation lives — the
// UI never reads a row directly.
//
// Each adapter is defensive: missing / null / wrong-typed fields fall
// back to a safe default rather than throwing, so a single bad row from
// Supabase can't take down the screen.

import type {
  EmergencyContactRow,
  HikeHistoryRow,
  IncidentEventRow,
  IncidentRow,
  NotificationRow,
  PostRow,
  ProfileRow,
  RoutePlanRow,
  RouteWaypointRow,
  SafetyPlanRow,
  TeamMemberLocationRow,
  TrailMetadataRow,
  TrailMetadataViewRow,
} from './schema';
import {
  normalizeDifficulty,
  normalizeHazardKind,
  normalizeNotificationKind,
  normalizeRisk,
  weatherIconKind,
  type Difficulty,
  type TimelineStatus,
} from './enums';
import { nearestShelter } from './shelters';
import type {
  ActiveSafetyPlan,
  ChatMessage,
  ChatSender,
  EmergencyContact,
  FeedAuthor,
  FeedPost,
  FeedPostAttachment,
  FeedPostStats,
  ForecastDay,
  GearChecklistItem,
  HikeRecord,
  IncidentTimelineEvent,
  NearbyHazard,
  Notification,
  ProfileBadge,
  ProfileHeaderData,
  ProfileStat,
  RoutePlan,
  TeamMemberLive,
  Trail,
  TrailCoord,
  TrailExtras,
  TrailHazard,
  TrailPrep,
  TrailSegment,
  ElevationPoint,
  TrailListItem,
  Waypoint,
} from './types';
import type { IconName } from '@components/Icon';

// ────────────────────────────── helpers ──────────────────────────────

const HOUR_MS = 3_600_000;
const DAY_MS = 86_400_000;

function num(v: unknown, fallback = 0): number {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string') {
    const p = Number(v);
    return Number.isFinite(p) ? p : fallback;
  }
  return fallback;
}

function str(v: unknown, fallback = ''): string {
  if (typeof v === 'string') return v;
  if (v == null) return fallback;
  return String(v);
}

function asDate(v: unknown, fallback: Date = new Date()): Date {
  if (v instanceof Date) return v;
  if (typeof v === 'string' && v.length > 0) {
    const d = new Date(v);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return fallback;
}

export function initialsFromName(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) {
    const first = parts[0]!;
    return first.length >= 2 ? first.slice(0, 2).toUpperCase() : first[0]!.toUpperCase();
  }
  return (parts[0]![0]! + parts[parts.length - 1]![0]!).toUpperCase();
}

/**
 * Stable accent colour for a UID — used everywhere we need a per-user
 * gradient avatar without storing a colour on the user. Hashes the uid
 * into the design's avatar palette so the same person always renders
 * with the same accent.
 */
const AVATAR_PALETTE = [
  '#ff6a2c',
  '#ff8a4d',
  '#4cc38a',
  '#5aa1d6',
  '#f2a93b',
  '#e63d2e',
];
export function colorForUid(uid: string | null | undefined): string {
  if (!uid) return AVATAR_PALETTE[0]!;
  let hash = 0;
  for (let i = 0; i < uid.length; i++) {
    hash = ((hash << 5) - hash + uid.charCodeAt(i)) | 0;
  }
  return AVATAR_PALETTE[Math.abs(hash) % AVATAR_PALETTE.length]!;
}

/** Relative time like '2m ago', '14m ago', '3h ago', 'Yesterday', '2d ago'. */
export function relativeTimeLabel(at: Date, now: Date = new Date()): string {
  const diffMs = now.getTime() - at.getTime();
  if (diffMs < 0) return 'soon';
  const mins = Math.round(diffMs / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.round(diffMs / HOUR_MS);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(diffMs / DAY_MS);
  if (days === 1) return 'Yesterday';
  if (days < 30) return `${days}d ago`;
  // Fall back to a 'MMM DD' label for older items.
  return at
    .toLocaleDateString('en-US', { month: 'short', day: '2-digit' })
    .toUpperCase();
}

/** Pre-formatted 'OCT 27' style date label used across cards. */
export function shortDateLabel(at: Date): string {
  return at
    .toLocaleDateString('en-US', { month: 'short', day: '2-digit' })
    .toUpperCase();
}

/** Pre-formatted 'HH:mm' time-of-day label. */
export function timeOfDayLabel(at: Date): string {
  const h = at.getHours().toString().padStart(2, '0');
  const m = at.getMinutes().toString().padStart(2, '0');
  return `${h}:${m}`;
}

/** `5400` (sec) → `'1:30'` (h:mm). */
export function hoursMinutesLabel(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${h}:${m.toString().padStart(2, '0')}`;
}

/** `12345` → `'12,345'`. */
export function thousandsLabel(n: number): string {
  return Math.round(n).toLocaleString('en-US');
}

/** WMO weather code → short uppercase description for the conditions strip. */
export function describeWeatherCode(code: number): string {
  if (code === 0) return 'CLEAR SKY';
  if (code === 1) return 'MAINLY CLEAR';
  if (code === 2) return 'PARTLY CLOUDY';
  if (code === 3) return 'OVERCAST';
  if (code === 45 || code === 48) return 'FOG';
  if (code <= 55) return 'DRIZZLE';
  if (code <= 57) return 'FREEZING DRIZZLE';
  if (code <= 65) return 'RAIN';
  if (code <= 67) return 'FREEZING RAIN';
  if (code <= 77) return 'SNOW';
  if (code <= 82) return 'RAIN SHOWERS';
  if (code <= 86) return 'SNOW SHOWERS';
  if (code <= 99) return 'THUNDERSTORM';
  return 'UNKNOWN';
}

/** Mirrors the Flutter hike-score formula (drier + calmer = higher). */
export function computeHikeScore(windKmh: number, precipPct: number): number {
  const windPenalty = (Math.min(Math.max(windKmh - 10, 0), 50) / 50) * 4;
  const raw = (1 - precipPct / 100) * 10 - windPenalty;
  return Math.max(1, Math.min(10, Math.round(raw)));
}

/** Score (1..10) → prose label for the day card. */
export function hikeScoreLabel(score: number): string {
  if (score >= 9) return 'Perfect window';
  if (score >= 7) return 'Good window';
  if (score >= 5) return 'Caution';
  if (score >= 3) return 'Stay low';
  return 'Avoid summit';
}

// ────────────────────────────── Profile ──────────────────────────────

export function profileHeaderFromRow(
  row: ProfileRow | null,
  fallbackEmail: string | null,
): ProfileHeaderData {
  const display = (row?.display_name ?? '').trim();
  const email = (row?.email ?? fallbackEmail ?? '').trim();
  const name = display.length > 0
    ? display
    : email.includes('@')
      ? email.split('@')[0]!
      : 'Hiker';
  const badges: ProfileBadge[] = [];
  if (row?.is_admin) badges.push({ label: 'ADMIN', color: 'ember' });
  return {
    displayName: name,
    email: email.length > 0 ? email : null,
    initials: initialsFromName(name),
    photoUrl: row?.photo_url ?? null,
    bio: '', // pending BLOCKERS.md #19
    badges,
  };
}

// ──────────────────────────── HikeRecord ─────────────────────────────

export function hikeRecordFromRow(row: HikeHistoryRow): HikeRecord {
  return {
    id: row.id,
    name: str(row.name, 'Recorded hike').trim() || 'Recorded hike',
    createdAt: asDate(row.created_at),
    distanceKm: num(row.distance_km),
    ascentM: num(row.ascent_m),
    durationSeconds: num(row.duration_seconds),
    score: null,        // BLOCKERS.md #11
    difficulty: null,   // derived from linked trail; null when free recording
    region: null,
  };
}

// ─────────────────────── Bundled trail asset row ─────────────────────
//
// Shape lives in `assets/data/routes_cleaned.json` (copied from the
// Flutter app per BLOCKERS.md #9). Defensive parsing because the asset
// has mixed-type fields (some rows missing `profile`, etc).

export interface BundledTrailAsset {
  id?: string;
  name?: string;
  region?: string;
  difficulty?: string;
  distanceKm?: number;
  elevationGainM?: number;
  elevationDescentM?: number;
  estTimeHours?: number;
  description?: string;
  minEle?: number;
  maxEle?: number;
  coords?: unknown;
  profile?: unknown;
}

export function trailFromAsset(json: BundledTrailAsset): Trail {
  const coords: TrailCoord[] = [];
  const rawCoords = Array.isArray(json.coords) ? json.coords : [];
  for (const c of rawCoords) {
    if (!Array.isArray(c) || c.length < 2) continue;
    const lat = num(c[0]);
    const lon = num(c[1]);
    if (lat === 0 && lon === 0) continue;
    const elev = c.length > 2 ? num(c[2]) : 0;
    coords.push({ lat, lon, elev });
  }

  const rawProfile = Array.isArray(json.profile) ? json.profile : [];
  const elev: ElevationPoint[] = [];
  for (const p of rawProfile) {
    if (!Array.isArray(p) || p.length < 2) continue;
    elev.push({ km: num(p[0]), metres: num(p[1]) });
  }
  // Down-sample to roughly 28 samples for the chart, keeping the
  // endpoints so the chart spans 0 → totalKm.
  const downsampled = downsampleElevation(elev, 28);

  // Bounding box from raw coords (some assets ship pre-computed bbox).
  let minLat = Infinity, maxLat = -Infinity, minLon = Infinity, maxLon = -Infinity;
  for (const c of coords) {
    if (c.lat < minLat) minLat = c.lat;
    if (c.lat > maxLat) maxLat = c.lat;
    if (c.lon < minLon) minLon = c.lon;
    if (c.lon > maxLon) maxLon = c.lon;
  }
  if (!Number.isFinite(minLat)) {
    minLat = maxLat = minLon = maxLon = 0;
  }

  return {
    id: str(json.id),
    name: str(json.name, 'Unnamed trail'),
    region: str(json.region, ''),
    difficulty: normalizeDifficulty(json.difficulty),
    distanceKm: num(json.distanceKm),
    ascentM: num(json.elevationGainM),
    descentM: num(json.elevationDescentM),
    estTimeHours: num(json.estTimeHours),
    baseM: num(json.minEle),
    elev: downsampled,
    coords,
    bbox: { minLat, maxLat, minLon, maxLon },
    description: str(json.description, ''),
  };
}

/** Returned by `Trails` list — picks the lean subset. */
export function trailListItemFromAsset(json: BundledTrailAsset): TrailListItem {
  const t = trailFromAsset(json);
  return {
    id: t.id,
    name: t.name,
    region: t.region,
    difficulty: t.difficulty,
    distanceKm: t.distanceKm,
    ascentM: t.ascentM,
    hoursLabel: formatHoursRange(t.estTimeHours),
    rating: null,        // BLOCKERS.md #10
    reportsCount: null,  // BLOCKERS.md #10
    tags: null,          // BLOCKERS.md #10
    liveCount: null,     // BLOCKERS.md #10
  };
}

/** `5.4` → `'5–6'`; `5.0` → `'5'`. */
function formatHoursRange(hours: number): string {
  if (!Number.isFinite(hours) || hours <= 0) return '—';
  const low = Math.floor(hours);
  const high = Math.ceil(hours);
  if (low === high) return `${low}`;
  return `${low}–${high}`;
}

/**
 * Keep first + last + spread N − 2 evenly between them. Stable, doesn't
 * smooth — the asset profile is already smoothed upstream.
 */
function downsampleElevation(
  points: ElevationPoint[],
  target: number,
): ElevationPoint[] {
  if (points.length <= target) return points;
  const out: ElevationPoint[] = [];
  const step = (points.length - 1) / (target - 1);
  for (let i = 0; i < target; i++) {
    const idx = Math.round(i * step);
    out.push(points[idx]!);
  }
  return out;
}

// ───────────────────────────── Forecast ──────────────────────────────
//
// Open-Meteo's "forecast" payload arrays come back column-major (one
// array per field). The adapter rebuilds them into row-shaped objects.

export interface OpenMeteoForecastPayload {
  daily?: {
    time?: string[];
    temperature_2m_max?: number[];
    temperature_2m_min?: number[];
    wind_speed_10m_max?: number[];
    weather_code?: number[];
    precipitation_probability_max?: number[];
  };
}

export function forecastDaysFromOpenMeteo(
  payload: OpenMeteoForecastPayload,
  now: Date = new Date(),
): ForecastDay[] {
  const d = payload.daily ?? {};
  const times = d.time ?? [];
  const hi = d.temperature_2m_max ?? [];
  const lo = d.temperature_2m_min ?? [];
  const winds = d.wind_speed_10m_max ?? [];
  const codes = d.weather_code ?? [];
  const precips = d.precipitation_probability_max ?? [];
  const out: ForecastDay[] = [];
  for (let i = 0; i < times.length; i++) {
    const date = asDate(times[i]);
    const dayLabel = isSameYMD(date, now)
      ? 'TODAY'
      : date.toLocaleDateString('en-US', { weekday: 'short' }).toUpperCase();
    const wind = num(winds[i]);
    const precip = num(precips[i]);
    const score = computeHikeScore(wind, precip);
    out.push({
      dayLabel,
      dateLabel: shortDateLabel(date),
      date,
      icon: weatherIconKind(num(codes[i])),
      hiC: num(hi[i]),
      loC: num(lo[i]),
      windKmh: wind,
      hikeScore: score,
      hikeLabel: hikeScoreLabel(score),
    });
  }
  return out;
}

function isSameYMD(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

// ───────────────────────────── Notifications ─────────────────────────
//
// Backed by the `notifications` table (BLOCKERS #12 RESOLVED). Row type
// lives in `schema.ts`. Adapter normalises kind + relative time label.

export function notificationFromRow(row: NotificationRow): Notification {
  const at = asDate(row.received_at);
  return {
    id: row.id,
    kind: normalizeNotificationKind(row.kind),
    urgent: row.urgent === true,
    timeLabel: relativeTimeLabel(at),
    receivedAt: at,
    title: str(row.title, ''),
    sub: str(row.sub, ''),
    action: str(row.action, ''),
    read: row.read === true,
  };
}

// ──────────────────────────────── Team ───────────────────────────────

export function teamMemberLiveFromRow(
  row: TeamMemberLocationRow,
  ctx: { ownerUid: string | null; currentUid: string | null },
): TeamMemberLive {
  const lastSeen = asDate(row.timestamp);
  const minutesOld = (Date.now() - lastSeen.getTime()) / 60_000;
  const speedKmh = num(row.speed) * 3.6; // DB stores m/s
  const battery = row.battery_pct == null ? null : num(row.battery_pct);
  const connectivity =
    row.connectivity === 'wifi' || row.connectivity === 'mobile' || row.connectivity === 'none'
      ? row.connectivity
      : null;
  // Resolve a friendly place via the bundled Drakensberg shelters
  // (BLOCKERS #20 resolved). Falls back to a coordinate snippet when no
  // shelter is within 3 km — never returns an empty string.
  const lat = num(row.lat);
  const lon = num(row.lon);
  const shelter = lat !== 0 && lon !== 0 ? nearestShelter(lat, lon) : null;
  const locationLabel = shelter
    ? `Near ${shelter.name} · ${(shelter.distanceM / 1000).toFixed(1)} km`
    : lat !== 0 && lon !== 0
      ? `${lat.toFixed(3)}, ${lon.toFixed(3)}`
      : '—';
  return {
    uid: row.uid,
    name: str(row.display_name, 'Hiker'),
    initials: initialsFromName(str(row.display_name, 'Hiker')),
    color: colorForUid(row.uid),
    locationLabel,
    distanceKm: null, // computed from hike history in the screen
    altitudeM: num(row.altitude),
    speedKmh,
    batteryPct: battery,
    connectivity,
    lead: ctx.ownerUid === row.uid,
    alert:
      (battery != null && battery <= 15) ||
      connectivity === 'none' ||
      minutesOld > 30,
    lastSeen,
    lat: num(row.lat),
    lon: num(row.lon),
  };
}

// ─────────────────────────── SOS / Incidents ─────────────────────────

export function nearbyHazardFromIncident(row: IncidentRow): NearbyHazard {
  const at = asDate(row.reported_at);
  const kind = normalizeHazardKind(row.type);
  const iconMap: Record<string, IconName> = {
    water: 'wind',
    shelter: 'rock',
    danger: 'alert',
    view: 'eye',
    summit: 'mountain',
  };
  return {
    id: row.id,
    iconName: iconMap[kind] ?? 'alert',
    title: str(row.title, str(row.type, 'Hazard')),
    sub: str(row.description, ''),
    risk: normalizeRisk(row.severity),
    reportedAt: at,
    timeLabel: timeOfDayLabel(at),
  };
}

// ──────────────────────────── ChatMessage ────────────────────────────
//
// Maps a `chat_messages` row to the design's ChatMessage. `currentUid`
// drives the `mine` flag.

export interface ChatMessageRow {
  id: string;
  room_id: string;
  sender_id: string | null;
  sender_name: string | null;
  message_text: string | null;
  sent_at: string | null;
  // `reactions` shipped with the security_hardening migration
  // (#14 resolved). Shape: [{ emoji, by_uid, at }, …].
  reactions?: unknown;
}

interface ReactionEntry {
  emoji?: unknown;
  by_uid?: unknown;
}

export function chatMessageFromRow(
  row: ChatMessageRow,
  currentUid: string | null,
): ChatMessage {
  const senderName = str(row.sender_name, 'Hiker');
  const senderId = row.sender_id ?? '';
  const sender: ChatSender = {
    id: senderId,
    name: senderName,
    initials: initialsFromName(senderName),
    color: colorForUid(senderId),
  };
  const at = asDate(row.sent_at);
  // Surface the current user's reaction if present; otherwise the
  // first reaction (rendered as a small pill on the bubble).
  let reaction: string | undefined;
  if (Array.isArray(row.reactions)) {
    const reactions = row.reactions as ReactionEntry[];
    const mine = currentUid
      ? reactions.find((r) => r && r.by_uid === currentUid)
      : null;
    const pick = mine ?? reactions[0];
    if (pick && typeof pick.emoji === 'string') reaction = pick.emoji;
  }
  return {
    id: row.id,
    sentAt: at,
    timeLabel: timeOfDayLabel(at),
    sender,
    mine: currentUid != null && senderId === currentUid,
    text: str(row.message_text, ''),
    reaction,
    roomId: row.room_id,
  };
}

// ─────────────────────────── Profile stats ───────────────────────────
//
// Computed entirely from `hike_history` rows — no separate table.

export function profileStatsFromHikes(rows: HikeHistoryRow[]): ProfileStat[] {
  const totals = rows.reduce(
    (acc, r) => ({
      count: acc.count + 1,
      km: acc.km + num(r.distance_km),
      ascent: acc.ascent + num(r.ascent_m),
      peaks: acc.peaks + num(r.peaks_climbed),
    }),
    { count: 0, km: 0, ascent: 0, peaks: 0 },
  );
  return [
    { label: 'Hikes', value: thousandsLabel(totals.count), iconName: 'mountain' },
    { label: 'Distance', value: totals.km.toFixed(0), unit: 'km', iconName: 'navigation', ember: true },
    { label: 'Ascent', value: thousandsLabel(totals.ascent), unit: 'm', iconName: 'arrow-up' },
    { label: 'Peaks', value: thousandsLabel(totals.peaks), iconName: 'flame' },
  ];
}

// Re-export so callers don't have to also import Difficulty separately.
export type { Difficulty };

// ───────────────────────────── Safety + emergency ────────────────────

export function safetyPlanFromRow(
  row: SafetyPlanRow,
  pings: number,
): ActiveSafetyPlan {
  const gear = Array.isArray(row.gear)
    ? (row.gear as unknown[])
        .map((it, idx): GearChecklistItem | null => {
          if (!it || typeof it !== 'object') return null;
          const obj = it as Record<string, unknown>;
          return {
            id: str(obj.id, `gear-${idx}`),
            label: str(obj.label, 'Item'),
            sub: str(obj.sub, ''),
            done: obj.done === true,
          };
        })
        .filter((it): it is GearChecklistItem => it != null)
    : [];
  return {
    id: row.id,
    trailName: str(row.trail_name, 'Unnamed trail'),
    trailId: row.trail_id,
    expectedReturn: asDate(row.expected_return),
    backpack: str(row.backpack, ''),
    tent: row.tent,
    watcherCount: Array.isArray(row.watcher_uids) ? row.watcher_uids.length : pings,
    lastPing: row.last_ping ? asDate(row.last_ping) : null,
    gear,
  };
}

export function emergencyContactFromRow(row: EmergencyContactRow): EmergencyContact {
  const type =
    row.type === 'rescue' || row.type === 'ambulance' || row.type === 'personal'
      ? row.type
      : 'personal';
  return {
    id: row.id,
    name: str(row.name, 'Contact'),
    sub: str(row.sub, ''),
    phone: str(row.phone, ''),
    type,
  };
}

// ───────────────────────────── Route plans ───────────────────────────

export function waypointFromRow(row: RouteWaypointRow): Waypoint {
  const type =
    row.type === 'start' || row.type === 'poi' || row.type === 'shelter' || row.type === 'end'
      ? row.type
      : 'poi';
  return {
    num: str(row.num, String(row.idx + 1)),
    type,
    name: str(row.name, 'Waypoint'),
    sub: str(row.sub, ''),
    km: num(row.km),
  };
}

export function routePlanFromRow(
  row: RoutePlanRow,
  waypoints: RouteWaypointRow[],
): RoutePlan {
  const sorted = [...waypoints].sort((a, b) => a.idx - b.idx);
  return {
    id: row.id,
    name: str(row.name, 'Untitled route'),
    date: row.hike_date ? asDate(row.hike_date) : new Date(),
    startTimeLabel: str(row.start_time, '—'),
    waypoints: sorted.map(waypointFromRow),
    tetherWatcherId: row.watcher_team_id,
    totalKm: num(row.total_km),
    ascentM: num(row.ascent_m),
    durationMinutes: num(row.duration_minutes),
  };
}

// ───────────────────────────── Incident timeline ─────────────────────

export function incidentEventFromRow(row: IncidentEventRow): IncidentTimelineEvent {
  const at = asDate(row.at);
  const status: TimelineStatus =
    row.status === 'done' || row.status === 'active' || row.status === 'pending'
      ? row.status
      : 'pending';
  return {
    at,
    timeLabel: timeOfDayLabel(at),
    label: str(row.label, ''),
    status,
  };
}

// ───────────────────────────── Trail extras ──────────────────────────
//
// `v_trail_metadata` ships a flat read shape; this adapter parses the
// JSONB segments / prep / hazards arrays defensively so a malformed
// entry can't take down the Trail Detail screen.

export function trailExtrasFromViewRow(row: TrailMetadataViewRow): TrailExtras {
  return {
    trailId: row.trail_id,
    techGrade: str(row.tech_grade, '—'),
    rating: num(row.avg_rating),
    reportsCount: row.reviews_count + row.open_incidents,
    segments: parseSegments(row.segments),
    hazards: parseHazards(row.hazards),
    prep: parsePrep(row.prep),
  };
}

export function trailExtrasFromMetadataRow(row: TrailMetadataRow): TrailExtras {
  return {
    trailId: row.trail_id,
    techGrade: str(row.tech_grade, '—'),
    rating: 0,
    reportsCount: 0,
    segments: parseSegments(row.segments),
    hazards: [],
    prep: parsePrep(row.prep),
  };
}

function parseSegments(raw: unknown): TrailSegment[] {
  if (!Array.isArray(raw)) return [];
  const out: TrailSegment[] = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const obj = item as Record<string, unknown>;
    out.push({
      km0: num(obj.km0),
      km1: num(obj.km1),
      diff: normalizeDifficulty(obj.diff),
      name: str(obj.name, 'Segment'),
      body: str(obj.body, ''),
    });
  }
  return out;
}

function parseHazards(raw: unknown): TrailHazard[] {
  if (!Array.isArray(raw)) return [];
  const out: TrailHazard[] = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const obj = item as Record<string, unknown>;
    out.push({
      km: num(obj.km),
      kind: normalizeHazardKind(obj.kind),
      label: str(obj.label ?? obj.description, 'Hazard'),
      desc: str(obj.description, ''),
    });
  }
  return out;
}

// ───────────────────────────── Posts (feed) ──────────────────────────

export interface PostWithAuthor extends PostRow {
  author?: Pick<ProfileRow, 'id' | 'display_name' | 'username' | 'photo_url'> | null;
  /** Whether the current user liked this post. Filled in by usePosts. */
  liked_by_me?: boolean;
}

export function postFromRow(
  row: PostWithAuthor,
  currentUid: string | null,
): FeedPost {
  const at = asDate(row.posted_at);
  const profile = row.author ?? null;
  const name = str(profile?.display_name, str(profile?.username, 'Hiker'));
  const author: FeedAuthor = {
    id: row.author_id,
    name,
    initials: initialsFromName(name),
    color: colorForUid(row.author_id),
  };
  return {
    id: row.id,
    author,
    timeLabel: relativeTimeLabel(at),
    postedAt: at,
    location: str(row.location, ''),
    text: str(row.text, ''),
    stats: parsePostStats(row.stats),
    likes: row.likes_count ?? 0,
    comments: row.comments_count ?? 0,
    hazard: row.hazard === true,
    attachment: parsePostAttachment(row.attachment),
  };
}

function parsePostStats(raw: unknown): FeedPostStats | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  const obj = raw as Record<string, unknown>;
  const distLabel = str(obj.distLabel ?? obj.dist_label, '');
  const gainLabel = str(obj.gainLabel ?? obj.gain_label, '');
  const timeLabel = str(obj.timeLabel ?? obj.time_label, '');
  if (!distLabel && !gainLabel && !timeLabel) return undefined;
  return { distLabel, gainLabel, timeLabel };
}

function parsePostAttachment(raw: unknown): FeedPostAttachment | null {
  if (!raw || typeof raw !== 'object') return null;
  const obj = raw as Record<string, unknown>;
  const kind = obj.kind;
  if (kind === 'elev') {
    const samples = Array.isArray(obj.samples)
      ? (obj.samples as unknown[])
          .map((s) => (typeof s === 'number' ? s : null))
          .filter((s): s is number => s != null)
      : [];
    return { kind: 'elev', samples };
  }
  if (kind === 'gpx') {
    return {
      kind: 'gpx',
      filename: str(obj.filename, 'track.gpx'),
      waypoints:
        typeof obj.waypoints === 'number' && Number.isFinite(obj.waypoints)
          ? obj.waypoints
          : 0,
      bytes:
        typeof obj.bytes === 'number' && Number.isFinite(obj.bytes) ? obj.bytes : 0,
    };
  }
  return { kind: null };
}

function parsePrep(raw: unknown): TrailPrep {
  const empty: TrailPrep = {
    water: '',
    food: '',
    layers: '',
    safety: '',
    permit: '',
    startBy: '',
    turnAround: '',
    cellSignal: '',
  };
  if (!raw || typeof raw !== 'object') return empty;
  const obj = raw as Record<string, unknown>;
  return {
    water: str(obj.water, ''),
    food: str(obj.food, ''),
    layers: str(obj.layers, ''),
    safety: str(obj.safety, ''),
    permit: str(obj.permit, ''),
    startBy: str(obj.startBy ?? obj.start_by, ''),
    turnAround: str(obj.turnAround ?? obj.turn_around, ''),
    cellSignal: str(obj.cellSignal ?? obj.cell_signal, ''),
  };
}
