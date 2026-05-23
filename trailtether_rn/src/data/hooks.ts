// Trailtether — async data hooks.
//
// Every hook returns `{ data, loading, error, refetch }`. Screens drop
// the same LoadingState / ErrorState components into each surface so the
// UX is consistent end-to-end.
//
// Real data sources, no mocks:
//   * Supabase tables (see `data/schema.ts`)
//   * Open-Meteo forecast API (matches the Flutter app's source)
//   * Bundled `routes_cleaned.json` + `caves.gpx` per BLOCKERS.md #9
//
// When a hook can't be satisfied (the underlying endpoint doesn't
// exist), it returns `error: BLOCKED:<n>:<reason>` where `<n>` is the
// BLOCKERS.md entry number. Screens render `<BlockedSection number={n}
// …/>` for those instead of `<ErrorState>`.

import { Asset } from 'expo-asset';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useAuth } from '@/store/auth';
import { supabase } from '@/data/supabase';
import {
  chatMessageFromRow,
  emergencyContactFromRow,
  forecastDaysFromOpenMeteo,
  hikeRecordFromRow,
  incidentEventFromRow,
  nearbyHazardFromIncident,
  notificationFromRow,
  postFromRow,
  profileStatsFromHikes,
  routePlanFromRow,
  safetyPlanFromRow,
  teamMemberLiveFromRow,
  trailExtrasFromViewRow,
  trailFromAsset,
  trailListItemFromAsset,
  type BundledTrailAsset,
  type ChatMessageRow,
  type OpenMeteoForecastPayload,
  type PostWithAuthor,
} from '@/data/adapters';
import type {
  AchievementProgressRow,
  EmergencyContactRow,
  HikeHistoryRow,
  HikePlanRow,
  IncidentEventRow,
  IncidentRow,
  NotificationRow,
  PostCommentRow,
  PostRow,
  ProfileRow,
  RoutePlanRow,
  RouteWaypointRow,
  SafetyPlanRow,
  TeamMemberLocationRow,
  TrailMetadataViewRow,
  WeatherLocationRow,
} from '@/data/schema';
import type {
  ActiveSafetyPlan,
  ChatMessage,
  EmergencyContact,
  FeedPost,
  ForecastDay,
  HikeRecord,
  IncidentTimelineEvent,
  NearbyHazard,
  Notification,
  ProfileStat,
  RoutePlan,
  TeamMemberLive,
  Trail,
  TrailExtras,
  TrailListItem,
} from '@/data/types';
import { ACHIEVEMENTS_CATALOG, type AchievementCatalogEntry } from '@/data/achievements_catalog';

export interface AsyncResource<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

/** Format a BLOCKERS.md-pointer error. Detected by screens to switch to BlockedSection. */
export function blocked(n: number, reason?: string): string {
  return `BLOCKED:${n}:${reason ?? `BLOCKERS.md entry #${n} pending`}`;
}

/** Parse a "BLOCKED:n:…" error string back into its components. */
export function parseBlocked(err: string | null): { n: number; reason: string } | null {
  if (!err || !err.startsWith('BLOCKED:')) return null;
  const rest = err.slice('BLOCKED:'.length);
  const colonIdx = rest.indexOf(':');
  if (colonIdx < 0) return null;
  const n = parseInt(rest.slice(0, colonIdx), 10);
  if (Number.isNaN(n)) return null;
  return { n, reason: rest.slice(colonIdx + 1) };
}

// ──────────────────────────── upcoming hikes ────────────────────────────

export interface UpcomingHike {
  id: string;
  trailId: string;
  trailName: string;
  hikeDate: Date;
  teamId: string | null;
  meetingPoint: string | null;
  status: HikePlanRow['status'];
}

