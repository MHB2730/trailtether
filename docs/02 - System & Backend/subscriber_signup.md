---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/newsletter]
aliases: [public.subscriber_signup]
source_paths: []
---

# subscriber_signup

**RPC** `public.subscriber_signup(p_email text, p_source text='site', p_country text=null, p_ua text=null) returns jsonb` (SECURITY DEFINER)

Captures a newsletter email. Idempotent. Returns the row + status.

## Input

| Param | Note |
|---|---|
| `p_email` | normalized to citext lower |
| `p_source` | `site` / `apk_gate` / etc. |
| `p_country`, `p_ua` | audit context |

## Output

```json
{
  "id": "<uuid>",
  "token": "<confirmation_token uuid>",
  "status": "new_unconfirmed" | "already_subscribed" | "rate_limited"
}
```

## Side effects

- Inserts row in [[site_subscribers]] with `confirmed_at = null` if new
- If already exists (and unconfirmed), refreshes `confirmation_token` to extend the link's lifetime
- If already confirmed, returns `already_subscribed` (no email re-sent)

## Anti-abuse

Rate-limited internally (per-email) so a single email can't be re-signed-up dozens of times to spam confirmation emails.

## Callers

- [[subscribe.js]] (footer form)
- [[apk-download-gate]] (when user opts in)
