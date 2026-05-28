---
tags: [type/model, layer/db, status/stable, domain/newsletter]
aliases: [public.site_newsletters]
source_paths: []
---

# site_newsletters

Newsletter drafts + sent records. One row per newsletter campaign.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| subject | text |
| body_md | text (admin-authored markdown) |
| body_html | text (rendered by `marked` in admin) |
| body_text | text (HTML stripped) |
| segment_filter | jsonb (see [[newsletter_segment_count]]) |
| status | text (draft / sent) |
| scheduled_for | timestamptz |
| sent_at | timestamptz |
| sent_count, failed_count, recipient_count | int |
| created_by | uuid → profiles.id |
| created_at, updated_at | timestamptz |

## Trigger

`site_newsletters_touch_updated_at` — bumps updated_at on UPDATE.

## CRUD locations

- **Drafted** by [[Hilltrek Admin Module]] newsletter editor (`#/newsletters/new`)
- **Read** by [[newsletter-send]] edge function (loads body + segment_filter)
- **Updated** by [[newsletter-send]] after a live blast (status='sent', sent_at, counts)

## Segment filter shape

```json
{
  "confirmed_only": true,
  "source": "apk_gate",  // optional
  "tags": ["beta-list"]  // optional
}
```

Used by both [[newsletter_segment_count]] (preview count in admin) and [[newsletter-send]] (recipient query).

## See also

- [[site_newsletter_sends]] — per-recipient send rows
- [[Workflow - Newsletter]]