export function useUpcomingHikes(): AsyncResource<UpcomingHike[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<UpcomingHike[]>(
    ['upcomingHikes', uid ?? ''],
    async () => {
      if (!uid) return [];
      const { data: teamRows, error: teamErr } = await supabase
        .from('teams')
        .select('id')
        .contains('member_uids', [uid]);
      if (teamErr) throw teamErr;
      const teamIds = (teamRows ?? []).map((r) => (r as { id: string }).id);
      if (teamIds.length === 0) return [];
      const nowIso = new Date().toISOString();
      const { data, error } = await supabase
        .from('hike_plans')
        .select('*')
        .in('team_id', teamIds)
        .gte('hike_date', nowIso)
        .order('hike_date', { ascending: true })
        .limit(10);
      if (error) throw error;
      return (data as HikePlanRow[]).map((r) => ({
        id: r.id,
        trailId: r.trail_id,
        trailName: r.trail_name,
        hikeDate: new Date(r.hike_date),
        teamId: r.team_id,
        meetingPoint: r.meeting_point,
        status: r.status,
      }));
    },
    [uid],
  );
}

// ──────────────────────────── last hike ────────────────────────────────

export interface LastHikeSummary {
  id: string;
  name: string;
  distanceKm: number;
  ascentM: number;
  durationSeconds: number;
  createdAt: Date;
}

export function useLastHike(): AsyncResource<LastHikeSummary | null> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<LastHikeSummary | null>(
    ['lastHike', uid ?? ''],
    async () => {
      if (!uid) return null;
      const { data, error } = await supabase
        .from('hike_history')
        .select('id, name, distance_km, ascent_m, duration_seconds, created_at')
        .eq('user_id', uid)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (error) throw error;
      if (!data) return null;
      const row = data as Pick<
        HikeHistoryRow,
        'id' | 'name' | 'distance_km' | 'ascent_m' | 'duration_seconds' | 'created_at'
      >;
      return {
        id: row.id,
        name: row.name?.trim() || 'Recorded hike',
        distanceKm: row.distance_km ?? 0,
        ascentM: row.ascent_m ?? 0,
        durationSeconds: row.duration_seconds ?? 0,
        createdAt: new Date(row.created_at ?? Date.now()),
      };
    },
    [uid],
  );
}

// ──────────────────────────── hike history ─────────────────────────────

export function useHikeHistory(): AsyncResource<HikeRecord[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<HikeRecord[]>(
    ['hikeHistory', uid ?? ''],
    async () => {
      if (!uid) return [];
      const { data, error } = await supabase
        .from('hike_history')
        .select('*')
        .eq('user_id', uid)
        .order('created_at', { ascending: false })
        .limit(200);
      if (error) throw error;
      return (data as HikeHistoryRow[]).map(hikeRecordFromRow);
    },
    [uid],
  );
}

// ──────────────────────────── profile stats ────────────────────────────

export function useProfileStats(): AsyncResource<ProfileStat[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<ProfileStat[]>(
    ['profileStats', uid ?? ''],
    async () => {
      if (!uid) return [];
      const { data, error } = await supabase
        .from('hike_history')
        .select('distance_km, ascent_m, duration_seconds, peaks_climbed')
        .eq('user_id', uid);
      if (error) throw error;
      return profileStatsFromHikes(data as HikeHistoryRow[]);
    },
    [uid],
  );
}

// ──────────────────────────── weather location ─────────────────────────

export interface WeatherLocation {
  id: string;
  name: string;
  lat: number;
  lon: number;
}

export function useHomeWeatherLocation(): AsyncResource<WeatherLocation | null> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<WeatherLocation | null>(
    ['homeWeatherLocation', uid ?? ''],
    async () => {
      if (!uid) return null;
      const { data, error } = await supabase
        .from('weather_locations')
        .select('*')
        .eq('user_id', uid)
        .order('created_at', { ascending: true })
        .limit(1)
        .maybeSingle();
      if (error) throw error;
      if (!data) return null;
      const row = data as WeatherLocationRow;
      return { id: row.id, name: row.name, lat: row.latitude, lon: row.longitude };
    },
    [uid],
  );
}

