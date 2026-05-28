---
tags: [type/model, layer/db, status/stable, domain/auth]
aliases: [public.profiles]
source_paths: [supabase/migrations/20260526_profiles_pii_lockdown.sql]
---

# profiles

User profile table. One row per auth.users row, identified by uid (uuid).

## Schema (key columns)

| Column | Type | Note |
|---|---|---|
| id | uuid PK | matches auth.users.id |
| email | text | redundant copy of auth.users.email |
| display_name | text | |
| username | text | unique handle (used by `find_profile_by_username`) |
| photo_url | text | CDN URL with cache-bust query param |
| bio | text | |
| is_admin | bool | drives [[is_admin]] RPC + [[MainPcShell]] admin gating |
| stats_* | various | denormalised cached stats |
| created_at, updated_at | timestamptz | |

## RLS

Locked down by `20260526_profiles_pii_lockdown.sql`:
- Owner can SELECT/UPDATE their own row
- Admins can SELECT all
- Public (anon/authenticated non-owner) can only call [[profiles_public]] RPC which returns trimmed columns (name, photo, bio)

## CRUD locations

- **Created** by [[handle_new_user]] trigger on auth.users insert
- **Read** by [[auth_provider.dart]] (refreshes `isAdmin`), [[profile_provider.dart]] (avatar + name)
- **Updated** by [[profile_provider.dart]] (photo upload, name edit)
- **Deleted** rarely; cascade on auth.users delete

## Relationships

- Referenced by [[recorded_trails]].user_id, [[hike_history]].user_id, [[teams]].member_uids, etc.
- Photo stored in Supabase Storage `profile-photos` bucket

## See also

- [[profiles_public]] — the public-safe view + RPC
- [[admin_users]] — separate allowlist table (driven by email, not uid)
