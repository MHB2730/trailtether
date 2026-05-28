---
tags: [type/endpoint, layer/backend, status/stable, domain/newsletter]
aliases: [newsletter-track-click edge function]
source_paths: [supabase/functions/newsletter-track-click/index.ts]
---

# newsletter-track-click

**GET** `/functions/v1/newsletter-track-click?nid=<uuid>&sid=<bigint>&url=<encoded>`

302-redirect with click logging. Hit when a recipient clicks a link in a sent newsletter.

## Auth

`verify_jwt: false` — public hit from any inbox.

## Anti-open-redirect

`url` param is validated against an allowlist:
- Exact: `hilltrek.co.za`, `xuqmdujupbmxahyhkdwl.supabase.co`
- Suffix: `.hilltrek.co.za`

Anything else → falls back to homepage `https://hilltrek.co.za` (not 4xx — clicking shouldn't dead-end for the user). Off-allowlist destinations are logged for audit.

## Side effects

- Updates [[site_newsletter_sends]].`clicked_at` to now (only if null — first click only)
- 302 redirect to dest

## Caching

`Cache-Control: no-store` so analytics aren't bypassed by proxies.

## Consumers

- Recipients clicking links in emails sent by [[newsletter-send]]
