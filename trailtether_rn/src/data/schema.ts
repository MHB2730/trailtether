// Trailtether — Supabase row types.
//
// Hand-authored to match the **live schema** in the shared backend
// (`xuqmdujupbmxahyhkdwl`) as introspected on the day of writing. We don't
// auto-generate (`supabase gen types typescript`) so we can keep the type
// names + nullability hints idiomatic for our TS code and add commentary
// against the columns the design references.
//
// If the schema changes, update both this file and BLOCKERS.md.

export interface ProfileRow {
  id: string;
  username: string | null;
  display_name: string | null;
  email: string | null;
  photo_url: string | null;
  created_at: string | null;
  emergency_contact_email: string | null;
  emergency_contact_phone: string | null;
  fcm_token: string | null;
  is_admin: boolean;
  /** Added in profiles_extras_20260523. */
  region: string | null;
  bio: string | null;
  experience_level: 'beginner' | 'intermediate' | 'advanced' | 'expert' | null;
  interests: string[] | null;
}

export interface HikePlanRow {
  id: string;
  team_id: string | null;
  trail_id: string;
  trail_name: string;
  hike_date: string;            // timestamptz
  meeting_point: string | null;
  notes: string | null;
  created_by: string | null;
  created_at: string | null;
  status: string | null;        // 'planned' | 'confirmed' | 'cancelled' | …
}

export interface HikeHistoryRow {
  id: string;
  user_id: string;
  team_id: string | null;
  trail_id: string | null;
  name: string | null;
  distance_km: number | null;
  ascent_m: number | null;
  peaks_climbed: number | null;
  duration_seconds: number | null;
  activity_type: string;        // 'hike' | 'run' | …
  activity_context: string;     // 'personal' | 'team' | …
  points: unknown | null;       // jsonb — array of recording points
  created_at: string | null;
  avg_accuracy_m: number | null;
  best_accuracy_m: number | null;
  worst_accuracy_m: number | null;
  accepted_fixes: number | null;
  rejected_fixes: number | null;
}

export interface WeatherLocationRow {
  id: string;
  user_id: string;
  name: string;
  latitude: number;
  longitude: number;
  created_at: string | null;
}

export interface IncidentRow {
  id: string;
  lat: number;
  lon: number;
  type: string;                 // 'rockfall' | 'weather' | 'water' | …
  severity: string;             // 'low' | 'med' | 'high'
  description: string;
  incident_date: string;
  reported_at: string | null;
  device_id: string | null;
  created_by: string | null;
  trail_id: string | null;
  trail_name: string | null;
  flag_count: number | null;
  last_flag_at: string | null;
  is_emergency: boolean | null;
  status: string | null;
  metadata: unknown | null;
  title: string | null;
  geometry: unknown | null;
  assigned_to_uid: string | null;
  assigned_to_name: string | null;
  team_id: string | null;
  verified_uids: string[] | null;
  photo_url: string | null;
  /** Added by incidents_sos_extras_20260523 (BLOCKERS #17). */
  beacon_id: string | null;
  accuracy_m: number | null;
  altitude_m: number | null;
  responder_status: 'en route' | 'on scene' | 'cleared' | null;
  responder_eta_minutes: number | null;
  responder_distance_metres: number | null;
  responder_signal_bars: number | null;
}

export interface TeamMemberLocationRow {
  id: string;
  uid: string;
  team_id: string | null;
  display_name: string | null;
  hike_id: string | null;
  lat: number;
  lon: number;
  status: string;
  timestamp: string | null;
  heading: number;
  speed: number;
  altitude: number;
  /** Added by the v3 RN/Flutter rollout. Nullable for pre-upgrade rows. */
  battery_pct: number | null;
  /** 'wifi' | 'mobile' | 'none' | null */
  connectivity: string | null;
}

// ──────────────────────────────────────────────────────────────────────
// Tables added in the 2026-05-23 RN schema rollout. Each ships with RLS
// scoped to the owning user (plus watcher overrides where called for).
// ──────────────────────────────────────────────────────────────────────

