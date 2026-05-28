---
tags: [type/workflow, layer/frontend, status/stable, domain/release]
aliases: [APK download gate]
source_paths: [supabase/functions/apk-download-gate/index.ts, hilltrek-site/trailtether]
---

# Workflow - APK Download

Public-site flow for a visitor to download the Trailtether Android APK. Gated by T&Cs + Turnstile, optional newsletter opt-in.

```mermaid
sequenceDiagram
  actor V as Visitor
  participant Site as /trailtether/
  participant CF as Cloudflare Turnstile
  participant Gate as apk-download-gate
  participant SS as subscriber_signup (RPC)
  participant DB as apk_downloads + app_releases + site_subscribers
  participant SSC as subscriber-send-confirmation

  V->>Site: click "Download for Android"
  Site->>V: open modal (email + T&Cs + newsletter + Turnstile widget)
  V->>CF: solve Turnstile
  CF-->>Site: token
  V->>Site: submit form
  Site->>Gate: POST { email, terms_accepted, newsletter_opt_in, turnstile_token }
  Gate->>Gate: rate limit (10/min/IP)
  Gate->>CF: verify token (5s timeout via AbortController)
  CF-->>Gate: success / fail
  alt verify fail
    Gate-->>Site: 403 { error: 'captcha_failed' }
  end
  Gate->>DB: SELECT latest app_releases WHERE platform='android'
  DB-->>Gate: release row
  alt newsletter_opt_in
    Gate->>SS: rpc('subscriber_signup', { email, p_source: 'apk_gate' })
    SS-->>Gate: { token, status }
    Gate->>SSC: fire-and-forget invoke (sends confirmation email)
  end
  Gate->>DB: INSERT apk_downloads (audit trail)
  Gate-->>Site: { ok, download_url, filename, sha256, version_name }
  Site->>V: trigger browser download of download_url
  Note over V: User installs APK. In-app updater takes over from here.
```

## Components

- `hilltrek-site/trailtether/index.html` — the landing + modal
- [[apk-download-gate]] — server-side gate
- [[subscriber_signup]] + [[subscriber-send-confirmation]] — opt-in chain
- [[app_releases]] — the manifest table

## Tables

- [[app_releases]] — read
- [[apk_downloads]] — written (audit)
- [[site_subscribers]] — written if opt-in

## Privacy controls

- Email captured for newsletter opt-in is real (no hashing)
- IP recorded for abuse investigation (not hashed because this is legal-evidence audit, not analytics)
- IP country from `cf-ipcountry`
- UA stored but truncated to 500 chars

## Rate limit

10/min per IP. Each request even before reaching Turnstile/DB is rate-checked.

## See also

- [[Workflow - Release]] (how new APKs land in [[app_releases]] table)
- [[Audit Findings]] (Turnstile timeout fix already applied)
