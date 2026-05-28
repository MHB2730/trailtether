---
tags: [type/model, layer/db, status/stable, domain/social]
aliases: [public.community_activities]
source_paths: []
---

# community_activities

Activity feed entries. Strava-style "X completed a hike", "Y joined team Z", etc.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| user_id | uuid → profiles.id |
| user_name | text (denormalised) |
| team_id | uuid → teams.id (nullable) |
| type | text (hike_completed / team_joined / achievement_unlocked / etc.) |
| title | text |
| subtitle | text |
| timestamp | timestamptz |
| metadata | jsonb |

## CRUD locations

- **Created** by [[hike_history_provider.dart]] `_postCommunityActivity` (non-fatal — wrapped in try/catch)
- **Read** by [[community_provider.dart]] for the feed
- **Read** by [[TTHomeScreen]] Recent Activities section
- Likely also surfaces in posts / community screen

## Visibility

Open feed (anyone authenticated can read). Posts are visible to all users including non-team members.