export function useWeatherLocations(): AsyncResource<WeatherLocation[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<WeatherLocation[]>(
    ['weatherLocations', uid ?? ''],
    async () => {
      if (!uid) return [];
      const { data, error } = await supabase
        .from('weather_locations')
        .select('*')
        .eq('user_id', uid)
        .order('created_at', { ascending: true });
      if (error) throw error;
      return (data as WeatherLocationRow[]).map((r) => ({
        id: r.id,
        name: r.name,
        lat: r.latitude,
        lon: r.longitude,
      }));
    },
    [uid],
  );
}

// ──────────────────────────── weather (Open-Meteo) ─────────────────────

export interface CurrentConditions {
  temperatureC: number;
  feelsLikeC: number;
  windKmh: number;
  humidity: number;
  weatherCode: number;
  precipitation: number;
  uvIndex: number;
  hikeScore: number;
  fetchedAt: string;
}

export function useCurrentWeather(
  location: WeatherLocation | null | undefined,
): AsyncResource<CurrentConditions | null> {
  const lat = location?.lat;
  const lon = location?.lon;
  const key = useMemo(
    () =>
      lat != null && lon != null
        ? `weather:${lat.toFixed(3)},${lon.toFixed(3)}`
        : 'weather:none',
    [lat, lon],
  );
  return useSupabaseQuery<CurrentConditions | null>(
    [key],
    async () => {
      if (lat == null || lon == null) return null;
      const url =
        'https://api.open-meteo.com/v1/forecast' +
        `?latitude=${lat}` +
        `&longitude=${lon}` +
        '&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,uv_index' +
        '&wind_speed_unit=kmh' +
        '&timezone=auto';
      const res = await fetch(url);
      if (!res.ok) throw new Error(`Open-Meteo HTTP ${res.status}`);
      const body = (await res.json()) as { current?: Record<string, number | undefined> };
      const c = body.current ?? {};
      const wind = num(c.wind_speed_10m);
      const precipProb = num(c.precipitation);
      const windPenalty = (Math.min(Math.max(wind - 10, 0), 50) / 50) * 4;
      const raw = (1 - precipProb / 100) * 10 - windPenalty;
      const hikeScore = Math.max(1, Math.min(10, Math.round(raw)));
      return {
        temperatureC: num(c.temperature_2m),
        feelsLikeC: num(c.apparent_temperature),
        humidity: num(c.relative_humidity_2m),
        precipitation: precipProb,
        weatherCode: Math.round(num(c.weather_code)),
        windKmh: wind,
        uvIndex: num(c.uv_index),
        hikeScore,
        fetchedAt: new Date().toISOString(),
      };
    },
    [lat, lon],
  );
}

// ──────────────────────────── 7-day forecast ───────────────────────────

export function useForecast(
  location: WeatherLocation | null | undefined,
): AsyncResource<ForecastDay[]> {
  const lat = location?.lat;
  const lon = location?.lon;
  const key = useMemo(
    () =>
      lat != null && lon != null
        ? `forecast:${lat.toFixed(3)},${lon.toFixed(3)}`
        : 'forecast:none',
    [lat, lon],
  );
  return useSupabaseQuery<ForecastDay[]>(
    [key],
    async () => {
      if (lat == null || lon == null) return [];
      const url =
        'https://api.open-meteo.com/v1/forecast' +
        `?latitude=${lat}` +
        `&longitude=${lon}` +
        '&daily=temperature_2m_max,temperature_2m_min,wind_speed_10m_max,weather_code,precipitation_probability_max' +
        '&wind_speed_unit=kmh' +
        '&forecast_days=7' +
        '&timezone=auto';
      const res = await fetch(url);
      if (!res.ok) throw new Error(`Open-Meteo HTTP ${res.status}`);
      const body = (await res.json()) as OpenMeteoForecastPayload;
      return forecastDaysFromOpenMeteo(body);
    },
    [lat, lon],
  );
}

// ──────────────────────────── achievements ─────────────────────────────
//
// Catalog ships static; per-user progress reads from
// `v_user_achievement_progress` (BLOCKERS #5 partial). Five catalog ids
// have real progress wired today (first / gpx / highrise / 5k /
// centurion); the rest stay locked with progress 0. Banner explains.

