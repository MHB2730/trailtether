---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/newsletter]
aliases: [public.subscriber_unsubscribe]
source_paths: []
---

# subscriber_unsubscribe

**RPC** `public.subscriber_unsubscribe(p_token uuid) returns jsonb` (SECURITY DEFINER)

Sets `unsubscribed_at = now()` on the row matching `unsubscribe_token`. Idempotent.

## Output

```json
{ "ok": true, "status": "unsubscribed" }
```

## Callers

- `hilltrek-site/subscribe/unsubscribe/index.html` (from email footer link)

## See also

- [[site_subscribers]]
- [[Workflow - Newsletter]]
