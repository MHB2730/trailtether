---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/recording, hardware/garmin]
aliases: [public.set_watch_active_route]
source_paths: []
---

# set_watch_active_route

**RPC** `public.set_watch_active_route(p_route_id text) returns void` (SECURITY DEFINER)

Sets the calling user's `watch_devices.active_route_id` so the next time the [[Watch App Module|watch]] calls [[watch-route]] with no body, that route is loaded as the planned course.

The watch's `RouteService.fetch()` runs on launch + on MENU-hold, so picking a route on the phone takes effect the next time the user opens the watch app (or holds UP).

## Behaviour

```sql
update public.watch_devices
   set active_route_id = p_route_id
 where user_id = auth.uid();
```

If the user has multiple paired watches, all of them get the same active route. (Per-device targeting would require accepting a `p_device_token` arg — not built.)

## Callers

- [[recorded_trails_screen.dart]] — "Send to watch" overflow option on a trail detail.
- (Implicit via [[WatchService|watch_service.dart::setActiveRoute]].)

## Related

- [[watch_devices]] — table being updated
- [[watch-route]] — endpoint that reads `active_route_id`
- [[Watch App Module]] — consumer
