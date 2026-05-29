-- Migration to document and version-control production Storage RLS policies.
-- Ensures storage security is fully portable and rebuildable in new environments.

-- Ensure RLS is active on storage objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 1. app-releases bucket (Public read, Admin-only write)
-- ---------------------------------------------------------------------------
CREATE POLICY "Public Access to app-releases"
ON storage.objects FOR SELECT
USING (bucket_id = 'app-releases');

CREATE POLICY "Admin Write Access to app-releases"
ON storage.objects FOR ALL
TO authenticated
USING (
  bucket_id = 'app-releases' 
  AND (auth.jwt() ->> 'email') LIKE '%@hilltrek.co.za' -- Gated to hilltrek admins
)
WITH CHECK (
  bucket_id = 'app-releases' 
  AND (auth.jwt() ->> 'email') LIKE '%@hilltrek.co.za'
);

-- ---------------------------------------------------------------------------
-- 2. recorded-trails bucket (Public read, Authenticated insert/update, Owner delete)
-- ---------------------------------------------------------------------------
CREATE POLICY "Public Read for recorded-trails"
ON storage.objects FOR SELECT
USING (bucket_id = 'recorded-trails');

CREATE POLICY "Authenticated Insert for recorded-trails"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'recorded-trails' 
  AND auth.uid()::text = (storage.foldername(name))[1] -- Files stored under hiker's uid folder, e.g. <uid>/track.gpx
);

CREATE POLICY "Owner Delete for recorded-trails"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'recorded-trails' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- ---------------------------------------------------------------------------
-- 3. gpx-uploads bucket (Public read, Authenticated/Admin write)
-- ---------------------------------------------------------------------------
CREATE POLICY "Public Read for gpx-uploads"
ON storage.objects FOR SELECT
USING (bucket_id = 'gpx-uploads');

CREATE POLICY "Authenticated/Admin Manage gpx-uploads"
ON storage.objects FOR ALL
TO authenticated
USING (bucket_id = 'gpx-uploads')
WITH CHECK (bucket_id = 'gpx-uploads');

-- ---------------------------------------------------------------------------
-- 4. incident-photos bucket (Authenticated insert, Public read)
-- ---------------------------------------------------------------------------
CREATE POLICY "Public Read for incident-photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'incident-photos');

CREATE POLICY "Authenticated Insert for incident-photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'incident-photos');

-- ---------------------------------------------------------------------------
-- 5. profile-photos bucket (Public read, Hiker-restricted manage)
-- ---------------------------------------------------------------------------
CREATE POLICY "Public Read for profile-photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-photos');

CREATE POLICY "Hiker Manage Own Profile Photos"
ON storage.objects FOR ALL
TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND auth.uid()::text = (storage.foldername(name))[1] -- Profile photos in <uid>/avatar.jpg
)
WITH CHECK (
  bucket_id = 'profile-photos'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
