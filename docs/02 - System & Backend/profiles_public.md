---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/auth]
aliases: [public.profiles_public]
source_paths: [supabase/migrations/20260526_profiles_pii_lockdown.sql]
---

# profiles_public

**RPC** `public.profiles_public() returns setof <row>` (SECURITY DEFINER)

Returns the public-safe view of [[profiles]]: id, display_name, photo_url, bio. **Not** email, is_admin, raw metadata.

## Why

After `20260526_profiles_pii_lockdown.sql`, direct SELECT on [[profiles]] is owner-only + admin-only. This RPC is the public read path — anyone can call it but the result is column-pruned.

## Callers

- [[chat_provider.dart]] (resolving user names in chat rooms)
- Any UI that needs a non-owner user's display info

## See also

- [[profiles]]
- [[is_admin]]
