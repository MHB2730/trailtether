-- =====================================================================
-- Move cron_secret out of public.site_settings into Supabase Vault.
--
-- Background
--   public.site_settings had a "Public reads settings" RLS policy
--   (using = true, granted to {anon, authenticated}). The row
--   key='cron_secret' was therefore readable by anyone holding the
--   project anon key — which is embedded in every page of the public
--   static site. The value was used by the health_pinger_every_minute
--   pg_cron job to authenticate to the health-pinger edge function.
--
-- Fix
--   1. Generate a fresh cron_secret value and store it in vault.secrets.
--   2. Rewrite the pg_cron job to read from vault.decrypted_secrets
--      instead of public.site_settings.
--   3. Delete the cron_secret row from public.site_settings (the old
--      value should be treated as compromised).
--   4. Replace the public read policy with a key-whitelist that only
--      exposes the rows the public static site actually needs:
--        - shipping_flat_rate_cents (cart + checkout flat-rate fetch)
--        - maintenance_mode         (maintenance-gate.js)
--
-- Out-of-band step
--   After this migration applies, update the health-pinger edge
--   function secret to the new value:
--     supabase secrets set CRON_SECRET=<new-value> \
--       --project-ref xuqmdujupbmxahyhkdwl
--   (or via Dashboard → Edge Functions → health-pinger → Secrets).
--   Read the new value with:
--     select decrypted_secret from vault.decrypted_secrets
--      where name = 'cron_secret';
--   ≤60s of failed health pings may occur while the two sides are
--   out of sync.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Create (or leave alone) the vault secret. Idempotent: re-applying
--    this migration must NOT rotate the value silently, since that
--    would desync the function env.
-- ---------------------------------------------------------------------
do $$
declare
  v_existing uuid;
begin
  select id into v_existing from vault.secrets where name = 'cron_secret';
  if v_existing is null then
    perform vault.create_secret(
      encode(gen_random_bytes(16), 'hex'),
      'cron_secret',
      'Shared secret sent as X-Cron-Secret by health_pinger_every_minute pg_cron job to the health-pinger edge function. Must match the CRON_SECRET env var on that function.'
    );
  end if;
end$$;

-- ---------------------------------------------------------------------
-- 2. Rewrite the pg_cron job to read from vault instead of site_settings.
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from cron.job where jobname = 'health_pinger_every_minute') then
    perform cron.unschedule('health_pinger_every_minute');
  end if;
end$$;

select cron.schedule(
  'health_pinger_every_minute',
  '* * * * *',
  $job$
    select net.http_post(
      url := 'https://xuqmdujupbmxahyhkdwl.supabase.co/functions/v1/health-pinger',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', coalesce(
          (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret'),
          ''
        )
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    );
  $job$
);

-- ---------------------------------------------------------------------
-- 3. Drop the leaked row.
-- ---------------------------------------------------------------------
delete from public.site_settings where key = 'cron_secret';

-- ---------------------------------------------------------------------
-- 4. Replace the wildcard public read with a key whitelist.
-- ---------------------------------------------------------------------
drop policy if exists "Public reads settings"         on public.site_settings;
drop policy if exists "Public reads maintenance_mode" on public.site_settings;
drop policy if exists "Public reads public settings"  on public.site_settings;

create policy "Public reads public settings" on public.site_settings
  for select to anon, authenticated
  using (key in ('shipping_flat_rate_cents', 'maintenance_mode'));
