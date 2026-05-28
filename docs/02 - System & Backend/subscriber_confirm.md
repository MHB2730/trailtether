---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/newsletter]
aliases: [public.subscriber_confirm]
source_paths: []
---

# subscriber_confirm

**RPC** `public.subscriber_confirm(p_token uuid) returns jsonb` (SECURITY DEFINER)

Confirms a subscriber by setting `confirmed_at = now()` on the row matching `confirmation_token`.

## Output

```json
{ "ok": true, "email": "alice@example.com", "status": "confirmed" }
```

Or `{ ok: false, error: 'token_not_found' | 'already_confirmed' | 'unsubscribed' }`.

## Callers

- `hilltrek-site/subscribe/confirm/index.html` (when user clicks confirm link)

## See also

- [[site_subscribers]]
- [[subscriber_signup]]
- [[Workflow - Newsletter]]
