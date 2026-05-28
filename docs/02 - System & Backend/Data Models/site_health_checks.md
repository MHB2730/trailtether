---
tags: [type/model, layer/db, status/stable, domain/ops]
aliases: [public.site_health_checks]
source_paths: []
---

# site_health_checks

Uptime ping log. One row per ping per endpoint per minute (when cron fires successfully).

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| endpoint | text (public / admin) |
| ok | bool |
| status_code | int |
| latency_ms | int |
| error | text (nullable) |
| created_at | timestamptz |

## CRUD locations

- **Inserted** by [[health-pinger]] edge function (cron, every 1 min)
- **Read** by [[Hilltrek Admin Module]] dashboard for uptime stats
- **Pruned** by `purge_old_analytics_and_health()`

## What it tracks

HEAD requests to:
- `https://hilltrek.co.za`
- `https://admin.hilltrek.co.za`

15s timeout. Supabase itself isn't pinged because "if this function ran, Supabase is up" (implicit).

## See also

- [[health-pinger]] edge function
