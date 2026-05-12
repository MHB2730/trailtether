-- ============================================================
--  Trailtether — MASTER SUPABASE SETUP (v3.0 - CONSOLIDATED)
--  Consolidated script for Tables, RLS, RPCs, and Realtime.
--  Strict Team Privacy & Mission Control ready.
-- ============================================================

-- ── 1. EXTENSIONS ───────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── 2. TABLES ────────────────────────────────────────────────

-- Profiles: Extended user data
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL PRIMARY KEY,
  username text UNIQUE,
  display_name text,
  photo_url text,
  bio text,
  email text,
  emergency_contact_email text,
  emergency_contact_phone text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Teams: User groups for hike planning
CREATE TABLE IF NOT EXISTS public.teams (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  description text,
  invite_code text UNIQUE NOT NULL,
  created_by uuid REFERENCES auth.users NOT NULL,
  member_uids uuid[] DEFAULT '{}',
  members jsonb DEFAULT '[]'::jsonb,
  total_distance_km double precision DEFAULT 0,
  total_ascent int DEFAULT 0,
  peaks_climbed int DEFAULT 0,
  member_count int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Hike History: Completed recordings
CREATE TABLE IF NOT EXISTS public.hike_history (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users NOT NULL,
  team_id uuid REFERENCES public.teams,
  trail_id text,
  name text,
  distance_km double precision DEFAULT 0.0,
  ascent_m int DEFAULT 0,
  peaks_climbed int DEFAULT 0,
  duration_seconds int DEFAULT 0,
  activity_type text NOT NULL DEFAULT 'hike',
  activity_context text NOT NULL DEFAULT 'personal',
  points jsonb,
  created_at timestamptz DEFAULT now()
);

-- Incidents: Community reports
CREATE TABLE IF NOT EXISTS public.incidents (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  type text NOT NULL,
  severity text NOT NULL,
  description text NOT NULL,
  lat double precision NOT NULL,
  lon double precision NOT NULL,
  trail_name text,
  created_by uuid REFERENCES auth.users NOT NULL,
  reported_by_name text,
  device_id text,
  flag_count int DEFAULT 0,
  last_flag_at timestamptz,
  is_emergency boolean DEFAULT false,
  status text DEFAULT 'active',
  verified_by_uids uuid[] DEFAULT '{}',
  verification_count int DEFAULT 0,
  is_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Reviews: Trail ratings
CREATE TABLE IF NOT EXISTS public.reviews (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  trail_id text NOT NULL,
  trail_name text,
  rating int CHECK (rating >= 1 AND rating <= 5),
  review_text text,
  condition text,
  user_id uuid REFERENCES auth.users NOT NULL,
  device_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Community Activities: Global feed
CREATE TABLE IF NOT EXISTS public.community_activities (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users,
  user_name text,
  type text NOT NULL,
  title text NOT NULL,
  subtitle text,
  metadata jsonb DEFAULT '{}',
  timestamp timestamptz DEFAULT now()
);

-- Chat Messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  room_id text NOT NULL,
  sender_id uuid REFERENCES auth.users NOT NULL,
  sender_name text NOT NULL,
  message_text text NOT NULL,
  type text DEFAULT 'text',
  payload jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.team_member_locations (
  uid uuid REFERENCES auth.users(id) NOT NULL PRIMARY KEY,
  team_id uuid REFERENCES public.teams(id),
  display_name text,
  lat double precision NOT NULL,
  lon double precision NOT NULL,
  heading double precision DEFAULT 0,
  speed double precision DEFAULT 0,
  altitude double precision DEFAULT 0,
  status text,
  hike_id uuid,
  timestamp timestamptz DEFAULT now()
);

-- User GPX Tracks: Personal/Team tracks
CREATE TABLE IF NOT EXISTS public.user_gpx_tracks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  shared_team_id uuid REFERENCES public.teams(id),
  name text NOT NULL,
  file_path text NOT NULL,
  bounds jsonb,
  created_at timestamptz DEFAULT now()
);

-- App Logs: System Diagnostics
CREATE TABLE IF NOT EXISTS public.app_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  uid uuid REFERENCES auth.users(id),
  team_id uuid REFERENCES public.teams(id),
  device_id text,
  platform text,
  tag text,
  message text,
  level text DEFAULT 'info',
  created_at timestamptz DEFAULT now()
);

-- Weather Locations
CREATE TABLE IF NOT EXISTS public.weather_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '',
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ── 3. INDEXES ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS hike_history_user_idx ON public.hike_history(user_id);
CREATE INDEX IF NOT EXISTS incidents_emergency_idx ON public.incidents(is_emergency) WHERE is_emergency = true;
CREATE INDEX IF NOT EXISTS chat_room_idx ON public.chat_messages(room_id);
CREATE INDEX IF NOT EXISTS profiles_username_idx ON public.profiles(username);
CREATE INDEX IF NOT EXISTS team_member_locations_team_idx ON public.team_member_locations(team_id);

-- ── 4. FUNCTIONS & TRIGGERS ──────────────────────────────────

-- Profile Auto-Creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (new.id, new.email, COALESCE(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)))
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Hike Stats Aggregator
CREATE OR REPLACE FUNCTION public.on_hike_saved()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.community_activities (user_id, user_name, type, title, subtitle)
  VALUES (
    new.user_id,
    (SELECT COALESCE(display_name, username) FROM public.profiles WHERE id = new.user_id),
    'hike_completed',
    'completed a ' || new.activity_type || '!',
    new.name || ' • ' || round(new.distance_km::numeric, 1) || 'km'
  );

  IF new.team_id IS NOT NULL THEN
    UPDATE public.teams
    SET 
      total_distance_km = total_distance_km + new.distance_km,
      total_ascent = total_ascent + new.ascent_m,
      peaks_climbed = peaks_climbed + new.peaks_climbed
    WHERE id = new.team_id;
  END IF;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS tr_on_hike_saved ON public.hike_history;
