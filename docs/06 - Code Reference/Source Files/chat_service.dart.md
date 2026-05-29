---
tags: [type/source, layer/frontend, domain/chat]
aliases: [chat_service]
source_paths: [trailtether_app/lib/services/chat_service.dart]
---

# chat_service.dart

`ChatService` — Supabase Realtime stream for team chat.

## Key members

| Member | Role |
|---|---|
| `streamMessages(roomId)` | `Stream<List<ChatMessage>>` — Supabase `.stream()` on `chat_messages` filtered by `room_id`, ordered `sent_at` desc, limit 60 |
| `sendMessage(roomId, userId, text)` | `Future<void>` — inserts a row into `chat_messages` |
| `voteMessage(messageId, userId, direction)` | Up/down vote on a message |
| `toggleTodo(messageId, done)` | Toggle todo-item state on a message |
| `deleteMessage(messageId)` | Soft-delete (admin only) |

## Table

`chat_messages` — columns: `id`, `room_id`, `user_id`, `text`, `sent_at`, `vote_up`, `vote_down`, `is_todo`, `todo_done`.

## Used by

- [[chat_provider.dart]]
