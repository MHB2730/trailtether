import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/community.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/chat_provider.dart';
import '../providers/community_provider.dart';
import '../services/chat_service.dart';
import '../widgets/common/clear_chat_bar.dart';
import '../widgets/common/user_avatar.dart';
import '../widgets/common/blueprint_background.dart';
import '../widgets/common/glass_panel.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Community Screen  —  Feed · General Chat
// ══════════════════════════════════════════════════════════════════════════════
class ChatTab extends StatefulWidget {
  const ChatTab({super.key});
  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _scroll = ScrollController();
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _scroll.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String _senderName(BuildContext context) {
    final auth = context.read<ap.AuthProvider>();
    if (auth.isAuth) {
      return auth.displayName ?? 'Hiker';
    }
    return 'You';
  }

  String _senderId(BuildContext context) {
    final auth = context.read<ap.AuthProvider>();
    return auth.uid ?? ''; // Use empty string for unauthenticated
  }

  Future<void> _sendMessage(ChatProvider chat) async {
    final auth = context.read<ap.AuthProvider>();
    if (!auth.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please sign in to join the community chat.')));
      return;
    }

    final txt = _msgCtrl.text.trim();
    if (txt.isEmpty) return;

    final sId = _senderId(context);
    final sName = _senderName(context);

    _msgCtrl.clear();
    await chat.sendText(
      senderId: sId,
      senderName: sName,
      text: txt,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: kColorBg,
        appBar: AppBar(
          backgroundColor: kColorBg,
          elevation: 0,
          toolbarHeight: 70,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kColorOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kColorOrange.withOpacity(0.2)),
                ),
                child: const Icon(Icons.public, color: kColorOrange, size: 24),
              ),
              const SizedBox(width: 12),
              Text('Community',
                  style: GoogleFonts.outfit(
                      color: kColorCream,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          bottom: TabBar(
            indicatorColor: kColorOrange,
            indicatorWeight: 3,
            labelColor: kColorOrange,
            unselectedLabelColor: kColorCream.withOpacity(0.4),
            labelStyle:
                GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'FEED', icon: Icon(Icons.dynamic_feed, size: 20)),
              Tab(text: 'USERS', icon: Icon(Icons.people_outline, size: 20)),
              Tab(text: 'CHAT', icon: Icon(Icons.chat_bubble, size: 20)),
            ],
          ),
        ),
        body: BlueprintBackground(
          child: TabBarView(
            children: [
              const _CommunityFeedView(),
              const _ActiveUsersView(),
              _GeneralChatView(
                scroll: _scroll,
                msgCtrl: _msgCtrl,
                onSend: (chat) => _sendMessage(chat),
                senderId: _senderId(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feed View ──────────────────────────────────────────────────────────────────
class _CommunityFeedView extends StatelessWidget {
  const _CommunityFeedView();

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityProvider>(
      builder: (_, provider, __) {
        if (provider.loading) {
          return const Center(
              child: CircularProgressIndicator(color: kColorOrange));
        }
        final activities = provider.activities;
        return RefreshIndicator(
          onRefresh: provider.refresh,
          color: kColorOrange,
          backgroundColor: kColorPanel,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (_, i) => _ActivityItem(activity: activities[i]),
          ),
        );
      },
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final CommunityActivity activity;
  const _ActivityItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (activity.type) {
      case ActivityType.hikeCompleted:
        icon = Icons.terrain;
        color = kColorOrange;
        break;
      case ActivityType.teamCreated:
        icon = Icons.group_add;
        color = Colors.blue;
        break;
      case ActivityType.achievementUnlocked:
        icon = Icons.workspace_premium;
        color = Colors.amber;
        break;
      case ActivityType.checkIn:
        icon = Icons.location_on;
        color = Colors.tealAccent;
        break;
    }

    return GlassPanel(
      opacity: 0.7,
      blur: 8,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kColorOrange.withOpacity(0.1)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(activity.teamName.toUpperCase(),
                          style: GoogleFonts.outfit(
                              color: kColorOrange,
                              fontSize: 10,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w900)),
                      Text(DateFormat('HH:mm').format(activity.timestamp),
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.3),
                              fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${activity.userName} ${activity.title}',
                      style: GoogleFonts.outfit(
                          color: kColorCream,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(activity.subtitle,
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.4), fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Leaderboard View ───────────────────────────────────────────────────────────
class _LeaderboardView extends StatefulWidget {
  @override
  State<_LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<_LeaderboardView> {
  int _sortBy = 0; // 0=KM, 1=Ascent, 2=Peaks

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityProvider>(
      builder: (_, provider, __) {
        if (provider.loading) {
          return const Center(
              child: CircularProgressIndicator(color: kColorOrange));
        }

        final sorted = List<TeamLeaderboardStats>.from(provider.leaderboard);
        if (_sortBy == 0) {
          sorted.sort((a, b) => b.totalKm.compareTo(a.totalKm));
        }
        if (_sortBy == 1) {
          sorted.sort((a, b) => b.totalAscent.compareTo(a.totalAscent));
        }
        if (_sortBy == 2) {
          sorted.sort((a, b) => b.peaksClimbed.compareTo(a.peaksClimbed));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _sortChip('Distance', 0),
                  const SizedBox(width: 8),
                  _sortChip('Ascent', 1),
                  const SizedBox(width: 8),
                  _sortChip('Peaks', 2),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sorted.length,
                itemBuilder: (_, i) => _LeaderboardItem(
                  stats: sorted[i],
                  rank: i + 1,
                  metricType: _sortBy,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sortChip(String label, int index) {
    final sel = _sortBy == index;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? kColorOrange.withOpacity(0.15) : kColorPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? kColorOrange : kColorBorder),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                color: sel ? kColorOrange : kColorCream.withOpacity(0.5),
                fontSize: 12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}

class _LeaderboardItem extends StatelessWidget {
  final TeamLeaderboardStats stats;
  final int rank;
  final int metricType;
  const _LeaderboardItem(
      {required this.stats, required this.rank, required this.metricType});

  @override
  Widget build(BuildContext context) {
    String value;
    String label;
    switch (metricType) {
      case 0:
        value = '${stats.totalKm.toInt()}';
        label = 'KM';
        break;
      case 1:
        value = '${stats.totalAscent}';
        label = 'M';
        break;
      default:
        value = '${stats.peaksClimbed}';
        label = 'PEAKS';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text('#$rank',
                style: GoogleFonts.outfit(
                    color:
                        rank <= 3 ? kColorOrange : kColorCream.withOpacity(0.3),
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stats.teamName,
                    style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text('${stats.memberCount} members',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.3),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Chat View ──────────────────────────────────────────────────────────────────
class _GeneralChatView extends StatelessWidget {
  final ScrollController scroll;
  final TextEditingController msgCtrl;
  final Function(ChatProvider) onSend;
  final String senderId;

  const _GeneralChatView({
    required this.scroll,
    required this.msgCtrl,
    required this.onSend,
    required this.senderId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (_, chat, __) {
        final msgs = chat.messages;
        final isAdmin = context.watch<ap.AuthProvider>().isAdmin;
        return Column(
          children: [
            if (isAdmin)
              ClearChatBar(
                label: 'Clear community chat',
                onConfirm: () => ChatService.clearRoom('general'),
              ),
            Expanded(
              child: msgs.isEmpty
                  ? Center(
                      child: Text('No messages yet. Say hi to the community!',
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.3))))
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: msgs.length,
                      cacheExtent:
                          1000, // Pre-render some items for smoother scrolling
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        final isMe =
                            m.senderId == senderId || m.senderId == 'demo_user';
                        final isFirst =
                            i == 0 || msgs[i - 1].senderId != m.senderId;
                        return _MessageBubble(
                            msg: m, isMe: isMe, isFirst: isFirst);
                      },
                    ),
            ),
            _ComposeBar(
              controller: chat.sending ? null : msgCtrl,
              onSend: () => onSend(chat),
              sending: chat.sending,
            ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe, isFirst;
  const _MessageBubble(
      {required this.msg, required this.isMe, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe && isFirst) ...[
            CircleAvatar(
                radius: 14,
                backgroundColor: kColorOrange.withOpacity(0.2),
                child: Text(
                    msg.senderName.isNotEmpty
                        ? msg.senderName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.outfit(
                        color: kColorOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
          ] else if (!isMe)
            const SizedBox(width: 36),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isFirst)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 2, left: 4, right: 4),
                    child: Text(isMe ? 'You' : msg.senderName,
                        style: GoogleFonts.outfit(
                            color: kColorOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? kColorOrange.withOpacity(0.15) : kColorPanel,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomLeft: isMe
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    border: Border.all(
                        color: isMe
                            ? kColorOrange.withOpacity(0.2)
                            : kColorBorder),
                  ),
                  child: Text(msg.text,
                      style:
                          GoogleFonts.outfit(color: kColorCream, fontSize: 14)),
                ),
              ],
            ),
          ),
          if (isMe && isFirst) ...[
            const SizedBox(width: 8),
            CircleAvatar(
                radius: 14,
                backgroundColor: kColorOrange.withOpacity(0.3),
                child: Text(
                    msg.senderName.isNotEmpty
                        ? msg.senderName[0].toUpperCase()
                        : 'Y',
                    style: GoogleFonts.outfit(
                        color: kColorOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold))),
          ] else if (isMe)
            const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  final TextEditingController? controller;
  final VoidCallback onSend;
  final bool sending;

  const _ComposeBar(
      {required this.controller, required this.onSend, required this.sending});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    if (!auth.isAuth) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: kColorBg,
          border: Border(top: BorderSide(color: kColorBorder)),
        ),
        child: Center(
          child: Text(
            'Sign in to join the community conversation',
            style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.4),
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: kColorBg,
        border: Border(top: BorderSide(color: kColorBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.outfit(color: kColorCream, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Message community…',
                hintStyle:
                    GoogleFonts.outfit(color: kColorCream.withOpacity(0.3)),
                filled: true,
                fillColor: kColorPanel,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: kColorOrange, borderRadius: BorderRadius.circular(12)),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active Users View ────────────────────────────────────────────────────────
class _ActiveUsersView extends StatefulWidget {
  const _ActiveUsersView();

  @override
  State<_ActiveUsersView> createState() => _ActiveUsersViewState();
}

class _ActiveUsersViewState extends State<_ActiveUsersView> {
  int _sortBy = 0; // 0=KM, 1=Ascent, 2=Peaks

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityProvider>(
      builder: (_, provider, __) {
        if (provider.loading) {
          return const Center(
              child: CircularProgressIndicator(color: kColorOrange));
        }

        final sorted =
            List<UserLeaderboardStats>.from(provider.userLeaderboard);
        if (sorted.isEmpty) {
          return Center(
            child: Text('No active users found.',
                style: GoogleFonts.outfit(color: kColorCream.withOpacity(0.3))),
          );
        }

        if (_sortBy == 0) {
          sorted.sort((a, b) => b.totalKm.compareTo(a.totalKm));
        }
        if (_sortBy == 1) {
          sorted.sort((a, b) => b.totalAscent.compareTo(a.totalAscent));
        }
        if (_sortBy == 2) {
          sorted.sort((a, b) => b.peaksClimbed.compareTo(a.peaksClimbed));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _sortChip('Distance', 0),
                  const SizedBox(width: 8),
                  _sortChip('Ascent', 1),
                  const SizedBox(width: 8),
                  _sortChip('Peaks', 2),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sorted.length,
                itemBuilder: (_, i) => _UserLeaderboardItem(
                  stats: sorted[i],
                  rank: i + 1,
                  metricType: _sortBy,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sortChip(String label, int index) {
    final sel = _sortBy == index;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? kColorOrange.withOpacity(0.15) : kColorPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? kColorOrange : kColorBorder),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                color: sel ? kColorOrange : kColorCream.withOpacity(0.5),
                fontSize: 12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}

class _UserLeaderboardItem extends StatelessWidget {
  final UserLeaderboardStats stats;
  final int rank;
  final int metricType;
  const _UserLeaderboardItem(
      {required this.stats, required this.rank, required this.metricType});

  @override
  Widget build(BuildContext context) {
    String value;
    String label;
    switch (metricType) {
      case 0:
        value = '${stats.totalKm.toInt()}';
        label = 'KM';
        break;
      case 1:
        value = '${stats.totalAscent}';
        label = 'M';
        break;
      default:
        value = '${stats.peaksClimbed}';
        label = 'PEAKS';
        break;
    }

    return GlassPanel(
      opacity: 0.7,
      blur: 8,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kColorOrange.withOpacity(0.1)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kColorOrange.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: kColorOrange.withOpacity(0.2)),
              ),
              child: Text('$rank',
                  style: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 14),
            UserAvatar(
              displayName: stats.displayName,
              photoUrl: stats.photoUrl,
              radius: 20,
              backgroundColor: kColorBg,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stats.displayName,
                      style: GoogleFonts.outfit(
                          color: kColorCream,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: kColorOrange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: kColorOrange.withOpacity(0.5),
                                blurRadius: 4)
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('ACTIVE NODE',
                          style: GoogleFonts.outfit(
                              color: kColorOrange.withOpacity(0.6),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    style: GoogleFonts.outfit(
                        color: kColorOrange,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                Text(label,
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.3),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
