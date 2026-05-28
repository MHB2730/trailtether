---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/release]
aliases: [public.app_release_meta]
source_paths: []
---

# app_release_meta

**RPC** `public.app_release_meta(p_platform text default 'android') returns jsonb` (SECURITY DEFINER, anon-callable)

Returns the latest [[app_releases]] row metadata. Used by the in-app updater + the web `/trailtether/` page to display "Latest: v3.7.6".

## Output

```json
{
  "platform": "android",
  "version_name": "3.7.6",
  "version_code": 61,
  "download_url": "...",
  "sha256": "...",
  "released_at": "2026-05-27T..."
}
```

## Callers

- [[update_service.dart]] (in-app updater poll)
- `hilltrek-site/trailtether/index.html` (latest version banner)
