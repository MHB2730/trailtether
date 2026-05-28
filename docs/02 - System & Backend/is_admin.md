---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/auth]
aliases: [public.is_admin]
source_paths: []
---

# is_admin

**RPC** `public.is_admin() returns boolean` (SECURITY DEFINER, lang sql)

The gate function used by virtually every admin-protected RLS policy + edge function.

## Definition

```sql
-- Conceptually:
create function public.is_admin() returns boolean
language sql security definer
as $$
  select exists(
    select 1 from public.admin_users
    where email = (auth.jwt() ->> 'email')
  );
$$;
```

## Callers

- **RLS policies** on [[trails]], [[site_orders]], [[site_settings]], etc.
- **Edge functions**: [[newsletter-send]], [[publish-site]] check it before doing admin work
- **Admin RPCs**: every `admin_trailtether_*` function raises `42501` if `!is_admin()`
- **Flutter**: [[auth_provider.dart]] caches `isAdmin` flag, used by [[MainPcShell]] to hide admin tabs
- **Admin SPA**: [[Hilltrek Admin Module]] calls this on load to gate the whole UI

## Admin allowlist

Backed by [[admin_users]]. To add an admin: insert a row with their auth email.

> [!note] Email-based, not uid-based
> If a user signs in with a different OAuth identity provider, they need a separate row (matching email).

## See also

- [[admin_users]] — the backing table
- [[Workflow - Auth]]
