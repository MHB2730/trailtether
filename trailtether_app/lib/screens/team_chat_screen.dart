// Trailtether 3.0 — Team chat tab body.
//
// Reskin notes:
//   * UI rewritten on top of TT v3 design tokens — ember bubbles for own
//     messages, graphite bubbles for incoming, mono timestamps, ember send
//     button matching the `chat tab` in tt_community_screen.dart.
//   * Logic is preserved verbatim: Supabase realtime stream on
//     `chat_messages` filtered by `room_id == team.id`, insert payload
//     identical to before, admin / team-creator gating for the clear-room
//     action. Auto-scroll to bottom on first load and on every new message.
//
// This widget is embedded both inside the TeamDetailScreen TabBarView and
// the standalone chat wrapper used by tt_team_screen.dart, so it does NOT
// supply its own Scaffold / AppBar — the parent owns the back chevron.
//
// Owns only this file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/design_tokens.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart' as ap;
import '../services/chat_service.dart';
import '../widgets/common/clear_chat_bar.dart';

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

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(target);
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
          content: Text('Send failed: $e',
              style: TT.body(size: 13, color: TT.text)),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
        ));
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

    return Container(
      color: TT.bg,
      child: Column(
        children: [
          if (canClear)
            ClearChatBar(
              label: 'Clear team chat',
              onConfirm: () => ChatService.clearRoom(widget.team.id),
            ),
          // ── Messages list ─────────────────────────────────────────────
          Expanded(
            child: _msgs.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                    itemCount: _msgs.length,
                    itemBuilder: (_, i) {
                      final m = _msgs[i];
                      final isMe = m.senderId == myUid;
                      final isNew = i == 0 ||
                          _msgs[i - 1].senderId != m.senderId ||
                          m.ts.difference(_msgs[i - 1].ts).inMinutes > 5;
                      return Padding(
                        padding: EdgeInsets.only(
                          top: isNew ? 12 : 4,
                          bottom: i == _msgs.length - 1 ? 0 : 2,
                        ),
                        child: _ChatBubble(
                          msg: m,
                          mine: isMe,
                          showHeader: isNew && !isMe,
                        ),
                      );
                    },
                  ),
          ),

          // ── Composer ──────────────────────────────────────────────────
          _Composer(
            controller: _ctrl,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────── HELPERS ────────────────────────────────

const List<Color> _avatarPalette = [
  Color(0xFFFF8A4D),
  Color(0xFF4CC38A),
  Color(0xFFF2A93B),
  Color(0xFFFF6A2C),
  Color(0xFF5AA1D6),
  Color(0xFFFFB486),
];

Color _avatarColorFor(String key) {
  if (key.isEmpty) return TT.ember;
  var h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _avatarPalette[h % _avatarPalette.length];
}

String _initialsFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    final p = parts.first;
    return p.length >= 2
        ? p.substring(0, 2).toUpperCase()
        : p[0].toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _clockTime(DateTime when) {
  final h = when.hour.toString().padLeft(2, '0');
  final m = when.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// ─────────────────────────────────── EMPTY ──────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TT.emberDim,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x52FF6A2C), width: 1),
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  color: TT.ember, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              'Be the first to say hello',
              textAlign: TextAlign.center,
              style: TT.title(15, letterSpacing: -0.01 * 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Messages stay private to this team.',
              textAlign: TextAlign.center,
              style: TT.body(size: 12.5, color: TT.text3, w: FontWeight.w500)
                  .copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────── BUBBLE ─────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final _TeamMsg msg;
  final bool mine;
  final bool showHeader;

  const _ChatBubble({
    required this.msg,
    required this.mine,
    required this.showHeader,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleBg = mine ? TT.emberDim : TT.surf;
    final bubbleBorder = mine ? const Color(0x5CFF6A2C) : TT.line;
    final bubbleColor = mine ? TT.ember3 : TT.text;
    final radius = mine
        ? const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(14),
          );

    final color = _avatarColorFor(
        msg.senderId.isNotEmpty ? msg.senderId : msg.senderName);
    final initials = _initialsFor(msg.senderName);
    final timeLabel = _clockTime(msg.ts);

    return LayoutBuilder(builder: (_, c) {
      final maxBubbleW = c.maxWidth * 0.74;
      final avatar = !mine
          ? Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.66)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style:
                    TT.body(size: 11, w: FontWeight.w800, color: Colors.white),
              ),
            )
          : null;

      final column = Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showHeader && !mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${msg.senderName} · $timeLabel',
                style: TT.mono(size: 10, color: TT.text3)
                    .copyWith(letterSpacing: 0.04 * 10),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleW),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: bubbleBg,
                border: Border.all(color: bubbleBorder, width: 1),
                borderRadius: radius,
              ),
              child: Text(
                msg.text,
                style: TT.body(
                        size: 12.5, w: FontWeight.w500, color: bubbleColor)
                    .copyWith(height: 1.4),
              ),
            ),
          ),
          if (mine)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel,
                    style: TT.mono(size: 9.5, color: TT.text3).copyWith(
                        letterSpacing: 0.04 * 9.5,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, size: 12, color: TT.green),
                ],
              ),
            ),
        ],
      );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: mine
            ? [Flexible(child: column)]
            : [
                if (avatar != null) avatar,
                const SizedBox(width: 8),
                Flexible(child: column),
              ],
      );
    });
  }
}

// ─────────────────────────────────── COMPOSER ───────────────────────────────

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: const BoxDecoration(
        color: TT.bg2,
        border: Border(top: BorderSide(color: TT.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: TT.surf,
                  border: Border.all(color: TT.line2, width: 1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: controller,
                  enabled: !sending,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  cursorColor: TT.ember,
                  style: TT.body(size: 13, w: FontWeight.w500),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    hintText: 'Message your team…',
                    hintStyle: TT.body(
                        size: 13, w: FontWeight.w500, color: TT.text3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: sending ? null : onSend,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [TT.ember2, TT.ember],
                  ),
                  boxShadow: TT.shadowEmber,
                ),
                alignment: Alignment.center,
                child: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(TT.emberInk),
                        ),
                      )
                    : const Icon(Icons.send, size: 16, color: TT.emberInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────── MODEL ──────────────────────────────────

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
