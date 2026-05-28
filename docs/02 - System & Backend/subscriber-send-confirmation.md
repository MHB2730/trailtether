---
tags: [type/endpoint, layer/backend, status/stable, domain/newsletter]
aliases: [subscriber-send-confirmation edge function]
source_paths: [supabase/functions/subscriber-send-confirmation/index.ts]
---

# subscriber-send-confirmation

**POST** `/functions/v1/subscriber-send-confirmation`

Sends the double-opt-in confirmation email after [[subscriber_signup]] inserts a row in [[site_subscribers]].

## Request

```json
{
  "email": "alice@example.com",
  "token": "<uuid from subscriber_signup>"
}
```

## Response

```json
{ "ok": true, "status": "sent" }
```

## Auth

- `verify_jwt: false` (anon-callable)
- Anti-abuse: looks up [[site_subscribers]] row by email + verifies `confirmation_token` matches the provided token. Random tokens won't trigger spam emails to arbitrary addresses.
- Rate-limited per-IP: 5/min

## Env vars

Same SMTP setup as [[newsletter-send]]:
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`

## Body

Branded HTML template with:
- Confirm URL: `https://hilltrek.co.za/subscribe/confirm/?token=<confirmation_token>`
- Unsubscribe URL: `https://hilltrek.co.za/subscribe/unsubscribe/?token=<unsubscribe_token>`

Plain-text fallback included.

## Consumers

- [[subscribe.js]] (after `subscriber_signup` RPC returns)
- [[apk-download-gate]] (when user opts in to newsletter on APK download)

## See also

- [[Workflow - Newsletter]]
- [[subscriber_signup]], [[subscriber_confirm]]
