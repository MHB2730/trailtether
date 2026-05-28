---
tags: [type/model, layer/db, status/stable, domain/analytics]
aliases: [public.site_analytics_events]
source_paths: []
---

# site_analytics_events

POPIA-safe pageview + event analytics for hilltrek.co.za. No PII stored — IP is hashed via SHA-256.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| session_id | text (per-tab, sessionStorage) |
| path | text (URL path, sliced to 500) |
| referrer | text (sliced to 500) |
| country | text (cf-ipcountry header) |
| device_type | text (mobile / tablet / desktop — parsed from UA) |
| browser | text |
| os | text |
| ua_hash | text (SHA-256 of `${ua}|${ip}|hilltrek-salt`, sliced to 16 chars) |
| event_type | text (pageview / click / etc.) |
| event_data | jsonb |
| created_at | timestamptz |

## CRUD locations

- **Inserted** by [[analytics-ingest]] edge function
- **Read** by [[Hilltrek Admin Module]] dashboard
- **Pruned** by `purge_old_analytics_and_health()` cron job

## Privacy

- No cookies (session_id is sessionStorage — cleared on tab close)
- No raw IP (hashed with a static salt)
- Country only via CF header, never reverse-geocoded
- User agent stored but no fingerprinting beyond device_type/browser/os parse

## See also

- [[analytics.js]] (client-side beacon)
- [[analytics-ingest]] (server endpoint)
