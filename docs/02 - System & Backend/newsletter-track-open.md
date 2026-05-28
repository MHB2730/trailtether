---
tags: [type/endpoint, layer/backend, status/stable, domain/newsletter]
aliases: [newsletter-track-open edge function]
source_paths: [supabase/functions/newsletter-track-open/index.ts]
---

# newsletter-track-open

**GET** `/functions/v1/newsletter-track-open?nid=<uuid>&sid=<bigint>`

Returns a 43-byte transparent 1×1 GIF. Embedded as `<img>` in sent newsletters to track opens.

## Auth

`verify_jwt: false` — public hit.

## Side effects

- Calls `newsletter_record_open(p_send_id)` RPC (graceful try/catch)
- Fallback: direct UPDATE on [[site_newsletter_sends]].`opened_at` if null

Either way: never throws. The pixel always returns even if DB is down (analytics never blocks).

> [!warning] Verify
> `newsletter_record_open` RPC may not exist (call is wrapped in try-or-noop). The fallback UPDATE handles missing RPC. Check if you want to harden the open-count logic.

## Consumers

- Email clients opening newsletters (auto-loaded image)
