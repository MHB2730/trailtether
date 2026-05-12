-- MIGRATION: Hardening Trailtether Admin Capabilities
-- This script adds missing columns required for the advanced admin features without breaking existing app logic.

-- 1. Hardening the Incidents Table
DO $$ 
BEGIN 
    -- Add is_emergency if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incidents' AND column_name='is_emergency') THEN
        ALTER TABLE incidents ADD COLUMN is_emergency BOOLEAN DEFAULT FALSE;
    END IF;

    -- Add metadata for geo-fencing and extra data
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incidents' AND column_name='metadata') THEN
        ALTER TABLE incidents ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
    END IF;

    -- Add status tracking
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incidents' AND column_name='status') THEN
        ALTER TABLE incidents ADD COLUMN status TEXT DEFAULT 'open';
    END IF;

    -- Add title for zones and events
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incidents' AND column_name='title') THEN
        ALTER TABLE incidents ADD COLUMN title TEXT;
    END IF;

    -- Add reported_at for ordering
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incidents' AND column_name='reported_at') THEN
        ALTER TABLE incidents ADD COLUMN reported_at TIMESTAMPTZ DEFAULT NOW();
    END IF;

    -- Add incident_date for legacy/mobile compatibility
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incidents' AND column_name='incident_date') THEN
        ALTER TABLE incidents ADD COLUMN incident_date TEXT;
    END IF;
END $$;

-- 2. Hardening the GPX Library Table
DO $$ 
BEGIN 
    -- Add description for trails
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gpx_uploads' AND column_name='description') THEN
        ALTER TABLE gpx_uploads ADD COLUMN description TEXT;
    END IF;

    -- Add display_name for user-friendly trail names
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gpx_uploads' AND column_name='display_name') THEN
        ALTER TABLE gpx_uploads ADD COLUMN display_name TEXT;
    END IF;

    -- Add difficulty rating
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gpx_uploads' AND column_name='difficulty') THEN
        ALTER TABLE gpx_uploads ADD COLUMN difficulty TEXT DEFAULT 'Moderate';
    END IF;

    -- Add distance tracking
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gpx_uploads' AND column_name='distance_km') THEN
        ALTER TABLE gpx_uploads ADD COLUMN distance_km FLOAT DEFAULT 0.0;
    END IF;

    -- Add point count for complexity analysis
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gpx_uploads' AND column_name='point_count') THEN
        ALTER TABLE gpx_uploads ADD COLUMN point_count INTEGER DEFAULT 0;
    END IF;

    -- Add ascent/descent
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gpx_uploads' AND column_name='ascent_m') THEN
        ALTER TABLE gpx_uploads ADD COLUMN ascent_m INTEGER DEFAULT 0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gpx_uploads' AND column_name='descent_m') THEN
        ALTER TABLE gpx_uploads ADD COLUMN descent_m INTEGER DEFAULT 0;
    END IF;

    -- Add created_at if missing (Supabase usually handles this but ensure it exists for ordering)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gpx_uploads' AND column_name='created_at') THEN
        ALTER TABLE gpx_uploads ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();
    END IF;

    -- Ensure foreign key for profiles join
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'gpx_uploads_user_id_fkey'
    ) THEN
        ALTER TABLE gpx_uploads 
        ADD CONSTRAINT gpx_uploads_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 3. Ensure Realtime is enabled for the new features (Idempotent)
DO $$ 
BEGIN 
    -- Add incidents if missing
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'incidents'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE incidents;
    END IF;

    -- Add gpx_uploads if missing
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'gpx_uploads'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE gpx_uploads;
    END IF;

    -- Add team_member_locations if missing
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'team_member_locations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE team_member_locations;
    END IF;
END $$;
