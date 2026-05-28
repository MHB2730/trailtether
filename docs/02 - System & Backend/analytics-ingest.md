---
tags: [type/endpoint, layer/backend, status/stable, domain/analytics]
aliases: [analytics-ingest edge function]
source_paths: [supabase/functions/analytics-ingest/index.ts]
---

# analytics-ingest

**POST** `/functions/v1/analytics-ingest`

POPIA-safe pageview/event beacon. Inserts a row into [[site_analytics_events]] with hashed UA+IP — no PII.

## Request

```json
{
  "session_id": "...",   // per-tab sessionStorage
  "path": "/hikes/mj-cave",
  "referrer": "https://google.com",
  "ua": "Mozilla/5.0 ...",
  "event_type": "pageview",
  "event_data": null
}
```

## Response

`204 No Content` on success.

## Auth

- `verify_jwt: false`
- CORS: hilltrek allowlist with `Access-Control-Allow-Credentials: true` (because `sendBeacon` always includes credentials)
- Rate limit: 120/min per IP

## Privacy controls

- UA hashed with `${ua}|${ip}|hilltrek-salt` → SHA-256 → first 16 chars
- Country from `cf-ipcountry` header (Cloudflare)
- No raw IP stored
- No cookies

## Consumers

- [[analytics.js]] on every page of [[Hilltrek Site Module]]
