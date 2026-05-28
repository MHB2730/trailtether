---
tags: [type/model, layer/db, status/stable, domain/admin, domain/auth]
aliases: [public.admin_users]
source_paths: []
---

# admin_users

Allowlist table backing the [[is_admin]] RPC. Email-based — not tied to uid.

## Schema

| Column | Type | Note |
|---|---|---|
| email | text PK | matches the user's auth.users email |
| created_at | timestamptz | |

(Confirmed table exists in production; full schema not in migrations — predates folder.)

## How `is_admin()` works

```sql
-- Conceptually:
select exists(
  select 1 from public.admin_users
  where email = (auth.jwt() ->> 'email')
);
```

A user becomes admin by adding their email here. Currently: `matt@hilltrek.co.za`. Per memory, `bremnermail@gmail.com` is the user's personal account (non-admin context for Trailtether app).

## Important

- Email-based, not uid-based — same person with different OAuth providers can either share or not share admin depending on email.
- No row-level RLS — the table is read by the SECURITY DEFINER `is_admin()` function, which is what enforces gating.

## CRUD locations

- **Read** by every `is_admin()` invocation across:
  - Edge functions ([[newsletter-send]], [[publish-site]])
  - RLS policies on [[trails]], [[site_orders]], [[site_settings]], etc.
  - [[auth_provider.dart]] refresh
  - [[Hilltrek Admin Module]] auth gate
- **Updated** rarely — by manually inserting/deleting rows in the Supabase dashboard or via [[AdminSettingsTab]]

## See also

- [[is_admin]] — the RPC
- [[Workflow - Auth]]
- [[MainPcShell]] — UI gating via `adminOnly` nav flag
