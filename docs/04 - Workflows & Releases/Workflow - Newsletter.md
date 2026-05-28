---
tags: [type/workflow, layer/frontend, status/stable, domain/newsletter]
aliases: [Newsletter flow, Subscribe + Confirm + Blast]
source_paths: [hilltrek-site/assets/js/subscribe.js, hilltrek-admin/app.js, supabase/functions/newsletter-send/index.ts, supabase/functions/subscriber-send-confirmation/index.ts]
---

# Workflow - Newsletter

Three sub-flows: **subscribe**, **confirm**, **send blast**.

## Subscribe + confirm (public)

```mermaid
sequenceDiagram
  actor U as Visitor
  participant Site as hilltrek.co.za footer
  participant RPC as subscriber_signup
  participant DB as site_subscribers
  participant SSC as subscriber-send-confirmation
  participant SMTP
  participant Confirm as /subscribe/confirm/
  participant CR as subscriber_confirm

  U->>Site: enter email + submit
  Site->>RPC: rpc('subscriber_signup', {p_email, p_source: 'site'})
  RPC->>DB: INSERT (or refresh confirmation_token if exists)
  RPC-->>Site: { id, token, status }
  alt new_unconfirmed
    Site->>SSC: invoke('subscriber-send-confirmation', {email, token})
    SSC->>DB: SELECT, verify token matches email
    SSC->>SMTP: send confirmation email
    SMTP-->>U: email with confirm link
    U->>Confirm: click /subscribe/confirm?token=...
    Confirm->>CR: rpc('subscriber_confirm', {p_token})
    CR->>DB: UPDATE confirmed_at = now()
    Confirm-->>U: "confirmed!"
  else already_subscribed
    Site-->>U: "already on the list"
  end
```

## Send blast (admin)

```mermaid
sequenceDiagram
  actor A as Admin
  participant SPA as hilltrek-admin
  participant NS as newsletter-send
  participant DB
  participant SMTP
  actor Sub as Subscribers

  Note over A,SPA: Admin drafts in /newsletters/new
  A->>SPA: edit subject + markdown body + segment filter
  SPA->>DB: upsert site_newsletters
  SPA->>RPC: rpc('newsletter_segment_count', {p_filter})
  RPC-->>SPA: N recipients
  A->>SPA: tap "Send Test"
  SPA->>NS: invoke('newsletter-send', {newsletter_id, mode: 'test'})
  NS->>NS: verify is_admin
  NS->>DB: load newsletter
  NS->>NS: recipients = [callerEmail]
  NS->>SMTP: send (test footer appended)
  NS-->>SPA: { ok, sent: 1, failed: 0 }

  Note over A,SPA: Test looks good, send live
  A->>SPA: tap "Send Live"
  SPA->>NS: invoke('newsletter-send', {newsletter_id, mode: 'live'})
  NS->>DB: SELECT site_subscribers matching segment_filter
  loop each subscriber
    NS->>DB: INSERT site_newsletter_sends (gets sid)
    NS->>NS: decorateBody (rewrite hrefs → newsletter-track-click, append unsub footer)
    NS->>SMTP: send
    alt success
      NS->>DB: UPDATE site_newsletter_sends SET sent_at
      NS->>Sub: email arrives
    else fail
      NS->>DB: UPDATE site_newsletter_sends SET error
    end
  end
  NS->>DB: UPDATE site_newsletters SET status='sent', counts
  NS-->>SPA: { ok, sent: 247, failed: 2, errors: [...] }
```

## Open + click tracking (downstream)

```mermaid
sequenceDiagram
  participant Email
  participant Pixel as newsletter-track-open
  participant Click as newsletter-track-click
  participant DB

  Note over Email: <img src="https://.../newsletter-track-open?nid=X&sid=Y">
  Email->>Pixel: GET (image load)
  Pixel->>DB: UPDATE site_newsletter_sends SET opened_at = now()
  Pixel-->>Email: 1x1 GIF

  Note over Email: <a href="https://.../newsletter-track-click?nid=X&sid=Y&url=Z">
  Email->>Click: GET (user clicks link)
  Click->>DB: UPDATE site_newsletter_sends SET clicked_at = now()
  Click-->>Email: 302 → Z
```

## Components

- [[subscribe.js]] (public footer)
- [[subscriber_signup]], [[subscriber_confirm]], [[subscriber_unsubscribe]] RPCs
- [[subscriber-send-confirmation]] (SMTP confirmation email)
- [[newsletter-send]] (blast)
- [[newsletter-track-open]], [[newsletter-track-click]] (analytics)
- [[Hilltrek Admin Module]] newsletter editor view
- [[newsletter_segment_count]] (preview count)

## Tables

- [[site_subscribers]] — the list
- [[site_newsletters]] — drafts + sent records
- [[site_newsletter_sends]] — per-recipient tracking

## See also

- [[denomailer]] — SMTP client used by both edge functions
