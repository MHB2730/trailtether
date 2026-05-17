import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart' as ap;
import '../services/chat_service.dart';
import '../widgets/common/clear_chat_bar.dart';

// ══════════════════════════════════════════════════════════════════════════════
// TeamChatScreen — private chat for a single team
// Stored in: chat_messages table with room_id = team.id
// ══════════════════════════════════════════════════════════════════════════════

class TeamChatScreen extends StatefulWidget {
  final Team team;
  const TeamChatScreen({super.key, required this.team});

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final _scroll = ScrollController();
  final _ctrl = TextEditingController();
  bool _sending = false;

  // Messages
  List<_TeamMsg> _msgs = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final stream = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.team.id)
        .order('sent_at', ascending: false)
        .limit(80);

    _sub = stream.listen(
      (rows) {
        if (!mounted) return;
        final msgs = rows.map(_TeamMsg.fromMap).toList().reversed.toList();
        setState(() => _msgs = msgs);
        _scrollToBottom();
      },
      onError: (e) => debugPrint('TeamChat stream error: $e'),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);

    final auth = context.read<ap.AuthProvider>();
    final uid = auth.uid ?? '';
    final name = auth.displayName ?? auth.email ?? 'Member';

    try {
      await Supabase.instance.client.from('chat_messages').insert({
        'room_id': widget.team.id,
        'sender_id': uid.isEmpty ? null : uid,
        'sender_name': name,
        'message_text': text,
        'sent_at': DateTime.now().toIso8601String(),
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Send failed: $e'),
            backgroundColor: const Color(0xFFE53935)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final myUid = auth.uid ?? '';
    final canClear = auth.isAdmin || widget.team.createdBy == myUid;

    // Render as a plain Column — this widget is embedded in a TabBarView
    // that already has a Scaffold/AppBar in the parent (TeamDetailScreen).
    return Column(
      children: [
        if (canClear)
          ClearChatBar(
            label: 'Clear team chat',
            onConfirm: () => ChatService.clearRoom(widget.team.id),
          ),
        // ── Messages list ─────────────────────────────────────────────
        Expanded(
          child: _msgs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          color: kColorOrange.withOpacity(0.3), size: 48),
                      const SizedBox(height: 12),
                      Text('No messages yet.\nBe the first to say something!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.3),
                              fontSize: 14,
                              height: 1.5)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: _msgs.length,
                  itemBuilder: (_, i) {
                    final m = _msgs[i];
                    final isMe = m.senderId == myUid;
                    final isNew = i == 0 ||
                        _msgs[i - 1].senderId != m.senderId ||
                        m.ts.difference(_msgs[i - 1].ts).inMinutes > 5;
                    return _Bubble(
                        msg: m, isMe: isMe, showName: isNew && !isMe);
                  },
                ),
        ),

        // ── Compose bar ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(
            color: kColorBg,
            border: Border(top: BorderSide(color: kColorBorder)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: kColorPanel,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      style:
                          GoogleFonts.outfit(color: kColorCream, fontSize: 14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Message your team…',
                        hintStyle: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.3), fontSize: 14),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kColorOrange,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                            color: kColorOrange.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: _sending
                        ? const Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Data model ─────────────────────────────────────────────────────────────────
class _TeamMsg {
  final String senderId;
  final String senderName;
  final String text;
  final DateTime ts;

  const _TeamMsg({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.ts,
  });

  static _TeamMsg fromMap(Map<String, dynamic> m) {
    return _TeamMsg(
      senderId: m['sender_id'] as String? ?? '',
      senderName: m['sender_name'] as String? ?? 'Member',
      text: m['message_text'] as String? ?? '',
      ts: m['sent_at'] != null
          ? DateTime.tryParse(m['sent_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final _TeamMsg msg;
  final bool isMe;
  final bool showName;
  const _Bubble(
      {required this.msg, required this.isMe, required this.showName});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${msg.ts.hour.toString().padLeft(2, '0')}:${msg.ts.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: showName ? 12 : 3,
          bottom: 2,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showName && !isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Text(msg.senderName,
                    style: GoogleFonts.outfit(
                        color: kColorOrange.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? kColorOrange.withOpacity(0.18) : kColorPanel,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMe ? 18 : (showName ? 4 : 18)),
                  topRight: Radius.circular(isMe ? (showName ? 4 : 18) : 18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(18),
                ),
                border: Border.all(
                    color: isMe ? kColorOrange.withOpacity(0.3) : kColorBorder),
              ),
              child: Text(msg.text,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.4)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(timeStr,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.25), fontSize: 9)),
            ),
          ],
        ),
      ),
    );
  }
}