export interface AchievementWithProgress extends AchievementCatalogEntry {
  /** 0..1 — 1 means unlocked. */
  progress: number;
  unlocked: boolean;
  earnedAt: Date | null;
  /** True when the catalog id isn't in the deterministic view yet. */
  derivationPending: boolean;
}

export interface AchievementsResource {
  catalog: AchievementWithProgress[];
  unlockedCount: number;
  /** Banner copy explaining the catalog ids that don't yet derive. */
  partial: { resolvedIds: string[]; pendingCount: number } | null;
}

const DERIVED_ACHIEVEMENT_IDS = new Set([
  'first',
  'gpx',
  'highrise',
  '5k',
  'centurion',
  'lead',
  'guide',
  'sos',
]);

export function useAchievements(): AsyncResource<AchievementsResource> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<AchievementsResource>(
    ['achievementsCatalog', uid ?? ''],
    async () => {
      const progressByid = new Map<string, AchievementProgressRow>();
      if (uid) {
        const { data, error } = await supabase
          .from('v_user_achievement_progress')
          .select('*')
          .eq('user_id', uid);
        if (error) throw error;
        for (const row of (data ?? []) as AchievementProgressRow[]) {
          progressByid.set(row.achievement_id, row);
        }
      }
      const catalog = ACHIEVEMENTS_CATALOG.map<AchievementWithProgress>((entry) => {
        const row = progressByid.get(entry.id);
        const progress = row ? clamp01(row.progress) : 0;
        return {
          ...entry,
          progress,
          unlocked: progress >= 1,
          earnedAt: row?.earned_at ? new Date(row.earned_at) : null,
          derivationPending: !DERIVED_ACHIEVEMENT_IDS.has(entry.id),
        };
      });
      const unlockedCount = catalog.filter((a) => a.unlocked).length;
      const pendingCount = catalog.filter((a) => a.derivationPending).length;
      return {
        catalog,
        unlockedCount,
        partial:
          pendingCount > 0
            ? {
                resolvedIds: Array.from(DERIVED_ACHIEVEMENT_IDS),
                pendingCount,
              }
            : null,
      };
    },
    [uid],
  );
}

function clamp01(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(1, n));
}

// ──────────────────────────── trails catalog ───────────────────────────
//
// The bundled `routes_cleaned.json` ships as an Expo asset; we load it
// once on first use, parse via `trailFromAsset`, and cache the result.

let TRAILS_CACHE: Trail[] | null = null;

async function loadTrailsAsset(): Promise<Trail[]> {
  if (TRAILS_CACHE) return TRAILS_CACHE;
  // require() routes via Metro at build time and produces an Asset module.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const mod = require('../../assets/data/routes_cleaned.json') as BundledTrailAsset[];
  const out: Trail[] = [];
  for (const row of mod) {
    try {
      out.push(trailFromAsset(row));
    } catch {
      // Skip malformed rows rather than failing the whole catalog.
    }
  }
  out.sort((a, b) => a.name.localeCompare(b.name));
  TRAILS_CACHE = out;
  // Touch via expo-asset so caching middleware knows about it.
  void Asset;
  return out;
}

export function useTrailsCatalog(): AsyncResource<TrailListItem[]> {
  return useSupabaseQuery<TrailListItem[]>(
    ['trailsCatalog'],
    async () => {
      try {
        const all = await loadTrailsAsset();
        return all.map((t) => trailListItemFromAsset({
          id: t.id,
          name: t.name,
          region: t.region,
          difficulty: t.difficulty,
          distanceKm: t.distanceKm,
          elevationGainM: t.ascentM,
          elevationDescentM: t.descentM,
          estTimeHours: t.estTimeHours,
          description: t.description,
          minEle: t.baseM,
          coords: t.coords.map((c) => [c.lat, c.lon, c.elev]),
          profile: t.elev.map((e) => [e.km, e.metres]),
        }));
      } catch (err) {
        // Asset missing — BLOCKERS.md #9.
        throw new Error(blocked(9, 'routes_cleaned.json not bundled yet.'));
      }
    },
    [],
  );
}