/** notifications — per-user delivered events feed (BLOCKERS #12 RESOLVED). */
export interface NotificationRow {
  id: string;
  user_id: string;
  kind:
    | 'weather'
    | 'hazard'
    | 'team'
    | 'mention'
    | 'achievement'
    | 'system'
    | 'review';
  urgent: boolean;
  title: string;
  sub: string | null;
  action: string | null;
  read: boolean;
  received_at: string;
  metadata: unknown | null;
}

/** safety_plans — server-side tether for watcher PCs (BLOCKERS #15). */
export interface SafetyPlanRow {
  id: string;
  user_id: string;
  trail_id: string | null;
  trail_name: string | null;
  expected_return: string;
  backpack: string | null;
  tent: string | null;
  gear: unknown;            // jsonb — [{ id, label, sub, done }]
  watcher_uids: string[];
  last_ping: string | null;
  started_at: string;
  closed_at: string | null;
}

/** emergency_contacts — per-user multi-row personal contacts (BLOCKERS #16). */
export interface EmergencyContactRow {
  id: string;
  user_id: string;
  name: string;
  sub: string | null;
  phone: string;
  type: 'personal' | 'rescue' | 'ambulance';
  created_at: string;
}

/** route_plans — saved + draft route planner output (BLOCKERS #18). */
export interface RoutePlanRow {
  id: string;
  user_id: string;
  name: string;
  trail_id: string | null;
  hike_date: string | null;
  start_time: string | null;
  watcher_team_id: string | null;
  total_km: number | null;
  ascent_m: number | null;
  duration_minutes: number | null;
  notes: string | null;
  is_draft: boolean;
  created_at: string;
  updated_at: string;
}

/** route_waypoints — ordered waypoints inside a RoutePlanRow. */
export interface RouteWaypointRow {
  id: string;
  route_id: string;
  idx: number;
  num: string;
  type: 'start' | 'poi' | 'shelter' | 'end';
  name: string;
  sub: string | null;
  km: number;
  lat: number | null;
  lon: number | null;
}

/** incident_events — append-only dispatch timeline (BLOCKERS #17). */
export interface IncidentEventRow {
  id: string;
  incident_id: string;
  at: string;
  label: string;
  status: 'done' | 'active' | 'pending';
}

/** trail_metadata + the v_trail_metadata view (BLOCKERS #10). */
export interface TrailMetadataRow {
  trail_id: string;
  tech_grade: string | null;
  segments: unknown;       // jsonb array of {km0, km1, diff, name, body}
  prep: unknown | null;    // jsonb object {water, food, layers, …}
  tags: string[] | null;
  updated_at: string;
  updated_by: string | null;
}

export interface TrailMetadataViewRow extends TrailMetadataRow {
  avg_rating: number | null;
  reviews_count: number;
  open_incidents: number;
  hazards: unknown;        // jsonb array of {id, kind, description, severity, reported_at}
}

/** posts + child likes/comments (BLOCKERS #13). */
export interface PostRow {
  id: string;
  author_id: string;
  text: string;
  location: string | null;
  stats: unknown | null;
  attachment: unknown | null;
  hazard: boolean;
  likes_count: number;
  comments_count: number;
  posted_at: string;
}
export interface PostLikeRow {
  post_id: string;
  user_id: string;
  at: string;
}
export interface PostCommentRow {
  id: string;
  post_id: string;
  author_id: string;
  text: string;
  posted_at: string;
}

/** v_user_achievement_progress — per-user unlock state (BLOCKERS #5 partial). */
export interface AchievementProgressRow {
  user_id: string;
  achievement_id: string;
  progress: number;          // 0..1
  earned_at: string | null;
}

/** v_upcoming_hikes_for_user view (BLOCKERS #1 optimisation). */
export interface UpcomingHikeViewRow {
  id: string;
  trail_id: string;
  trail_name: string;
  hike_date: string;
  team_id: string | null;
  team_name: string | null;
  meeting_point: string | null;
  notes: string | null;
  status: string | null;
  created_by: string | null;
  created_at: string | null;
}
