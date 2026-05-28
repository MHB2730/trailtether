---
tags: [type/model, layer/db, status/stable, domain/social]
aliases: [public.posts, public.post_comments, public.post_likes]
source_paths: []
---

# posts (+ post_comments + post_likes)

Long-form community posts (separate from [[community_activities]] which is an activity feed).

## Schema (posts, key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| user_id | uuid → profiles.id |
| title | text |
| body_md | text |
| photo_urls | text[] |
| like_count, comment_count | int (denormalised — kept in sync via triggers) |
| created_at, updated_at | timestamptz |

## Sibling tables

- `post_comments` — id, post_id, user_id, body, created_at; trigger `_touch_post_comments_counter` keeps `posts.comment_count` synced
- `post_likes` — id, post_id, user_id, created_at; trigger `_touch_post_likes_counter` keeps `posts.like_count` synced

## CRUD locations

- **Created** by community screens (e.g. tt_community_screen.dart)
- **Read** as community feed
- Triggers maintain denormalised counters

> [!warning] Verify
> Did not deeply read the community screen UI; the post/comment/like model is inferred from RPC names (`_touch_post_comments_counter`, etc.) confirmed in production.
