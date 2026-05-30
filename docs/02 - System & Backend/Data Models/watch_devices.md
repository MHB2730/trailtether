---
tags: [type/table, layer/db, status/stable, domain/pairing, hardware/garmin]
aliases: [public.watch_devices]
source_paths: []
---

# watch_devices

Token → user_id mapping for paired Garmin watches. Lives at the seam between the [[Watch App Module]] (which sends a `x-device-token` header) and the [[hike_history]] / [[recorded_trails]] rows the user actually owns.

## Columns

| Column | Type | Notes |
|---|---|---|
| `device_token` | text, PK | `ttw_<32 hex>`, minted by [[mint_watch_token]] |
| `user_id` | uuid, FK auth.users | owner of every hike synced under this token |
| `label` | text | user-visible name (e.g. "Instinct 3 (sideload)") |
| `active_route_id` | text | set by [[set_watch_active_route]]; read by [[watch-route]] no-body fetch |
| `last_seen_at` | timestamptz | bumped by [[watch-ingest]] on every upload |
| `created_at` | timestamptz | row mint time |

## RLS

Owner-read only:

```sql
create policy watch_devices_select on public.watch_devices
  for select using (auth.uid() = user_id);
```

No insert/update/delete policies — edits go through `mint_watch_token` (SECURITY DEFINER) and `set_watch_active_route` (SECURITY DEFINER), or service-role from edge functions.

## Edge-function access

[[watch-ingest]] and [[watch-route]] both look up the row by `device_token` using the **service-role key** (bypasses RLS). The anon-key JWT only satisfies `verify_jwt`; the real auth is the token.

## Lifecycle

- **Mint** — phone app calls [[mint_watch_token]] → row inserted with `user_id = auth.uid()`.
- **Paste** — user copies the returned token into the watch's `pairingToken` setting in Connect IQ Mobile.
- **Use** — watch sends `x-device-token: <token>` on every sync / route fetch.
- **Revoke** — `delete from watch_devices where device_token = '...'`; subsequent sync attempts fail with 403 `unknown_device`.

## Related

- [[mint_watch_token]] — issuer
- [[set_watch_active_route]] — mutator
- [[watch-route]] / [[watch-ingest]] — readers
- [[Watch App Module]] — token consumer
