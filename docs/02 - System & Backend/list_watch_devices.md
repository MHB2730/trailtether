---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/pairing, hardware/garmin]
aliases: [public.list_watch_devices]
source_paths: []
---

# list_watch_devices

**RPC** `public.list_watch_devices() returns jsonb` (SECURITY DEFINER)

Returns every [[watch_devices]] row for the calling user, enriched with the active-route name (joined from [[trails]] for text ids, [[recorded_trails]] for UUID ids). Used by the **Profile → Garmin watch** tile to render live status ("Instinct 3 (sideload) · synced 12m ago · route: Cathedral Peak").

## Output shape

```json
[
  {
    "device_token":  "ttw_df78433d…",
    "label":         "Instinct 3 (sideload)",
    "created_at":    "2026-05-30T07:05:02Z",
    "last_seen_at":  "2026-05-30T09:37:18Z",   // null until first sync
    "active_route_id":   "apes_pass",
    "active_route_name": "Apes Pass"
  }
]
```

Ordered newest-first by `created_at`. Empty array if the user has no paired watches.

## Active-route join

`active_route_id` is `text` in [[watch_devices]] so it can hold either a curated [[trails]] id (e.g. `apes_pass`) or a recorded-trail UUID. The join uses:

- `LEFT JOIN trails ON t.id = wd.active_route_id` — matches the curated id directly.
- `LEFT JOIN recorded_trails ON wd.active_route_id ~ '<uuid-regex>' AND rt.id = wd.active_route_id::uuid AND rt.user_id = auth.uid()` — guarded cast so a non-UUID id doesn't error.

The view returns `COALESCE(t.name, rt.name)`, so one of the two joins wins (or both are null when no route is active).

## Callers

- [[tt_profile_screen.dart]] via [[WatchService|watch_service.dart::listDevices]].

## Related

- [[watch_devices]] — source table
- [[mint_watch_token]] — creates rows
- [[set_watch_active_route]] — updates `active_route_id`
- [[Watch App Module]] — what `last_seen_at` ticks for
