---
tags: [type/model, layer/db, status/stable, domain/notifications]
aliases: [public.notifications]
source_paths: []
---

# notifications

In-app notification feed per user.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| user_id | uuid → profiles.id |
| type | text |
| title | text |
| body | text |
| metadata | jsonb |
| read_at | timestamptz (nullable) |
| created_at | timestamptz |

## CRUD locations

- **Created** by server-side triggers / cron / edge functions
- **Read** by mobile app `notifications_screen.dart`
- **Marked read** via [[mark_notification_read]] RPC

## Related

- [[notification_service.dart]] handles local OS notifications (not this table)
- This table is the in-app feed (the bell icon)
