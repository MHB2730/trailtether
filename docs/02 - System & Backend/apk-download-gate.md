---
tags: [type/endpoint, layer/backend, status/stable, domain/release]
aliases: [apk-download-gate edge function]
source_paths: [supabase/functions/apk-download-gate/index.ts]
---

# apk-download-gate

**POST** `/functions/v1/apk-download-gate`

Gated APK download for the public `/trailtether/` landing page. Email + T&Cs + Turnstile audit before serving the download URL.

## Request

```json
{
  "email": "alice@example.com",
  "terms_accepted": true,
  "newsletter_opt_in": true,
  "turnstile_token": "..."
}
```

## Response

```json
{
  "ok": true,
  "download_url": "https://...storage.supabase.co/.../trailtether-3.7.6.apk",
  "filename": "trailtether-3.7.6.apk",
  "version_name": "3.7.6",
  "version_code": 61,
  "sha256": "abc...",
  "subscriber_status": "new_unconfirmed"
}
```

## Auth

- `verify_jwt: true` (anon-callable via apikey)
- CORS: hilltrek allowlist (echoes Origin header)
- Rate-limited: 10/min per IP

## Validation chain

1. Email syntax + non-empty
2. `terms_accepted === true`
3. Turnstile token verification (Cloudflare API, **5s timeout** via AbortController — fixed in audit)
4. Fetch latest android row from [[app_releases]]
5. Optionally call [[subscriber_signup]] RPC if `newsletter_opt_in`
6. Insert audit row in [[apk_downloads]] (soft-fail — already passed gate)
7. Fire-and-forget call to [[subscriber-send-confirmation]] if a new subscriber row was created
8. Return download URL + sha256 to client

## Storage policy

The `app-releases` Storage bucket has LIST off but direct object read is open — so the in-app updater can also pull from it. See [[Build & Deploy]].

## Consumers

- `hilltrek-site/trailtether/index.html` modal form
- Indirectly: [[subscriber-send-confirmation]] (called downstream)
