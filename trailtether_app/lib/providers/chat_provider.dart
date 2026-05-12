import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/app_messenger.dart';
import '../core/runtime_config.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _uuid = Uuid();

class ChatProvider extends ChangeNotifier {
  static const String _currentRoom = 'general';

  bool _sending = false;
  List<ChatMessage> _liveMessages = [];
  StreamSubscription<List<ChatMessage>>? _sub;

  // Reconnection state
  int _retryCount = 0;
  Timer? _reconnectTimer;

  final List<ChatMessage> _demoMessages = [];

  String get currentRoom => _currentRoom;
  bool get sending => _sending;
  List<ChatMessage> get messages =>
      List.unmodifiable(kSupabaseAvailable ? _liveMessages : _demoMessages);

  ChatProvider() {
    if (kSupabaseAvailable) {
      _subscribeToRoom(_currentRoom);
    }
  }

  void _subscribeToRoom(String roomId) {
    _reconnectTimer?.cancel();
    _sub?.cancel();

    debugPrint(
        'ChatProvider: Subscribing to room $roomId (attempt ${_retryCount + 1})');

    _sub = ChatService.streamMessages(roomId).listen(
      (msgs) {
        // Detect new messages for notification
        if (_liveMessages.isNotEmpty &&
            msgs.length > _liveMessages.length &&
            kSupabaseAvailable) {
          final last = msgs.last;
          final currentUser = Supabase.instance.client.auth.currentUser;
          // Only notify if it's from someone else
          if (last.senderId != currentUser?.id) {
            NotificationService.instance.showNotification(
              id: last.id.hashCode,
              title: 'New message from ${last.senderName}',
              body: last.text,
            );
          }
        }

        _liveMessages = msgs;
        _retryCount = 0; // Reset on success
        notifyListeners();
      },
      onError: (e) {
        debugPrint('ChatProvider stream error: $e');
        _handleStreamError(roomId);
      },
      onDone: () {
        debugPrint('ChatProvider stream closed (done)');
        _handleStreamError(roomId);
      },
      cancelOnError: false,
    );
  }

  void _handleStreamError(String roomId) {
    _retryCount++;
    // Exponential backoff: 2s, 4s, 8s, 16s... max 30s
    final delay = Duration(seconds: (_retryCount * 2).clamp(2, 30));

    debugPrint(
        'ChatProvider: Connection lost. Retrying in ${delay.inSeconds}s...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => _subscribeToRoom(roomId));

    // Notify UI of the issue but only show toast after multiple failures
    if (_retryCount > 1) {
      showGlobalToast('Chat connection unstable. Retrying...', isError: true);
    }
    notifyListeners();
  }

  // â”€â”€ Send â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> sendText({
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    _setSending(true);
    try {
      if (kSupabaseAvailable) {
        await ChatService.sendMessage(
          _currentRoom,
          senderId: senderId,
          senderName: senderName,
          text: text.trim(),
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 150));
        _demoAdd(ChatMessage(
          id: _uuid.v4(),
          senderId: senderId,
          senderName: senderName,
          text: text.trim(),
          timestamp: DateTime.now(),
          roomId: _currentRoom,
        ));
      }
    } catch (e) {
      debugPrint('ChatProvider send error: $e');
      showGlobalToast('Failed to send message. Please try again.',
          isError: true);
    } finally {
      _setSending(false);
    }
  }

  Future<void> sendTodo({
    required String senderId,
    required String senderName,
    required String todoText,
  }) async {
    if (todoText.trim().isEmpty) return;
    _setSending(true);
    final todo =
        ChatTodo(id: _uuid.v4(), text: todoText.trim(), createdBy: senderId);
    try {
      if (kSupabaseAvailable) {
        await ChatService.sendMessage(
          _currentRoom,
          senderId: senderId,
          senderName: senderName,
          text: todoText.trim(),
          type: ChatMessageType.todo,
          todo: todo,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 150));
        _demoAdd(ChatMessage(
          id: _uuid.v4(),
          senderId: senderId,
          senderName: senderName,
          text: todoText.trim(),
          timestamp: DateTime.now(),
          type: ChatMessageType.todo,
          todo: todo,
          roomId: _currentRoom,
        ));
      }
    } catch (e) {
      debugPrint('ChatProvider sendTodo error: $e');
      showGlobalToast('Failed to create task.', isError: true);
    } finally {
      _setSending(false);
    }
  }

  Future<void> sendPoll({
    required String senderId,
    required String senderName,
    required String question,
    required List<String> optionTexts,
  }) async {
    if (question.trim().isEmpty || optionTexts.length < 2) return;
    _setSending(true);
    final poll = ChatPoll(
      question: question.trim(),
      options: optionTexts
          .map((t) => PollOption(id: _uuid.v4(), text: t.trim()))
          .toList(),
    );
    try {
      if (kSupabaseAvailable) {
        await ChatService.sendMessage(
          _currentRoom,
          senderId: senderId,
          senderName: senderName,
          text: question.trim(),
          type: ChatMessageType.poll,
          poll: poll,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 150));
        _demoAdd(ChatMessage(
          id: _uuid.v4(),
          senderId: senderId,
          senderName: senderName,
          text: question.trim(),
          timestamp: DateTime.now(),
          type: ChatMessageType.poll,
          poll: poll,
          roomId: _currentRoom,
        ));
      }
    } catch (e) {
      debugPrint('ChatProvider sendPoll error: $e');
      showGlobalToast('Failed to create poll.', isError: true);
    } finally {
      _setSending(false);
    }
  }

  // â”€â”€ Interactions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void toggleTodo(String messageId, bool done) {
    if (kSupabaseAvailable) {
      ChatService.updateMessage(_currentRoom, messageId, {'todo.done': done});
    } else {
      _demoPatch(messageId, (m) {
        if (m.todo == null) return m;
        return m.copyWith(todo: m.todo!.copyWith(done: done));
      });
    }
  }

  void castVote(String messageId, String optionId, String uid) {
    if (kSupabaseAvailable) {
      ChatMessage? msg;
      for (final m in _liveMessages) {
        if (m.id == messageId) {
          msg = m;
          break;
        }
      }
      if (msg == null || msg.poll == null) return;
      final updated = msg.poll!.options.map((opt) {
        final hasVote = opt.voterUids.contains(uid);
        if (opt.id == optionId) return opt.withVote(uid, true);
        return hasVote ? opt.withVote(uid, false) : opt;
      }).toList();
      ChatService.updateMessage(_currentRoom, messageId, {
        'poll.options': updated.map((o) => o.toMap()).toList(),
      });
    } else {
      _demoPatch(messageId, (m) {
        if (m.poll == null) return m;
        final updated = m.poll!.options.map((opt) {
          final hasVote = opt.voterUids.contains(uid);
          if (opt.id == optionId) return opt.withVote(uid, true);
          return hasVote ? opt.withVote(uid, false) : opt;
        }).toList();
        return m.copyWith(
            poll: ChatPoll(question: m.poll!.question, options: updated));
      });
    }
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _setSending(bool v) {
    _sending = v;
    notifyListeners();
  }

  void _demoAdd(ChatMessage msg) {
    _demoMessages.add(msg);
    notifyListeners();
  }

  void _demoPatch(String id, ChatMessage Function(ChatMessage) fn) {
    final idx = _demoMessages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    _demoMessages[idx] = fn(_demoMessages[idx]);
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