CREATE TRIGGER tr_on_hike_saved
  AFTER INSERT ON public.hike_history
  FOR EACH ROW EXECUTE FUNCTION public.on_hike_saved();

-- ── 5. RPCs (TEAM & MODERATION) ───────────────────────────────

-- Join Team
CREATE OR REPLACE FUNCTION public.join_team_by_invite_code(p_invite_code TEXT, p_member JSONB)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_team_id UUID;
    v_member_uid UUID := (p_member->>'uid')::UUID;
BEGIN
    SELECT id INTO v_team_id FROM teams WHERE invite_code = p_invite_code;
    IF v_team_id IS NULL THEN RETURN NULL; END IF;

    UPDATE teams
    SET 
        members = CASE WHEN NOT (member_uids @> ARRAY[v_member_uid]) THEN COALESCE(members, '[]'::jsonb) || jsonb_build_array(p_member) ELSE members END,
        member_uids = CASE WHEN NOT (member_uids @> ARRAY[v_member_uid]) THEN array_append(COALESCE(member_uids, '{}'::UUID[]), v_member_uid) ELSE member_uids END,
        member_count = CASE WHEN NOT (member_uids @> ARRAY[v_member_uid]) THEN member_count + 1 ELSE member_count END
    WHERE id = v_team_id;

    RETURN v_team_id;
END;
$$;

-- Verify Incident
CREATE OR REPLACE FUNCTION public.verify_incident(p_incident_id uuid)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    UPDATE incidents
    SET 
        verified_by_uids = array_append(verified_by_uids, v_user_id),
        verification_count = verification_count + 1,
        is_verified = (verification_count + 1 >= 3)
    WHERE id = p_incident_id 
      AND NOT (verified_by_uids @> ARRAY[v_user_id])
      AND created_by <> v_user_id;
END;
$$;

-- Flag Incident
CREATE OR REPLACE FUNCTION public.flag_incident(p_incident_id uuid)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    UPDATE incidents
    SET 
        flag_count = flag_count + 1,
        status = CASE WHEN flag_count + 1 >= 5 THEN 'flagged' ELSE status END
    WHERE id = p_incident_id;
END;
$$;

-- ── 6. ROW LEVEL SECURITY (STRICT TEAM PRIVACY) ───────────────

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hike_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_member_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_gpx_tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weather_locations ENABLE ROW LEVEL SECURITY;

-- 6.1 TEAM PRIVACY
DROP POLICY IF EXISTS teams_select ON public.teams;
CREATE POLICY teams_select ON public.teams FOR SELECT USING (auth.uid() = ANY(member_uids) OR auth.uid() = created_by);

-- 6.2 LOCATION PRIVACY (STRICT)
DROP POLICY IF EXISTS team_member_locations_select ON public.team_member_locations;
CREATE POLICY team_member_locations_select ON public.team_member_locations FOR SELECT
  USING (
    auth.uid() = uid 
    OR EXISTS (
      SELECT 1 FROM teams t
      WHERE auth.uid() = ANY(t.member_uids) AND team_member_locations.uid = ANY(t.member_uids)
    )
  );
DROP POLICY IF EXISTS team_member_locations_upsert ON public.team_member_locations;
CREATE POLICY team_member_locations_upsert ON public.team_member_locations FOR ALL
  USING (auth.uid() = uid) WITH CHECK (auth.uid() = uid);

