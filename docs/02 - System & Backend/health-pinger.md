---
tags: [type/endpoint, layer/backend, status/stable, domain/ops]
aliases: [health-pinger edge function]
source_paths: [supabase/functions/health-pinger/index.ts]
---

# health-pinger

**POST** `/functions/v1/health-pinger` (called by pg_cron every minute)

Pings public + admin sites with HEAD requests, logs result to [[site_health_checks]].

## Auth

`verify_jwt: false` — uses `X-Cron-Secret` header check against `CRON_SECRET` env var (from `vault.decrypted_secrets`).

## Endpoints pinged

- `https://hilltrek.co.za`
- `https://admin.hilltrek.co.za`

Both with 15s timeout. Supabase itself is implicitly up if this function ran.

## Side effects

- Inserts one row per endpoint into [[site_health_checks]]: `{endpoint, ok, status_code, latency_ms, error}`

## Response

```json
{ "ok": true, "results": [...] }
```

## Cron

Set up by `20260526_finalize_orphan_hikes_cron.sql` and related pg_cron configurations. Runs every minute.

## Consumers

- pg_cron internal scheduler
- [[Hilltrek Admin Module]] dashboard reads [[site_health_checks]] for uptime UI
