-- =====================================================================
-- Hourly pg_cron job that pokes the finalize-orphan-hikes edge function.
--
-- Reads the cron secret from Vault (where it already lives — see
-- 20260526_cron_secret_to_vault.sql) and passes it as the
-- X-Cron-Secret header. Uses pg_net for the HTTP call.
--
-- Cadence: minute 17 of every hour. The off-by-15-or-so offset stops
-- this colliding with the health-pinger (which fires every minute, top
-- of the second) and the nightly materialized-view refreshes (02:17,
-- 02:37 UTC) once those come online for The Berg, Live.
--
-- Applied via Supabase MCP on 2026-05-26.
-- =====================================================================

-- Belt-and-braces: drop any previous schedule with this name before
-- re-creating, so the migration is idempotent on re-runs.
select cron.unschedule(jobid)
from cron.job
where jobname = 'finalize-orphan-hikes-hourly';

select cron.schedule(
  'finalize-orphan-hikes-hourly',
  '17 * * * *',
  $cron$
  select net.http_post(
    url     := 'https://xuqmdujupbmxahyhkdwl.supabase.co/functions/v1/finalize-orphan-hikes',
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'X-Cron-Secret',  (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body                 := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $cron$
);
