---
tags: [type/config, layer/infra, status/stable]
aliases: [Env Vars, Secrets Inventory]
source_paths: [supabase/functions, scripts]
---

# Env Vars Inventory

All environment variables / secrets used across the codebase. None live in `.env` files in the repo (no `.env*` files present).

## Edge functions (Supabase Dashboard → Edge Functions → Secrets)

| Var | Used by | Purpose |
|---|---|---|
| `SUPABASE_URL` | All functions | Auto-injected by Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | All functions | Auto-injected; bypasses RLS |
| `SUPABASE_ANON_KEY` | [[apk-download-gate]], [[newsletter-send]] | For chained internal calls |
| `SMTP_HOST` | [[subscriber-send-confirmation]], [[newsletter-send]] | SMTP server |
| `SMTP_PORT` | same | typically 465 |
| `SMTP_USER` | same | also the FROM address |
| `SMTP_PASS` | same | |
| `TURNSTILE_SECRET` | [[apk-download-gate]] | Cloudflare Turnstile verify |
| `PAYFAST_MERCHANT_ID` | [[payfast-checkout]] | PayFast credentials |
| `PAYFAST_MERCHANT_KEY` | same | |
| `PAYFAST_PASSPHRASE` | same | optional |
| `PAYFAST_MODE` | same | `sandbox` (default) or `production` |
| `YOCO_SECRET_KEY` | [[yoco-checkout]] | `sk_test_*` or `sk_live_*` |
| `YOCO_WEBHOOK_SECRET` | [[yoco-webhook]] | HMAC signing secret |
| `ZAPPER_API_KEY` | [[zapper-checkout]] | |
| `ZAPPER_MERCHANT_ID` | same | |
| `ZAPPER_SITE_ID` | same | |
| `ZAPPER_SITE_REFERENCE` | same | |
| `ZAPPER_API_BASE_URL` | same | default `https://api.zapper.com` |
| `ZAPPER_WEBHOOK_SECRET` | [[zapper-webhook]] | HMAC signing secret |
| `CPANEL_HOST`, `CPANEL_USER`, `CPANEL_API_TOKEN`, `CPANEL_HOME` | [[publish-site]] | cPanel UAPI deploy |
| `CRON_SECRET` | [[health-pinger]], [[finalize-orphan-hikes]] | Header check for pg_cron calls. **Stored in `vault.secrets`**, decrypted via `vault.decrypted_secrets`. |

## Publish scripts (per-shell session)

Set with `$env:VAR = '...'` before running:

| Var | Used by |
|---|---|
| `CPANEL_HOST` | [[publish_site.ps1]] |
| `CPANEL_USER` | same |
| `CPANEL_API_TOKEN` | same |
| `HILLTREK_PUBLIC_DIR` | same |
| `HILLTREK_ADMIN_DIR` | same |
| (GitHub PAT for `gh` CLI) | [[publish_release.ps1]], [[publish_windows.ps1]] |

## Flutter app (compiled in)

| Constant | Source | Note |
|---|---|---|
| `kSupabaseUrl` | [[supabase_options.dart]] | Public — anon keys are safe to ship |
| `kSupabaseAnonKey` | same | |
| `kAllowDemoMode` | [[runtime_config.dart]] | `--dart-define=ALLOW_DEMO_MODE=true` |

> [!warning] Verify
> `supabase_options.dart` content not deeply read this session. Confirm only the anon key + URL are there (no service-role key).

## Signing certs

- Android keystore — outside repo, in build environment
- Windows .pfx — `%USERPROFILE%\.trailtether-signing\trailtether.pfx`, password passed via `--certificate-password` argument to [[publish_windows.ps1]] (NEVER in source)

## See also

- [[Edge Function Secrets]] — operational notes on Supabase's secrets dashboard
- [[Supabase Client Config]] — the runtime client setup
