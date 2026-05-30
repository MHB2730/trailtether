---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/pairing, hardware/garmin]
aliases: [public.mint_watch_token]
source_paths: []
---

# mint_watch_token

**RPC** `public.mint_watch_token(p_label text default 'Garmin Watch') returns text` (SECURITY DEFINER)

Issues a fresh device token for the [[Watch App Module|Garmin watch app]] bound to the calling user. The user pastes it into the Trailtether watch app's settings in **Connect IQ Mobile** (sideloaded apps don't appear in the Garmin Connect Mobile Connect IQ store).

## Behaviour

```sql
v_token := 'ttw_' || replace(gen_random_uuid()::text, '-', '');
insert into watch_devices (device_token, user_id, label)
values (v_token, auth.uid(), coalesce(nullif(p_label, ''), 'Garmin Watch'));
return v_token;
```

- Token format: `ttw_<32 hex chars>` (e.g. `ttw_df78433dbc56421f9aba494773c22543`).
- Each call mints a new row — users can have multiple watches paired simultaneously.
- `SECURITY DEFINER` so the watch_devices RLS (only the row's user can read) is bypassed at insert.

## Errors

- `not authenticated` — `auth.uid()` was null.

## Callers

- [[PairWatchScreen|pair_watch_screen.dart]] via [[WatchService|watch_service.dart::mintToken]].

## Related

- [[watch_devices]] — table the row lands in
- [[Watch App Module]] — where the token gets pasted
- [[set_watch_active_route]] — companion RPC for the "Send to watch" flow