export function useTrail(trailId: string | null | undefined): AsyncResource<Trail | null> {
  return useSupabaseQuery<Trail | null>(
    ['trail', trailId ?? ''],
    async () => {
      if (!trailId) return null;
      try {
        const all = await loadTrailsAsset();
        return all.find((t) => t.id === trailId) ?? null;
      } catch {
        throw new Error(blocked(9, 'routes_cleaned.json not bundled yet.'));
      }
    },
    [trailId],
  );
}

// ──────────────────────────── team members ─────────────────────────────

export function useTeamMembers(teamId: string | null | undefined): AsyncResource<TeamMemberLive[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<TeamMemberLive[]>(
    ['teamMembers', teamId ?? ''],
    async () => {
      if (!teamId) return [];
      const [{ data: locRows, error: locErr }, { data: teamRow, error: teamErr }] =
        await Promise.all([
          supabase
            .from('team_member_locations')
            .select('*')
            .eq('team_id', teamId)
            .order('timestamp', { ascending: false }),
          supabase
            .from('teams')
            .select('created_by')
            .eq('id', teamId)
            .maybeSingle(),
        ]);
      if (locErr) throw locErr;
      if (teamErr) throw teamErr;
      const ownerUid = (teamRow as { created_by?: string } | null)?.created_by ?? null;
      return (locRows as TeamMemberLocationRow[]).map((r) =>
        teamMemberLiveFromRow(r, { ownerUid, currentUid: uid ?? null }),
      );
    },
    [teamId, uid],
  );
}

export function useMyTeams(): AsyncResource<{ id: string; name: string }[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<{ id: string; name: string }[]>(
    ['myTeams', uid ?? ''],
    async () => {
      if (!uid) return [];
      const { data, error } = await supabase
        .from('teams')
        .select('id, name')
        .contains('member_uids', [uid])
        .order('created_at', { ascending: false });
      if (error) throw error;
      return (data ?? []) as { id: string; name: string }[];
    },
    [uid],
  );
}

// ──────────────────────────── chat messages ────────────────────────────

export function useChatMessages(roomId: string | null | undefined): AsyncResource<ChatMessage[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<ChatMessage[]>(
    ['chatMessages', roomId ?? ''],
    async () => {
      if (!roomId) return [];
      const { data, error } = await supabase
        .from('chat_messages')
        .select('id, room_id, sender_id, sender_name, message_text, sent_at, reactions')
        .eq('room_id', roomId)
        .order('sent_at', { ascending: true })
        .limit(200);
      if (error) throw error;
      return (data as ChatMessageRow[]).map((r) => chatMessageFromRow(r, uid ?? null));
    },
    [roomId, uid],
  );
}

// ──────────────────────────── nearby incidents ─────────────────────────

export function useNearbyHazards(): AsyncResource<NearbyHazard[]> {
  return useSupabaseQuery<NearbyHazard[]>(
    ['nearbyHazards'],
    async () => {
      // Without PostGIS proximity (BLOCKERS.md #17) we approximate
      // "nearby" with "open incidents reported in the last 24h".
      const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
      const { data, error } = await supabase
        .from('incidents')
        .select('*')
        .eq('status', 'open')
        .gte('reported_at', since)
        .order('reported_at', { ascending: false })
        .limit(20);
      if (error) throw error;
      return (data as IncidentRow[]).map(nearbyHazardFromIncident);
    },
    [],
  );
}

// ──────────────────────────── field intel feed ─────────────────────────
//
// Reads open `incidents` then filters client-side by haversine distance
// from a `center` (typically the user's first weather_location).
// Resolves BLOCKERS.md #4 without a schema change: the data model
// already carries lat/lon on every incident, so proximity scoping is
// purely a client concern.
//
// Pass `center: null` to disable filtering (used on screens with no
// region context yet).

export interface FieldIntelOptions {
  /** Filter centre. When null, returns every open incident (capped at limit). */
  center: { lat: number; lon: number } | null;
  /** Default 80 km — roughly "your region" at Drakensberg scale. */
  radiusKm?: number;
  /** Max rows. Defaults to 8 (Home card). */
  limit?: number;
}

