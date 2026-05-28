---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/notifications]
aliases: [public.mark_notification_read]
source_paths: []
---

# mark_notification_read

**RPC** `public.mark_notification_read(p_id uuid)` (SECURITY DEFINER, authenticated)

Sets `read_at = now()` on the caller's notification row in [[notifications]].

## Auth

Caller's uid must match the notification's `user_id` (enforced inside SECURITY DEFINER body).

## Callers

- Mobile notifications screen (bell icon dropdown)
