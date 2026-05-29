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
create or replace function public.is_admin() returns boolean
language sql stable security definer
set search_path to 'public'
as $$
  select exists(
    select 1 from public.admin_users
    where user_id = auth.uid()
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

Backed by [[admin_users]]. To add an admin, insert a row keyed on their **`user_id`** (`auth.users.id`):

```sql
insert into public.admin_users (user_id, email, notes)
select id, email, '<why>' from auth.users where email = '<their email>'
on conflict (user_id) do nothing;
```

> [!warning] uid-based, not email-based — and separate from `profiles.is_admin`
> `is_admin()` matches `admin_users.user_id = auth.uid()`; the `email` column is informational only. A user under a different identity (different `auth.users.id`) needs a new row.
>
> The PC app gates **tab visibility** on a *different* flag — `profiles.is_admin` (cached in [[auth_provider.dart]], used by [[MainPcShell]]). These two admin signals are independent and **both** must be set for a working PC Trails admin. (2026-05-29: `bremnermail@gmail.com` had `profiles.is_admin=true` but no `admin_users` row, so the Trails editor showed yet every write was silently filtered by RLS to 0 rows.)

## See also

- [[admin_users]] — the backing table
- [[Workflow - Auth]]
