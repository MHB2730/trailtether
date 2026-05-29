-- Advisor fix (lint 0011_function_search_path_mutable):
-- increment_recorded_trail_downloads was the only SECURITY DEFINER function
-- without an explicit search_path, leaving it open to search_path manipulation.
-- The body already fully-qualifies public.recorded_trails, so pin search_path
-- to empty. Behaviour is unchanged.
CREATE OR REPLACE FUNCTION public.increment_recorded_trail_downloads(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE public.recorded_trails
    SET download_count = COALESCE(download_count, 0) + 1
    WHERE id = p_id;
END;
$$;
