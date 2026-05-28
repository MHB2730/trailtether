---
tags: [type/model, layer/db, status/stable, domain/newsletter]
aliases: [public.site_subscribers]
source_paths: []
---

# site_subscribers

Newsletter subscribers — emails captured from the site footer form, APK download gate, or admin import.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| email | citext UNIQUE |
| source | text (`site` / `apk_gate` / etc.) |
| tags | text[] (for segmentation) |
| ip_country | text |
| ua_hint | text |
| confirmed_at | timestamptz (nullable — null means pending double opt-in) |
| confirmation_token | uuid |
| unsubscribed_at | timestamptz (nullable) |
| unsubscribe_token | uuid |
| created_at | timestamptz |

## CRUD locations

- **Created** by [[subscriber_signup]] RPC (rate-limited, email-validated)
- **Confirmed** by [[subscriber_confirm]] RPC (validates token, sets `confirmed_at`)
- **Unsubscribed** by [[subscriber_unsubscribe]] RPC (sets `unsubscribed_at`)
- **Read** by [[newsletter_segment_count]] RPC + [[newsletter-send]] edge function (recipient list)
- **Read** by [[Hilltrek Admin Module]] subscriber browser view

## Double opt-in flow

1. Footer form on hilltrek.co.za → [[subscriber_signup]] → row inserted (confirmed_at = null) + confirmation_token set
2. [[subscriber-send-confirmation]] edge function sends the confirm email with link
3. User clicks → /subscribe/confirm?token=... → [[subscriber_confirm]] flips confirmed_at

## Used by

- [[Workflow - Newsletter]]
- [[subscribe.js]] (form submit)
- [[newsletter-send]] (blast recipient query)
