-- =====================================================================
-- Supabase advisor cleanup
--
-- Three classes of warnings being addressed:
--
-- 1. function_search_path_mutable — 3 trigger functions don't pin their
--    search_path, so a malicious schema in front of `public` could hijack
--    their resolution. Lock to `public, pg_temp`.
--
-- 2. profiles_public + newsletter_segment_count — SECURITY DEFINER
--    functions that don't need to be reachable by anon. Revoke from anon
--    so the linter is happy and the attack surface shrinks.
--
-- 3. site_newsletters_touch_updated_at — pure trigger function; was never
--    meant to be RPC-callable. Revoke from both anon and authenticated.
--
-- Left intentionally alone (the advisor still flags these but they are
-- by design):
--   - is_admin()                    — returns bool, harmless to expose
--   - app_release_meta(text)        — public site reads version metadata
--   - get_order_for_confirmation()  — anon order-confirmation page
--   - place_order()                 — anon checkout
--   - subscriber_signup / confirm / unsubscribe — public forms / email links
--
-- Applied via Supabase MCP on 2026-05-26.
-- =====================================================================

-- 1. Lock search_path on trigger functions
alter function public.touch_updated_at()                    set search_path = public, pg_temp;
alter function public.set_updated_at()                      set search_path = public, pg_temp;
alter function public.recorded_trails_touch_updated_at()    set search_path = public, pg_temp;

-- 2. Revoke anon execute where it wasn't needed
revoke execute on function public.profiles_public()              from anon;
revoke execute on function public.newsletter_segment_count(jsonb) from anon;

-- 3. Pure trigger function — never meant to be RPC-callable
revoke execute on function public.site_newsletters_touch_updated_at() from anon, authenticated;
