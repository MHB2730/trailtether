---
tags: [type/model, layer/db, status/stable, domain/social]
aliases: [public.reviews]
source_paths: []
---

# reviews

Trail reviews. Authored by hikers after completing a trail.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| user_id | uuid → profiles.id |
| device_id | text (legacy fallback) |
| trail_id | text → trails.id |
| rating | int (1-5) |
| comment | text |
| safety_rating | int |
| difficulty_rating | int |
| photos | text[] (URLs) |
| created_at, updated_at | timestamptz |

## CRUD locations

- **Streamed** by [[review_service.dart]] per-trail
- **Created/Updated/Deleted** via [[review_provider.dart]] → service → Supabase
- **Read** by trail detail screens

## Auth

`isOwner()` check tolerates legacy device_id-only reviews (from before Supabase auth). Both must match user_id OR device_id to allow update/delete.