-- 6.3 GPX SHARING
DROP POLICY IF EXISTS user_gpx_tracks_select ON public.user_gpx_tracks;
CREATE POLICY user_gpx_tracks_select ON public.user_gpx_tracks FOR SELECT
  USING (
    auth.uid() = user_id
    OR (shared_team_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM teams t WHERE t.id = shared_team_id AND auth.uid() = ANY(t.member_uids)
    ))
  );

-- 6.4 DIAGNOSTICS (TEAM AWARE)
DROP POLICY IF EXISTS app_logs_select ON public.app_logs;
CREATE POLICY app_logs_select ON public.app_logs FOR SELECT
  USING (
    auth.uid() = uid 
    OR (team_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM teams t WHERE t.id = app_logs.team_id AND auth.uid() = ANY(t.member_uids)
    ))
  );

-- 6.4b ADMIN ROLE — server-side flag, replaces the legacy hardcoded email check.
-- Defined BEFORE the policies below since they call public.is_admin().
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT COALESCE((SELECT is_admin FROM public.profiles WHERE id = auth.uid()), false);
$$;

-- 6.5 GENERAL POLICIES
DROP POLICY IF EXISTS profiles_select ON public.profiles;
CREATE POLICY profiles_select ON public.profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS profiles_update ON public.profiles;
CREATE POLICY profiles_update ON public.profiles FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS incidents_select ON public.incidents;
CREATE POLICY incidents_select ON public.incidents FOR SELECT USING (status <> 'flagged');
DROP POLICY IF EXISTS incidents_insert ON public.incidents;
CREATE POLICY incidents_insert ON public.incidents FOR INSERT WITH CHECK (auth.uid() = created_by);
DROP POLICY IF EXISTS chat_select ON public.chat_messages;
CREATE POLICY chat_select ON public.chat_messages FOR SELECT 
  USING (room_id = 'general' OR EXISTS (SELECT 1 FROM teams t WHERE t.id::text = room_id AND auth.uid() = ANY(member_uids)));
DROP POLICY IF EXISTS chat_insert ON public.chat_messages;
CREATE POLICY chat_insert ON public.chat_messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
DROP POLICY IF EXISTS chat_delete ON public.chat_messages;
CREATE POLICY chat_delete ON public.chat_messages FOR DELETE
  USING (auth.uid() = sender_id OR public.is_admin());

-- 6.6 ADDITIONAL POLICIES
DROP POLICY IF EXISTS hike_history_select ON public.hike_history;
CREATE POLICY hike_history_select ON public.hike_history FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS hike_history_insert ON public.hike_history;
CREATE POLICY hike_history_insert ON public.hike_history FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS reviews_select ON public.reviews;
CREATE POLICY reviews_select ON public.reviews FOR SELECT USING (true);
DROP POLICY IF EXISTS reviews_insert ON public.reviews;
CREATE POLICY reviews_insert ON public.reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS reviews_update ON public.reviews;
CREATE POLICY reviews_update ON public.reviews FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS reviews_delete ON public.reviews;
CREATE POLICY reviews_delete ON public.reviews FOR DELETE
  USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS community_activities_select ON public.community_activities;
CREATE POLICY community_activities_select ON public.community_activities FOR SELECT USING (true);

-- 6.7 INCIDENT MODERATION POLICIES (uses public.is_admin() defined in 6.4b above)
-- Incidents: creators may update their own; admins (server-side flag) may update any.
DROP POLICY IF EXISTS incidents_update ON public.incidents;
CREATE POLICY incidents_update ON public.incidents FOR UPDATE
  USING (auth.uid() = created_by OR public.is_admin())
  WITH CHECK (auth.uid() = created_by OR public.is_admin());

-- Incidents: creators may delete their own; admins may delete any. This is the policy
-- that fixes the gap where the admin "delete incident" flow relied on the application
-- layer alone — without this row, the DELETE silently fails under RLS.
DROP POLICY IF EXISTS incidents_delete ON public.incidents;
CREATE POLICY incidents_delete ON public.incidents FOR DELETE
  USING (auth.uid() = created_by OR public.is_admin());

DROP POLICY IF EXISTS weather_locations_all ON public.weather_locations;
CREATE POLICY weather_locations_all ON public.weather_locations FOR ALL USING (auth.uid() = user_id);

-- ── 7. REALTIME & PERMISSIONS ───────────────────────────────

DO $$
BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.incidents; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.team_member_locations; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.app_logs; EXCEPTION WHEN OTHERS THEN NULL; END;
END $$;

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
