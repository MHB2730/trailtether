// ============================================================================
// finalize-orphan-hikes  —  Hilltrek Edge Function (cron janitor)
// ----------------------------------------------------------------------------
// When a Trailtether app records a hike, it streams individual fixes into
// team_member_track_points and is *supposed* to finalize the recording via
// HikeHistoryProvider.add(), which uploads a GPX to Storage and writes a
// recorded_trails row.
//
// In practice that finalization path doesn't always fire — app crashes, force
// closes, flat batteries, or simply users who never tap "stop & save". The
// data ends up stranded as a heap of track points with no recorded_trails
// row to give it shape.
//
// This function runs hourly via pg_cron and recovers those orphaned sessions:
//
//   1. Group track points per user, ordered by timestamp.
//   2. Detect session boundaries by time-gap (default >60 min between fixes).
//   3. For each session ended > stale_hours ago AND not already recovered:
//      - Compute bbox, distance (haversine), ascent/descent, duration.
//      - Generate a GPX string from the points.
//      - Upload to the recorded-trails bucket at <user_id>/<hike_id>.gpx.
//      - Insert a recorded_trails row tagged as "Recovered hike YYYY-MM-DD".
//
// hike_id on track points is unreliable (often NULL because the live-tracking
// upload writes points before a hike_id is assigned). So we synthesize a
// fresh hike_id per detected session and rely on the (user_id, hike_id)
// unique constraint plus an "already recovered" pre-check for idempotency.
//
// Required env vars:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (auto-injected by Supabase)
//   CRON_SECRET                              (matches the pg_cron caller's header)
//
// Verify_jwt: false. Auth is the X-Cron-Secret header check, not a JWT.
// ============================================================================

// deno-lint-ignore-file no-explicit-any
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET  = Deno.env.get("CRON_SECRET") ?? "";

// Tunables (defaults work for Hilltrek's current volume; can be overridden
// via the request body for one-off backfills / manual runs).
const DEFAULTS = {
  gap_minutes:  60,   // >60 min between consecutive fixes = session boundary
  stale_hours:  6,    // wait this long before assuming the session ended
  min_points:   5,    // skip sessions with fewer fixes (noise / accidental starts)
  lookback_days: 30,  // don't recover ancient orphans on every run; capped
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return j(405, { error: "POST only" });

  // Auth — cron-secret header must match, else 401 fast. Manual admin
  // invocations from the dashboard can pass the same header.
  const headerSecret = req.headers.get("x-cron-secret") ?? "";
  if (!CRON_SECRET || headerSecret !== CRON_SECRET) {
    return j(401, { error: "invalid or missing X-Cron-Secret" });
  }

  let opts: any = {};
  try { opts = await req.json(); } catch { /* empty body is fine */ }
  const gapMin    = clampInt(opts.gap_minutes,   DEFAULTS.gap_minutes,   5,  1440);
  const staleHrs  = clampInt(opts.stale_hours,   DEFAULTS.stale_hours,   1,  72);
  const minPoints = clampInt(opts.min_points,    DEFAULTS.min_points,    2,  10000);
  const lookback  = clampInt(opts.lookback_days, DEFAULTS.lookback_days, 1,  365);

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  // 1. Pull all track points in the lookback window. The query is bounded —
  //    a normal site will have hundreds of points, not millions, within 30d.
  const since = new Date(Date.now() - lookback * 86400_000).toISOString();
  const { data: points, error: tpErr } = await admin
    .from("team_member_track_points")
    .select("uid, lat, lon, altitude, timestamp, team_id, hike_id")
    .gte("timestamp", since)
    .order("uid", { ascending: true })
    .order("timestamp", { ascending: true });

  if (tpErr) return j(500, { error: "fetch track points failed", detail: tpErr.message });
  const pts = points ?? [];

  // 2. Group by uid and split into sessions by gap.
  const sessions: Array<{ uid: string; team_id: string | null; points: any[] }> = [];
  let current: { uid: string; team_id: string | null; points: any[] } | null = null;
  let prevTs = 0;
  for (const p of pts) {
    const ts = new Date(p.timestamp).getTime();
    const newUser = !current || current.uid !== p.uid;
    const bigGap  = !current || (ts - prevTs) > gapMin * 60_000;
    if (newUser || bigGap) {
      if (current && current.points.length >= minPoints) sessions.push(current);
      current = { uid: p.uid, team_id: p.team_id, points: [] };
    }
    current!.points.push(p);
    prevTs = ts;
  }
  if (current && current.points.length >= minPoints) sessions.push(current);

  // 3. Process each session that's old enough to be considered finished
  //    AND hasn't already been recovered.
  const result = { sessions_seen: sessions.length, created: 0, skipped: 0, errors: [] as any[] };
  const staleCutoff = Date.now() - staleHrs * 3600_000;

  for (const s of sessions) {
    try {
      const firstTs = new Date(s.points[0].timestamp).getTime();
      const lastTs  = new Date(s.points[s.points.length - 1].timestamp).getTime();
      if (lastTs > staleCutoff) { result.skipped++; continue; } // still in progress

      // Pre-check: do we already have a recorded_trails row for this user
      // whose timespan overlaps this session? Use a generous tolerance —
      // if anything claims this window, skip.
      const startISO = new Date(firstTs).toISOString();
      const endISO   = new Date(lastTs).toISOString();
      const { data: existing } = await admin
        .from("recorded_trails")
        .select("id, created_at")
        .eq("user_id", s.uid)
        .gte("created_at", new Date(firstTs - 3600_000).toISOString())
        .lte("created_at", new Date(lastTs  + 3600_000).toISOString())
        .limit(1);
      if (existing && existing.length > 0) { result.skipped++; continue; }

      // Compute metadata
      const stats = computeStats(s.points);
      const hikeId = crypto.randomUUID();
      const gpx    = buildGpx(s.points, `Recovered hike ${new Date(firstTs).toISOString().slice(0, 10)}`);
      const gpxPath = `${s.uid}/${hikeId}.gpx`;

      // Upload GPX. supabase-js v2 storage.upload returns { data, error }.
      const { error: uploadErr } = await admin.storage
        .from("recorded-trails")
        .upload(gpxPath, new TextEncoder().encode(gpx), {
          contentType: "application/gpx+xml",
          upsert: true,
        });
      if (uploadErr) {
        result.errors.push({ uid: s.uid, step: "upload", err: uploadErr.message });
        continue;
      }

      // Insert recorded_trails row. Same id used as hike_id so the existing
      // (user_id, hike_id) unique constraint provides idempotency on re-runs.
      const { error: insertErr } = await admin.from("recorded_trails").insert({
        id:                hikeId,
        hike_id:           hikeId,
        user_id:           s.uid,
        team_id:           s.team_id,
        name:              `Recovered hike ${new Date(firstTs).toISOString().slice(0, 10)}`,
        description:       `Auto-recovered from ${s.points.length} live-tracking points. Original hike record was not finalized in-app.`,
        distance_km:       stats.distance_km,
        ascent_m:          stats.ascent_m,
        descent_m:         stats.descent_m,
        duration_seconds:  Math.round((lastTs - firstTs) / 1000),
        activity_type:     "hike",
        point_count:       s.points.length,
        min_lat:           stats.min_lat,
        max_lat:           stats.max_lat,
        min_lon:           stats.min_lon,
        max_lon:           stats.max_lon,
        gpx_path:          gpxPath,
        sharing:           "private",
        created_at:        endISO,
      });
      if (insertErr) {
        // Best-effort cleanup so we don't orphan storage bytes.
        try { await admin.storage.from("recorded-trails").remove([gpxPath]); } catch {}
        result.errors.push({ uid: s.uid, step: "insert", err: insertErr.message });
        continue;
      }

      result.created++;
      console.log(`[finalize-orphan-hikes] recovered ${s.uid} ${startISO} → ${endISO} (${s.points.length} pts, ${stats.distance_km.toFixed(2)} km)`);
    } catch (e: any) {
      result.errors.push({ uid: s.uid, step: "exception", err: String(e?.message ?? e) });
    }
  }

  return j(200, result);
});

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------

