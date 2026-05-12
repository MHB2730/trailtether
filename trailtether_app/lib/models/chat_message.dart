import 'package:uuid/uuid.dart';

// ── Enums ──────────────────────────────────────────────────────────────────────
enum ChatMessageType { text, todo, poll, system }

// ── Chat To-Do ─────────────────────────────────────────────────────────────────
class ChatTodo {
  final String id;
  final String text;
  final bool done;
  final String assignedTo;
  final String createdBy;

  const ChatTodo({
    required this.id,
    required this.text,
    this.done = false,
    this.assignedTo = '',
    this.createdBy = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'done': done,
        'assignedTo': assignedTo,
        'createdBy': createdBy,
      };

  factory ChatTodo.fromMap(Map<String, dynamic> m) => ChatTodo(
        id: m['id'] as String? ?? const Uuid().v4(),
        text: m['text'] as String? ?? '',
        done: m['done'] as bool? ?? false,
        assignedTo: m['assignedTo'] as String? ?? '',
        createdBy: m['createdBy'] as String? ?? '',
      );

  ChatTodo copyWith({bool? done}) => ChatTodo(
        id: id,
        text: text,
        done: done ?? this.done,
        assignedTo: assignedTo,
        createdBy: createdBy,
      );
}

// ── Poll Option ────────────────────────────────────────────────────────────────
class PollOption {
  final String id;
  final String text;
  final List<String> voterUids;

  const PollOption(
      {required this.id, required this.text, this.voterUids = const []});

  Map<String, dynamic> toMap() =>
      {'id': id, 'text': text, 'voterUids': voterUids};

  factory PollOption.fromMap(Map<String, dynamic> m) => PollOption(
        id: m['id'] as String? ?? const Uuid().v4(),
        text: m['text'] as String? ?? '',
        voterUids: (m['voterUids'] as List<dynamic>?)?.cast<String>() ?? [],
      );

  PollOption withVote(String uid, bool add) {
    final updated = List<String>.from(voterUids);
    if (add) {
      if (!updated.contains(uid)) updated.add(uid);
    } else {
      updated.remove(uid);
    }
    return PollOption(id: id, text: text, voterUids: updated);
  }
}

// ── Chat Poll ──────────────────────────────────────────────────────────────────
class ChatPoll {
  final String question;
  final List<PollOption> options;
  final bool closed;

  const ChatPoll(
      {required this.question, required this.options, this.closed = false});

  Map<String, dynamic> toMap() => {
        'question': question,
        'options': options.map((o) => o.toMap()).toList(),
        'closed': closed,
      };

  factory ChatPoll.fromMap(Map<String, dynamic> m) => ChatPoll(
        question: m['question'] as String? ?? '',
        options: (m['options'] as List<dynamic>?)
                ?.map((o) => PollOption.fromMap(o as Map<String, dynamic>))
                .toList() ??
            [],
        closed: m['closed'] as bool? ?? false,
      );

  int get totalVotes => options.fold(0, (s, o) => s + o.voterUids.length);
}

// ── Chat Message ───────────────────────────────────────────────────────────────
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final ChatMessageType type;
  final ChatTodo? todo;
  final ChatPoll? poll;
  final String roomId;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.type = ChatMessageType.text,
    this.todo,
    this.poll,
    required this.roomId,
  });

  ChatMessage copyWith({ChatTodo? todo, ChatPoll? poll}) => ChatMessage(
        id: id,
        senderId: senderId,
        senderName: senderName,
        text: text,
        timestamp: timestamp,
        type: type,
        todo: todo ?? this.todo,
        poll: poll ?? this.poll,
        roomId: roomId,
      );

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'type': type.name,
        'roomId': roomId,
        if (todo != null) 'todo': todo!.toMap(),
        if (poll != null) 'poll': poll!.toMap(),
      };

  /// Construct from a Supabase row.  Handles both the new snake_case column
  /// names (Supabase) and the legacy camelCase keys (demo / in-memory).
  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) {
    // message type
    final typeStr =
        m['message_type'] as String? ?? m['type'] as String? ?? 'text';
    final type = ChatMessageType.values.firstWhere((t) => t.name == typeStr,
        orElse: () => ChatMessageType.text);

    // timestamp — ISO-8601 string from Supabase or epoch int from demo
    final tsRaw = m['sent_at'] ?? m['timestamp'];
    DateTime ts;
    if (tsRaw is String) {
      ts = DateTime.parse(tsRaw).toLocal();
    } else if (tsRaw is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(tsRaw);
    } else {
      ts = DateTime.now();
    }

    // text — Supabase column is message_text, legacy is text
    final text = m['message_text'] as String? ?? m['text'] as String? ?? '';

    // todo / poll — stored as JSONB (already decoded by Supabase client)
    final todoRaw = m['todo_data'] ?? m['todo'];
    final pollRaw = m['poll_data'] ?? m['poll'];

    return ChatMessage(
      id: id,
      senderId: m['sender_id'] as String? ?? m['senderId'] as String? ?? '',
      senderName:
          m['sender_name'] as String? ?? m['senderName'] as String? ?? 'Hiker',
      text: text,
      timestamp: ts,
      type: type,
      todo: todoRaw != null
          ? ChatTodo.fromMap(todoRaw as Map<String, dynamic>)
          : null,
      poll: pollRaw != null
          ? ChatPoll.fromMap(pollRaw as Map<String, dynamic>)
          : null,
      roomId: m['room_id'] as String? ?? m['roomId'] as String? ?? '',
    );
  }
}

// ── Chat Room ──────────────────────────────────────────────────────────────────
class ChatRoom {
  final String id;
  final String name;
  final String emoji;
  final String description;

  const ChatRoom({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
  });

  static const List<ChatRoom> defaultRooms = [
    ChatRoom(
        id: 'general',
        name: 'General',
        emoji: '💬',
        description: 'General hiking chat'),
    ChatRoom(
        id: 'next_hike',
        name: 'Next Hike',
        emoji: '🎯',
        description: 'Plan the next adventure'),
    ChatRoom(
        id: 'conditions',
        name: 'Trail Conditions',
        emoji: '🌤',
        description: 'Real-time condition reports'),
    ChatRoom(
        id: 'gear',
        name: 'Gear Talk',
        emoji: '🎒',
        description: 'Kit, gear and reviews'),
    ChatRoom(
        id: 'challenge',
        name: 'Peak Challenge',
        emoji: '🏔',
        description: 'Summit achievements'),
  ];
}
