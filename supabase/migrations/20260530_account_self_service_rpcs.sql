-- Account self-service RPCs for the hilltrek.co.za/account portal.
-- All SECURITY DEFINER, gated on auth.uid(), EXECUTE only for authenticated.
-- They operate ONLY on the calling user's own data — no admin surface.
-- Applied to prod 2026-05-30.

-- Read the signed-in user's email + notification settings + newsletter status.
CREATE OR REPLACE FUNCTION public.account_prefs()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid := auth.uid(); v_email text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;
  RETURN jsonb_build_object(
    'email', v_email,
    'push_enabled',       COALESCE((SELECT push_enabled       FROM notification_settings WHERE user_id = v_uid), true),
    'chat_notifications', COALESCE((SELECT chat_notifications FROM notification_settings WHERE user_id = v_uid), true),
    'feed_notifications', COALESCE((SELECT feed_notifications FROM notification_settings WHERE user_id = v_uid), true),
    'newsletter_known',      EXISTS (SELECT 1 FROM site_subscribers WHERE lower(email::text) = lower(v_email)),
    'newsletter_subscribed', EXISTS (SELECT 1 FROM site_subscribers WHERE lower(email::text) = lower(v_email) AND unsubscribed_at IS NULL)
  );
END $$;

-- Upsert the user's notification settings (update-then-insert; no ON CONFLICT dep).
CREATE OR REPLACE FUNCTION public.account_set_notifications(p_push boolean, p_chat boolean, p_feed boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  UPDATE notification_settings
     SET push_enabled = p_push, chat_notifications = p_chat,
         feed_notifications = p_feed, updated_at = now()
   WHERE user_id = v_uid;
  IF NOT FOUND THEN
    INSERT INTO notification_settings (user_id, push_enabled, chat_notifications, feed_notifications, updated_at)
    VALUES (v_uid, p_push, p_chat, p_feed, now());
  END IF;
END $$;

-- Subscribe / unsubscribe the user's email from the newsletter.
CREATE OR REPLACE FUNCTION public.account_set_newsletter(p_subscribed boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid := auth.uid(); v_email text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;
  IF v_email IS NULL THEN RAISE EXCEPTION 'no email on account'; END IF;
  IF p_subscribed THEN
    UPDATE site_subscribers SET unsubscribed_at = NULL
     WHERE lower(email::text) = lower(v_email);
    IF NOT FOUND THEN
      INSERT INTO site_subscribers (email, source, confirmed_at)
      VALUES (v_email, 'account_portal', now());
    END IF;
  ELSE
    UPDATE site_subscribers SET unsubscribed_at = now()
     WHERE lower(email::text) = lower(v_email) AND unsubscribed_at IS NULL;
  END IF;
END $$;

REVOKE EXECUTE ON FUNCTION public.account_prefs()                              FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.account_set_notifications(boolean,boolean,boolean) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.account_set_newsletter(boolean)             FROM anon, public;
GRANT EXECUTE ON FUNCTION public.account_prefs()                              TO authenticated;
GRANT EXECUTE ON FUNCTION public.account_set_notifications(boolean,boolean,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.account_set_newsletter(boolean)             TO authenticated;
