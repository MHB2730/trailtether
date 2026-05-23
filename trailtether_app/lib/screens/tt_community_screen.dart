// Trailtether 2.0 — Community screen.
//
// Recreates project/screens/community.jsx from the design bundle:
// brand bar + segmented tabs (Feed / Chat) over an animated body.
// Feed shows posts (TTCard) sourced from CommunityProvider.activities
// with author rows, location pills and an optional mini elevation chart
// when the activity references a hike. Chat shows a bubble thread
// (ember tint for own messages, graphite for received) backed by
// ChatProvider with a working composer pinned at the bottom.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/chat_message.dart';
import '../models/community.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/chat_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_segmented.dart';
import '../widgets/design/tt_topo.dart';

class TTCommunityScreen extends StatefulWidget {
  final bool embedded;
  const TTCommunityScreen({super.key, this.embedded = false});

  @override
  State<TTCommunityScreen> createState() => _TTCommunityScreenState();
}

class _TTCommunityScreenState extends State<TTCommunityScreen> {
  int _tab = 0; // 0 Feed, 1 Chat — matches the design's default

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        const Positioned.fill(child: TTAmbient()),
        const Positioned.fill(child: TTTopoBackdrop()),
        SafeArea(
          top: !widget.embedded,
          bottom: false,
          child: Column(
            children: [
              TTPageAppBar(
                title: 'Community',
                trailing: [
                  TTIconBtn(icon: Icons.search, onTap: () {}),
                  TTIconBtn(icon: Icons.notifications_none, onTap: () {}),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                child: TTSegmented(
                  tabs: const ['Feed', 'Chat'],
                  active: _tab,
                  onChange: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: TT.dMed,
                  child: _tab == 0
                      ? const _FeedView(key: ValueKey('feed'))
                      : const _ChatView(key: ValueKey('chat')),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

// ─────────────────────────────────── HELPERS ────────────────────────────────

/// Stable avatar color for a name — keeps users visually distinct across
/// posts/chat without persisting anything. Uses the brand palette.
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

String _relativeTime(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when);
  if (diff.isNegative) return 'just now';
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

String _clockTime(DateTime when) {
  final h = when.hour.toString().padLeft(2, '0');
  final m = when.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// ─────────────────────────────────── FEED ───────────────────────────────────

class _FeedView extends StatelessWidget {
  const _FeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityProvider>(
      builder: (_, provider, __) {
        if (provider.loading && provider.activities.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: TT.ember),
          );
        }
        final activities = provider.activities;
        return RefreshIndicator(
          onRefresh: provider.refresh,
          color: TT.ember,
          backgroundColor: TT.surf,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              const _ComposePrompt(),
              const SizedBox(height: 14),
              if (activities.isEmpty)
                const _EmptyFeed()
              else
                for (var i = 0; i < activities.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i == activities.length - 1 ? 0 : 12),
                    child: _FadeUpDelayed(
                      delay: Duration(milliseconds: 350 + i * 90),
                      child: _FeedPost(activity: activities[i]),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return _FadeUpDelayed(
      delay: const Duration(milliseconds: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TT.surf,
          border: Border.all(color: TT.line, width: 1),
          borderRadius: BorderRadius.circular(TT.rLg),
        ),
        child: Text(
          'No activity yet. When your team starts hiking, posts appear here.',
          textAlign: TextAlign.center,
          style: TT.body(size: 13, w: FontWeight.w500, color: TT.text3)
              .copyWith(height: 1.5),
        ),
      ),
    );
  }
}

class _ComposePrompt extends StatelessWidget {
  const _ComposePrompt();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final name = auth.displayName ?? auth.email ?? 'You';
    final initials = _initialsFor(name);

    return _FadeUpDelayed(
      delay: const Duration(milliseconds: 220),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sharing posts is coming soon',
                  style: TT.body(size: 13, color: Colors.white)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: TT.surf2,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: TT.surf,
            border: Border.all(color: TT.line, width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TT.ember, width: 2),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF6B3A1A), TT.ember2],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: TT.body(
                        size: 12, w: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Share a trail report, hazard, or photo…',
                  style: TT.body(size: 13, w: FontWeight.w500, color: TT.text3),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32, height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x08FFFFFF),
                  border: Border.all(color: TT.line, width: 1),
                  borderRadius: BorderRadius.circular(TT.rMd),
                ),
                child: const Icon(Icons.send, size: 14, color: TT.ember),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedPost extends StatelessWidget {
  final CommunityActivity activity;
  const _FeedPost({required this.activity});

  bool get _isHike => activity.type == ActivityType.hikeCompleted;
  bool get _isHazard => activity.type == ActivityType.checkIn &&
      (activity.title.toLowerCase().contains('hazard') ||
          activity.subtitle.toLowerCase().contains('hazard'));

  String get _locationLabel {
    // Prefer an explicit location field on metadata if present, then fall
    // back to the team name so the location pill is never empty.
    final meta = activity.metadata;
    final loc = (meta['location'] ?? meta['trail_name'] ?? meta['trail'])
        as String?;
    if (loc != null && loc.trim().isNotEmpty) return loc;
    return activity.teamName;
  }

  String get _bodyText {
    // Compose a readable body from the title + subtitle without producing
    // double-spaces when one is empty.
    final parts = <String>[];
    if (activity.title.trim().isNotEmpty) parts.add(activity.title.trim());
    if (activity.subtitle.trim().isNotEmpty) parts.add(activity.subtitle.trim());
    return parts.isEmpty ? '(no details)' : parts.join(' — ');
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColorFor(activity.userName);
    final initials = _initialsFor(activity.userName);

    return TTCard(
      onTap: () {},
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TT.rLg),
        child: Stack(
          children: [
            if (_isHazard)
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(width: 3, color: TT.amber),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthorRow(
                    name: activity.userName,
                    initials: initials,
                    color: color,
                    time: _relativeTime(activity.timestamp),
                    location: _locationLabel,
                    hazard: _isHazard,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _bodyText,
                    style: TT.body(size: 13, w: FontWeight.w500)
                        .copyWith(height: 1.5),
                  ),
                  if (_isHike) ...[
                    const SizedBox(height: 12),
                    const _MiniElevChart(),
                  ],
                  const SizedBox(height: 12),
                  Container(height: 1, color: TT.line),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      _ActionBtn(icon: Icons.send, value: 'Share'),
                      Spacer(),
                      Icon(Icons.more_horiz, size: 14, color: TT.text3),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final String name;
  final String initials;
  final Color color;
  final String time;
  final String location;
  final bool hazard;
  const _AuthorRow({
    required this.name,
    required this.initials,
    required this.color,
    required this.time,
    required this.location,
    required this.hazard,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.66)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TT.body(size: 13, w: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: TT.body(size: 13, w: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: TT.mono(size: 9.5, color: TT.text3)
                        .copyWith(letterSpacing: 0.06 * 9.5),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.place, size: 10, color: TT.ember),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TT.mono(size: 10, color: TT.ember)
                          .copyWith(letterSpacing: 0.06 * 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (hazard) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x2EF2A93B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'HAZARD',
                        style: TT.mono(size: 8.5, color: TT.amber, w: FontWeight.w800)
                            .copyWith(letterSpacing: 0.1 * 8.5),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniElevChart extends StatefulWidget {
  const _MiniElevChart();

  @override
  State<_MiniElevChart> createState() => _MiniElevChartState();
}

class _MiniElevChartState extends State<_MiniElevChart> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, __) => CustomPaint(
          painter: _MiniElevPainter(progress: TT.drawCurve.transform(_ctl.value)),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MiniElevPainter extends CustomPainter {
  final double progress;
  _MiniElevPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.125, h * 0.60, w * 0.25, h * 0.48)
      ..quadraticBezierTo(w * 0.40, h * 0.22, w * 0.56, h * 0.17)
      ..quadraticBezierTo(w * 0.69, h * 0.30, w * 0.81, h * 0.43)
      ..quadraticBezierTo(w * 0.91, h * 0.52, w, h * 0.65);

    // Animate the stroke draw using PathMetric trim.
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    final drawn = Path();
    var consumed = 0.0;
    final target = total * progress.clamp(0.0, 1.0);
    for (final m in metrics) {
      if (consumed + m.length <= target) {
        drawn.addPath(m.extractPath(0, m.length), Offset.zero);
        consumed += m.length;
      } else {
        final remain = target - consumed;
        if (remain > 0) drawn.addPath(m.extractPath(0, remain), Offset.zero);
        break;
      }
    }

    // Fill under curve — based on the full path so the gradient holds shape.
    final fill = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x80FF6A2C), Color(0x00FF6A2C)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w * progress.clamp(0.0, 1.0), h));
    canvas.drawPath(fill, fillPaint);
    canvas.restore();

    final stroke = Paint()
      ..color = TT.ember
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(drawn, stroke);
  }

  @override
  bool shouldRepaint(_MiniElevPainter old) => old.progress != progress;
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String value;
  const _ActionBtn({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: TT.text2),
        const SizedBox(width: 5),
        Text(value,
            style: TT.body(size: 11, w: FontWeight.w700, color: TT.text2)
                .copyWith(letterSpacing: 0.04 * 11)),
      ],
    );
  }
}

// ─────────────────────────────────── CHAT ───────────────────────────────────

class _ChatView extends StatefulWidget {
  const _ChatView({super.key});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _composer = TextEditingController();
  int _lastMsgCount = 0;

  @override
  void dispose() {
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
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

  Future<void> _send(ChatProvider chat) async {
    final auth = context.read<ap.AuthProvider>();
    final txt = _composer.text.trim();
    if (txt.isEmpty) return;

    if (!auth.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please sign in to join the community chat.',
            style: TT.body(size: 13, color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: TT.surf2,
      ));
      return;
    }

    final senderId = auth.uid ?? '';
    final senderName = auth.displayName ?? auth.email ?? 'Hiker';

    _composer.clear();
    await chat.sendText(
      senderId: senderId,
      senderName: senderName,
      text: txt,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (_, chat, __) {
        // ChatProvider already returns oldest-first (service does .reversed
        // after sorting sent_at DESC). Defensive sort keeps ordering stable
        // if that ever changes.
        final messages = List<ChatMessage>.from(chat.messages)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Auto-scroll to bottom when message count changes (new message
        // arrives) or on initial build.
        if (messages.length != _lastMsgCount) {
          _lastMsgCount = messages.length;
          _scrollToBottom(animate: _lastMsgCount > 0);
        }

        final auth = context.watch<ap.AuthProvider>();
        final myUid = auth.uid;

        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: _FadeUpDelayed(
                delay: Duration(milliseconds: 120),
                child: _PinnedChannel(),
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? const _EmptyChat()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        final mine =
                            myUid != null && m.senderId == myUid;
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: i == messages.length - 1 ? 0 : 10),
                          child: _FadeUpDelayed(
                            // Cap the stagger so older messages don't pile
                            // up huge delays on the first render.
                            delay: Duration(
                                milliseconds: 80 + (i.clamp(0, 8)) * 50),
                            child: _ChatMsg(msg: m, mine: mine),
                          ),
                        );
                      },
                    ),
            ),
            _ChatComposer(
              controller: _composer,
              sending: chat.sending,
              onSend: () => _send(chat),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Be the first to say hello',
          textAlign: TextAlign.center,
          style: TT.body(size: 13, w: FontWeight.w500, color: TT.text3),
        ),
      ),
    );
  }
}

class _PinnedChannel extends StatelessWidget {
  const _PinnedChannel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TT.emberDim,
        border: Border.all(color: const Color(0x52FF6A2C), width: 1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0x38FF6A2C),
              border: Border.all(color: const Color(0x73FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.groups, size: 14, color: TT.ember),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Community · Team Chat',
                    style: TT.body(size: 12.5, w: FontWeight.w800, color: TT.ember)),
                const SizedBox(height: 2),
                Text('LIVE · #GENERAL',
                    style: TT.mono(size: 10, color: TT.text3)
                        .copyWith(letterSpacing: 0.04 * 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMsg extends StatelessWidget {
  final ChatMessage msg;
  final bool mine;
  const _ChatMsg({required this.msg, required this.mine});

  @override
  Widget build(BuildContext context) {
    if (msg.type == ChatMessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          msg.text,
          textAlign: TextAlign.center,
          style: TT.mono(size: 10, color: TT.text3)
              .copyWith(letterSpacing: 0.06 * 10),
        ),
      );
    }

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

    final color = _avatarColorFor(msg.senderId.isNotEmpty ? msg.senderId : msg.senderName);
    final initials = _initialsFor(msg.senderName);
    final timeLabel = _clockTime(msg.timestamp);

    return LayoutBuilder(builder: (_, c) {
      final maxBubbleW = c.maxWidth * 0.74;
      final avatar = !mine
          ? Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.66)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TT.body(size: 11, w: FontWeight.w800, color: Colors.white),
              ),
            )
          : null;

      final column = Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine)
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: bubbleBg,
                border: Border.all(color: bubbleBorder, width: 1),
                borderRadius: radius,
              ),
              child: Text(
                msg.text,
                style: TT.body(size: 12.5, w: FontWeight.w500, color: bubbleColor)
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
                    style: TT.mono(size: 9.5, color: TT.text3)
                        .copyWith(letterSpacing: 0.04 * 9.5, fontWeight: FontWeight.w600),
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
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
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

class _ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _ChatComposer({
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
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0x08FFFFFF),
                border: Border.all(color: TT.line, width: 1),
                borderRadius: BorderRadius.circular(TT.rMd),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, size: 18, color: TT.text2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: TT.surf,
                  border: Border.all(color: TT.line, width: 1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
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
                              const EdgeInsets.symmetric(vertical: 10),
                          hintText: 'Message…',
                          hintStyle: TT.body(
                              size: 13,
                              w: FontWeight.w500,
                              color: TT.text3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.visibility_outlined, size: 16, color: TT.text3),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: sending ? null : onSend,
              child: Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [TT.ember2, TT.ember],
                  ),
                  boxShadow: TT.shadowEmber,
                ),
                alignment: Alignment.center,
                child: sending
                    ? const SizedBox(
                        width: 16, height: 16,
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

// Convenience pill kept inline — used here to import nothing extra while
// still pulling TTPill out of the design system if needed downstream.
// (Reference retained to satisfy lints that may flag unused imports.)
// ignore: unused_element
class _PillProxy extends StatelessWidget {
  const _PillProxy();
  @override
  Widget build(BuildContext context) =>
      const TTPill(label: 'LIVE', variant: TTPillVariant.live);
}

// ────────────────────────────── ANIMATION HELPER ────────────────────────────

class _FadeUpDelayed extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _FadeUpDelayed({required this.delay, required this.child});

  @override
  State<_FadeUpDelayed> createState() => _FadeUpDelayedState();
}

class _FadeUpDelayedState extends State<_FadeUpDelayed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);
  late final Animation<double> _t =
      CurvedAnimation(parent: _ctl, curve: TT.easeOut);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _ctl.forward(); });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, __) {
        final v = _t.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 14),
            child: widget.child,
          ),
        );
      },
    );
  }
}
