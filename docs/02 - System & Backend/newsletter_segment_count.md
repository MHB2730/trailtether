---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/newsletter, domain/admin]
aliases: [public.newsletter_segment_count]
source_paths: []
---

# newsletter_segment_count

**RPC** `public.newsletter_segment_count(p_filter jsonb) returns integer` (SECURITY DEFINER, admin-only via `is_admin()`)

Returns the count of [[site_subscribers]] matching a segment filter. Powers the admin's "X recipients match" preview before sending a blast.

## Input filter shape

```json
{
  "confirmed_only": true,    // default true if omitted
  "source": "apk_gate",      // optional
  "tags": ["beta-list"]      // optional, ANY match
}
```

## SQL logic

```sql
select count(*) from site_subscribers
where unsubscribed_at is null
  and (not v_confirmed_only or confirmed_at is not null)
  and (v_source is null or source = v_source)
  and (v_tags is null or tags && v_tags);
```

## Auth

`is_admin()` check raises 42501 for non-admins.

## Callers

- [[Hilltrek Admin Module]] newsletter editor — `refreshSegmentCount()` debounced on filter changes
- [[newsletter-send]] live mode reuses the same WHERE clause to fetch actual rows

## See also

- [[newsletter-send]]
- [[site_subscribers]]
