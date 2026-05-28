---
tags: [type/model, layer/db, status/stable, domain/newsletter]
aliases: [public.site_newsletter_sends]
source_paths: []
---

# site_newsletter_sends

Per-recipient send row. Created when [[newsletter-send]] sends a live blast to a subscriber. Used for tracking opens, clicks, bounces.

## Schema (key columns)

| Column | Type |
|---|---|
| id | bigint PK |
| newsletter_id | uuid → site_newsletters.id |
| subscriber_id | uuid → site_subscribers.id |
| email | text (denormalised for audit) |
| sent_at | timestamptz |
| bounced_at | timestamptz |
| opened_at | timestamptz |
| open_count | int |
| clicked_at | timestamptz |
| click_count | int |
| error | text (SMTP error message if send failed) |
| created_at | timestamptz |

## CRUD locations

- **Inserted** by [[newsletter-send]] before SMTP send (so click-tracking has a sid even if send throws)
- **Updated** by [[newsletter-send]] after SMTP succeeds (sets `sent_at`) or fails (sets `error`)
- **Updated** by [[newsletter-track-open]] when tracking pixel hits (sets `opened_at` if null)
- **Updated** by [[newsletter-track-click]] when a link is clicked (sets `clicked_at` if null)
- **Read** by [[Hilltrek Admin Module]] newsletter detail view for per-send stats

## Note: counters not incremented

The schema has `open_count` + `click_count` but the current `newsletter-track-*` functions only `set opened_at = now() where opened_at is null` — they don't increment counts on repeat hits. Per-recipient unique opens are still captured.