export function useFieldIntel(opts: FieldIntelOptions = { center: null }): AsyncResource<NearbyHazard[]> {
  const { center, radiusKm = 80, limit = 8 } = opts;
  const lat = center?.lat;
  const lon = center?.lon;
  return useSupabaseQuery<NearbyHazard[]>(
    ['fieldIntel', lat != null ? lat.toFixed(3) : '*', lon != null ? lon.toFixed(3) : '*', String(radiusKm), String(limit)],
    async () => {
      // Pull a wider window than we render so the proximity filter has
      // something to bite. Capped at 60 to keep payload small.
      const { data, error } = await supabase
        .from('incidents')
        .select('*')
        .eq('status', 'open')
        .order('reported_at', { ascending: false })
        .limit(60);
      if (error) throw error;
      const rows = (data as IncidentRow[]);
      const filtered = (lat != null && lon != null)
        ? rows.filter((r) => haversineKm(lat, lon, r.lat, r.lon) <= radiusKm)
        : rows;
      return filtered.slice(0, limit).map(nearbyHazardFromIncident);
    },
    [lat, lon, radiusKm, limit],
  );
}

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

// ──────────────────────────── notifications ────────────────────────────

export function useNotifications(): AsyncResource<Notification[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<Notification[]>(
    ['notifications', uid ?? ''],
    async () => {
      if (!uid) return [];
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', uid)
        .order('received_at', { ascending: false })
        .limit(100);
      if (error) throw error;
      return (data as NotificationRow[]).map(notificationFromRow);
    },
    [uid],
  );
}

/** Mark a single notification read via the RPC. */
export async function markNotificationRead(id: string): Promise<boolean> {
  const { data, error } = await supabase.rpc('mark_notification_read', { p_id: id });
  if (error) throw error;
  return data === true;
}

// ──────────────────────────── safety plan ──────────────────────────────

export function useActiveSafetyPlan(): AsyncResource<ActiveSafetyPlan | null> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<ActiveSafetyPlan | null>(
    ['activeSafetyPlan', uid ?? ''],
    async () => {
      if (!uid) return null;
      const { data, error } = await supabase
        .from('safety_plans')
        .select('*')
        .eq('user_id', uid)
        .is('closed_at', null)
        .order('started_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (error) throw error;
      if (!data) return null;
      return safetyPlanFromRow(data as SafetyPlanRow, 0);
    },
    [uid],
  );
}

// ──────────────────────────── emergency contacts ───────────────────────

export function useEmergencyContacts(): AsyncResource<EmergencyContact[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<EmergencyContact[]>(
    ['emergencyContacts', uid ?? ''],
    async () => {
      if (!uid) return [];
      const { data, error } = await supabase
        .from('emergency_contacts')
        .select('*')
        .eq('user_id', uid)
        .order('created_at', { ascending: true });
      if (error) throw error;
      return (data as EmergencyContactRow[]).map(emergencyContactFromRow);
    },
    [uid],
  );
}

// ──────────────────────────── route plans ──────────────────────────────

export function useSavedRoutePlans(): AsyncResource<RoutePlan[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<RoutePlan[]>(
    ['savedRoutePlans', uid ?? ''],
    async () => {
      if (!uid) return [];
      const { data: plans, error: pErr } = await supabase
        .from('route_plans')
        .select('*')
        .eq('user_id', uid)
        .order('created_at', { ascending: false });
      if (pErr) throw pErr;
      const planRows = (plans ?? []) as RoutePlanRow[];
      if (planRows.length === 0) return [];
      const ids = planRows.map((r) => r.id);
      const { data: wps, error: wErr } = await supabase
        .from('route_waypoints')
        .select('*')
        .in('route_id', ids);
      if (wErr) throw wErr;
      const wpRows = (wps ?? []) as RouteWaypointRow[];
      const byRoute = new Map<string, RouteWaypointRow[]>();
      for (const w of wpRows) {
        const list = byRoute.get(w.route_id) ?? [];
        list.push(w);
        byRoute.set(w.route_id, list);
      }
      return planRows.map((r) => routePlanFromRow(r, byRoute.get(r.id) ?? []));
    },
    [uid],
  );
}

