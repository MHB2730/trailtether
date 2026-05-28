---
tags: [type/model, layer/db, status/stable, domain/social, domain/realtime]
aliases: [public.chat_messages]
source_paths: []
---

# chat_messages

Real-time chat messages — either in a team room or the global community "general" room.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| room | text (`general` or team id) |
| team_id | uuid (nullable) |
| user_id | uuid → profiles.id |
| user_name | text (denormalised) |
| user_photo_url | text |
| type | text (`text` / `todo` / `poll`) |
| body | text |
| metadata | jsonb (todo state, poll options + votes) |
| created_at | timestamptz |

## CRUD locations

- **Subscribed** via Supabase Realtime by [[chat_provider.dart]] (reconnect 2-30s exponential backoff)
- **Inserted** by `send()` in [[chat_provider.dart]]
- **Updated** for `todo` toggles / `poll` votes via metadata mutation

## Used by

- `chat_screen.dart` (standalone view)
- `_StandaloneTeamChat` (in [[TTTeamScreen]])
- General room in community screen