function j(status: number, body: any): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function clampInt(v: any, def: number, lo: number, hi: number): number {
  const n = Number.isFinite(Number(v)) ? Math.floor(Number(v)) : def;
  return Math.max(lo, Math.min(hi, n));
}

function computeStats(points: any[]) {
  let minLat = points[0].lat, maxLat = minLat;
  let minLon = points[0].lon, maxLon = minLon;
  let distance_km = 0;
  let ascent_m = 0, descent_m = 0;

  for (let i = 0; i < points.length; i++) {
    const p = points[i];
    if (p.lat < minLat) minLat = p.lat;
    if (p.lat > maxLat) maxLat = p.lat;
    if (p.lon < minLon) minLon = p.lon;
    if (p.lon > maxLon) maxLon = p.lon;

    if (i > 0) {
      distance_km += haversineKm(points[i - 1].lat, points[i - 1].lon, p.lat, p.lon);
      const dEle = (Number(p.altitude) || 0) - (Number(points[i - 1].altitude) || 0);
      if (dEle > 0) ascent_m  += dEle;
      else          descent_m += -dEle;
    }
  }

  return {
    min_lat: minLat, max_lat: maxLat, min_lon: minLon, max_lon: maxLon,
    distance_km: round1(distance_km),
    ascent_m:    Math.round(ascent_m),
    descent_m:   Math.round(descent_m),
  };
}

// Haversine in kilometres.
function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
}
function toRad(d: number): number { return d * Math.PI / 180; }
function round1(n: number): number { return Math.round(n * 10) / 10; }

function buildGpx(points: any[], name: string): string {
  const xml = (s: string) =>
    String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  const parts: string[] = [];
  parts.push('<?xml version="1.0" encoding="UTF-8"?>');
  parts.push('<gpx version="1.1" creator="Trailtether (recovered)" xmlns="http://www.topografix.com/GPX/1/1">');
  parts.push('  <trk>');
  parts.push(`    <name>${xml(name)}</name>`);
  parts.push('    <type>hike</type>');
  parts.push('    <trkseg>');
  for (const p of points) {
    const ele = Number.isFinite(Number(p.altitude)) ? Number(p.altitude).toFixed(2) : '0';
    const ts  = new Date(p.timestamp).toISOString();
    parts.push(`      <trkpt lat="${p.lat}" lon="${p.lon}"><ele>${ele}</ele><time>${ts}</time></trkpt>`);
  }
  parts.push('    </trkseg>');
  parts.push('  </trk>');
  parts.push('</gpx>');
  return parts.join("\n");
}
