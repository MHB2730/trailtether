import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import '../core/constants.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Supabase-backed chat service.
/// Schema: chat_messages table with room_id column.
class ChatService {
  /// Stream the last 60 messages for a room, oldest first.
  /// Uses Supabase Realtime for live updates.
  static Stream<List<ChatMessage>> streamMessages(String roomId) {
    return _db
        .from(kColChat)
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('sent_at', ascending: false)
        .limit(60)
        .map((rows) => rows
            .map((r) => ChatMessage.fromMap(r['id'] as String, r))
            .toList()
            .reversed
            .toList());
  }

  static Future<void> sendMessage(
    String roomId, {
    required String senderId,
    required String senderName,
    required String text,
    ChatMessageType type = ChatMessageType.text,
    ChatTodo? todo,
    ChatPoll? poll,
  }) async {
    await _db.from(kColChat).insert({
      'room_id': roomId,
      'sender_id': senderId.isEmpty ? null : senderId,
      'sender_name': senderName,
      'message_text': text,
      'message_type': type.name,
      'sent_at': DateTime.now().toIso8601String(),
      if (todo != null) 'todo_data': todo.toMap(),
      if (poll != null) 'poll_data': poll.toMap(),
    });
  }

  /// Delete every message in [roomId]. RLS restricts who can do this:
  /// global admins for any room; team creators for their team's room.
  static Future<void> clearRoom(String roomId) async {
    await _db.from(kColChat).delete().eq('room_id', roomId);
  }

  static Future<void> updateMessage(
    String roomId,
    String messageId,
    Map<String, dynamic> fields,
  ) async {
    // Translate legacy document-style dot keys to Supabase column names.
    final mapped = <String, dynamic>{};
    fields.forEach((key, value) {
      if (key == 'todo.done') {
        mapped['_todo_done_patch'] = value;
      } else if (key.startsWith('poll.')) {
        mapped['poll_data'] = value;
      } else {
        mapped[key] = value;
      }
    });

    if (mapped.containsKey('_todo_done_patch')) {
      final done = mapped.remove('_todo_done_patch') as bool;
      final row = await _db
          .from(kColChat)
          .select('todo_data')
          .eq('id', messageId)
          .single();
      final todo = Map<String, dynamic>.from(
        (row['todo_data'] as Map<String, dynamic>? ?? {}),
      );
      todo['done'] = done;
      mapped['todo_data'] = todo;
    }

    if (mapped.isNotEmpty) {
      await _db.from(kColChat).update(mapped).eq('id', messageId);
    }
  }
}
