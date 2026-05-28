---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/auth, domain/trigger]
aliases: [public.handle_new_user]
source_paths: []
---

# handle_new_user

**Trigger function** `public.handle_new_user()` (SECURITY DEFINER)

Fires on `INSERT` into `auth.users` (Supabase Auth's internal table). Creates the matching row in [[profiles]] with sensible defaults — display_name from auth metadata, email copied, photo_url from OAuth provider.

## Why this exists

Supabase Auth gives you `auth.users` for free, but your app needs more (display name, photo, achievements, etc.) in `public.profiles`. This trigger does the connection automatically on first sign-up.

## See also

- [[profiles]]
- [[Workflow - Auth]]