// ──────────────────────────── incident timeline ────────────────────────

export function useIncidentTimeline(
  incidentId: string | null | undefined,
): AsyncResource<IncidentTimelineEvent[]> {
  return useSupabaseQuery<IncidentTimelineEvent[]>(
    ['incidentTimeline', incidentId ?? ''],
    async () => {
      if (!incidentId) return [];
      const { data, error } = await supabase
        .from('incident_events')
        .select('*')
        .eq('incident_id', incidentId)
        .order('at', { ascending: true });
      if (error) throw error;
      return (data as IncidentEventRow[]).map(incidentEventFromRow);
    },
    [incidentId],
  );
}

// ──────────────────────────── community posts ──────────────────────────

export function usePosts(): AsyncResource<FeedPost[]> {
  const uid = useAuth((s) => s.user?.id);
  return useSupabaseQuery<FeedPost[]>(
    ['posts', uid ?? ''],
    async () => {
      const { data, error } = await supabase
        .from('posts')
        .select(
          'id, author_id, text, location, stats, attachment, hazard, likes_count, comments_count, posted_at, author:profiles!posts_author_id_fkey(id, display_name, username, photo_url)',
        )
        .order('posted_at', { ascending: false })
        .limit(50);
      if (error) throw error;
      // Supabase types the `author:profiles!fk(…)` join as an array even
      // for a many-to-one relationship. Normalise to {…} | null before
      // handing to postFromRow.
      const rows = (data ?? []) as unknown as Array<
        Omit<PostWithAuthor, 'author'> & {
          author: NonNullable<PostWithAuthor['author']> | NonNullable<PostWithAuthor['author']>[] | null;
        }
      >;
      return rows.map((row) => {
        const author = Array.isArray(row.author) ? row.author[0] ?? null : row.author;
        return postFromRow({ ...row, author }, uid ?? null);
      });
    },
    [uid],
  );
}

/** Toggle the current user's like on a post; returns the new state. */
export async function togglePostLike(
  postId: string,
  currentlyLiked: boolean,
): Promise<boolean> {
  const { data: sess } = await supabase.auth.getSession();
  const uid = sess.session?.user.id;
  if (!uid) throw new Error('Not signed in');
  if (currentlyLiked) {
    const { error } = await supabase
      .from('post_likes')
      .delete()
      .eq('post_id', postId)
      .eq('user_id', uid);
    if (error) throw error;
    return false;
  }
  const { error } = await supabase
    .from('post_likes')
    .insert({ post_id: postId, user_id: uid });
  if (error) throw error;
  return true;
}

// ──────────────────────────── trail extras ─────────────────────────────

export function useTrailExtras(
  trailId: string | null | undefined,
): AsyncResource<TrailExtras | null> {
  return useSupabaseQuery<TrailExtras | null>(
    ['trailExtras', trailId ?? ''],
    async () => {
      if (!trailId) return null;
      const { data, error } = await supabase
        .from('v_trail_metadata')
        .select('*')
        .eq('trail_id', trailId)
        .maybeSingle();
      if (error) throw error;
      if (!data) return null;
      return trailExtrasFromViewRow(data as TrailMetadataViewRow);
    },
    [trailId],
  );
}

// ──────────────────────────── helpers ──────────────────────────────────

function num(v: unknown): number {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  return 0;
}

function useSupabaseQuery<T>(
  keyParts: readonly string[],
  fetcher: () => Promise<T>,
  deps: readonly unknown[],
): AsyncResource<T> {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const inflight = useRef('');

  const run = useCallback(async () => {
    const key = keyParts.join('|');
    inflight.current = key;
    setLoading(true);
    setError(null);
    try {
      const result = await fetcher();
      if (inflight.current === key) setData(result);
    } catch (err) {
      if (inflight.current === key) {
        setError(err instanceof Error ? err.message : String(err));
      }
    } finally {
      if (inflight.current === key) setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  useEffect(() => {
    void run();
  }, [run]);

  return { data, loading, error, refetch: run };
}
