-- Create standard RPC for incrementing recorded trail download counters.
CREATE OR REPLACE FUNCTION public.increment_recorded_trail_downloads(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.recorded_trails
    SET download_count = COALESCE(download_count, 0) + 1
    WHERE id = p_id;
END;
$$;
