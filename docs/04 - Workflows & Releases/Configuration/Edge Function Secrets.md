---
tags: [type/config, layer/backend, status/stable]
aliases: [Edge Secrets, Function Secrets]
source_paths: [supabase/functions]
---

# Edge Function Secrets

Operational notes for managing Supabase Edge Function secrets.

## Where they live

Supabase Dashboard → **Edge Functions** → **Secrets** (project-wide, shared across all functions).

## Setting

Two ways:

```bash
# Supabase CLI
supabase secrets set SMTP_HOST=smtp.example.com

# Dashboard
Edge Functions → Secrets → Add new secret
```

## Reading (in function code)

```ts
const SMTP_HOST = Deno.env.get('SMTP_HOST')!;
```

The `!` non-null assertion is liberal — most functions throw if the env var is missing. Some have explicit `?? ''` fallbacks (e.g. `TURNSTILE_SECRET || ''`) so they can fail closed at request time rather than at startup.

## Inventory

See [[Env Vars Inventory]] for the full list.

## CRON_SECRET via vault.secrets

The `cron_secret` used by [[health-pinger]] and [[finalize-orphan-hikes]] is **not** a standard edge-function secret. It lives in `vault.secrets` and the cron job reads it via `vault.decrypted_secrets`. Migration `20260526_cron_secret_to_vault.sql` did this move.

> [!note] Why vault?
> Originally stored in [[site_settings]] (world-readable). Moved to vault so leaked-DB-read can't reveal it. The edge functions themselves still receive it via `Deno.env.get('CRON_SECRET')` — the indirection is at the cron-job level.

## Rotation guidance

| Secret | Rotation cadence |
|---|---|
| `SUPABASE_SERVICE_ROLE_KEY` | Rotate if leaked; otherwise rare |
| `SMTP_PASS` | When changing provider or quarterly |
| `PAYFAST_PASSPHRASE` | If suspected compromised — coordinate with PayFast |
| `YOCO_SECRET_KEY` | If suspected; rotate webhook secret too |
| `YOCO_WEBHOOK_SECRET` | Quarterly is fine |
| `ZAPPER_WEBHOOK_SECRET` | Quarterly is fine |
| `TURNSTILE_SECRET` | Rotate via Cloudflare dashboard |
| `CRON_SECRET` | When the suspect cron-secret leaks; otherwise quarterly |
| `CPANEL_API_TOKEN` | Quarterly + after every team member leaves |

After rotating, redeploy any function that reads the variable (or just bump the dashboard — Supabase picks it up on next invocation).
