-- Fix: solo hikes/walks fail to save with PostgrestException 23502
-- ("null value in column \"team_id\" of relation \"community_activities\"").
--
-- The on_hike_saved() AFTER INSERT trigger on hike_history inserts a matching
-- community_activities feed row but only sets (user_id, user_name, type,
-- title, subtitle). It never sets team_id/team_name because an activity that
-- isn't tied to a team legitimately has none. Both columns were created
-- NOT NULL, so the trigger's INSERT failed — and because the trigger runs in
-- the same transaction as the hike_history INSERT, the entire hike save
-- rolled back and surfaced to the app as "hike_history sync failed".
--
-- Relax both columns to nullable so team attribution is optional (matches the
-- documented data model and the solo-activity use case).
ALTER TABLE public.community_activities
  ALTER COLUMN team_id DROP NOT NULL;

ALTER TABLE public.community_activities
  ALTER COLUMN team_name DROP NOT NULL;
