// Trailtether 2.0 — Community screen.
//
// Recreates project/screens/community.jsx from the design bundle:
// brand bar + segmented tabs (Feed / Chat) over an animated body.
// Feed shows staggered posts (TTCard) with author rows, optional mini
// elevation charts and GPX/route cards. Chat shows a bubble thread
// (ember tint for own messages, graphite for received) with a
// placeholder composer pinned at the bottom. Backed by inline
// placeholder data — no provider / services dependencies.

import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
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

// ─────────────────────────────────── FEED ───────────────────────────────────

class _FeedPostData {
  final String user;
  final String initials;
  final Color color;
  final String time;
  final String location;
  final String text;
  final _PostStats? stats;
  final int likes;
  final int comments;
  final bool hazard;
  final _Attachment attached;
  final String? gpxName;
  final String? gpxMeta;

  const _FeedPostData({
    required this.user,
    required this.initials,
    required this.color,
    required this.time,
    required this.location,
    required this.text,
    this.stats,
    required this.likes,
    required this.comments,
    this.hazard = false,
    this.attached = _Attachment.none,
    this.gpxName,
    this.gpxMeta,
  });
}

class _PostStats {
  final String dist, gain, time;
  const _PostStats({required this.dist, required this.gain, required this.time});
}

enum _Attachment { none, elev, gpx }

class _FeedView extends StatelessWidget {
  const _FeedView({super.key});

  static const List<_FeedPostData> _posts = [
    _FeedPostData(
      user: 'Sarah L.', initials: 'SL', color: Color(0xFFFF8A4D),
      time: '14m ago', location: 'Wonderland Trail',
      text: "Made it to the summit — Liberty Cap. Wind is brutal up here but visibility is unreal.",
      stats: _PostStats(dist: '8.4 mi', gain: '+3,950 ft', time: '5:42'),
      likes: 24, comments: 6, attached: _Attachment.elev,
    ),
    _FeedPostData(
      user: 'Mike K.', initials: 'MK', color: Color(0xFF4CC38A),
      time: '2h ago', location: 'Berkeley Park',
      text: 'Heads up — bridge at km 4 is washed out. Going around via the upper switchback. Adds ~30 min.',
      likes: 42, comments: 11, hazard: true,
    ),
    _FeedPostData(
      user: 'John D.', initials: 'JD', color: Color(0xFFFF6A2C),
      time: 'Yesterday', location: 'Mt. Marcy Trail',
      text: 'Sunday hike with the team. Perfect conditions, scored 9/10 on the weather. Posted the GPX if anyone wants it.',
      stats: _PostStats(dist: '5.8 mi', gain: '+3,950 ft', time: '5:14'),
      likes: 87, comments: 19, attached: _Attachment.gpx,
      gpxName: 'mt-marcy-2023-10-26.gpx',
      gpxMeta: '5.8 mi · 412 waypoints · 84 KB',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const _ComposePrompt(),
        const SizedBox(height: 14),
        for (var i = 0; i < _posts.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == _posts.length - 1 ? 0 : 12),
            child: _FadeUpDelayed(
              delay: Duration(milliseconds: 350 + i * 90),
              child: _FeedPost(data: _posts[i]),
            ),
          ),
      ],
    );
  }
}

class _ComposePrompt extends StatelessWidget {
  const _ComposePrompt();

  @override
  Widget build(BuildContext context) {
    return _FadeUpDelayed(
      delay: const Duration(milliseconds: 220),
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
              child: Text('JD',
                  style: TT.body(size: 12, w: FontWeight.w800, color: Colors.white)),
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
    );
  }
}

class _FeedPost extends StatelessWidget {
  final _FeedPostData data;
  const _FeedPost({required this.data});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      onTap: () {},
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TT.rLg),
        child: Stack(
          children: [
            if (data.hazard)
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(width: 3, color: TT.amber),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthorRow(data: data),
                  const SizedBox(height: 12),
                  Text(
                    data.text,
                    style: TT.body(size: 13, w: FontWeight.w500)
                        .copyWith(height: 1.5),
                  ),
                  if (data.stats != null) ...[
                    const SizedBox(height: 12),
                    _StatBar(stats: data.stats!),
                  ],
                  if (data.attached == _Attachment.elev) ...[
                    const SizedBox(height: 12),
                    const _MiniElevChart(),
                  ],
                  if (data.attached == _Attachment.gpx) ...[
                    const SizedBox(height: 12),
                    _GpxCard(name: data.gpxName ?? '', meta: data.gpxMeta ?? ''),
                  ],
                  const SizedBox(height: 12),
                  Container(height: 1, color: TT.line),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _ActionBtn(icon: Icons.favorite_border, value: '${data.likes}'),
                      const SizedBox(width: 18),
                      _ActionBtn(icon: Icons.mode_comment_outlined, value: '${data.comments}'),
                      const SizedBox(width: 18),
                      const _ActionBtn(icon: Icons.send, value: 'Share'),
                      const Spacer(),
                      const Icon(Icons.more_horiz, size: 14, color: TT.text3),
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
  final _FeedPostData data;
  const _AuthorRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: data.color, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [data.color, data.color.withOpacity(0.66)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            data.initials,
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
                    child: Text(data.user,
                        style: TT.body(size: 13, w: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.time,
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
                      data.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TT.mono(size: 10, color: TT.ember)
                          .copyWith(letterSpacing: 0.06 * 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (data.hazard) ...[
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

class _StatBar extends StatelessWidget {
  final _PostStats stats;
  const _StatBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TT.bg3,
        border: Border.all(color: TT.line, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: _StatChip(label: 'DIST', value: stats.dist)),
          Expanded(child: _StatChip(label: 'GAIN', value: stats.gain, ember: true)),
          Expanded(child: _StatChip(label: 'TIME', value: stats.time)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool ember;
  const _StatChip({required this.label, required this.value, this.ember = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TT.body(size: 9, w: FontWeight.w700, color: TT.text3)
                .copyWith(letterSpacing: 0.14 * 9)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TT.numStyle(
            size: 12.5,
            color: ember ? TT.ember : TT.text,
            letterSpacing: -0.01 * 12.5,
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

class _GpxCard extends StatelessWidget {
  final String name;
  final String meta;
  const _GpxCard({required this.name, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TT.bg3,
        border: Border.all(color: TT.line, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: TT.emberDim,
              border: Border.all(color: const Color(0x52FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.route, size: 14, color: TT.ember),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TT.body(size: 11.5, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TT.mono(size: 9.5, color: TT.text3)
                        .copyWith(letterSpacing: 0.04 * 9.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0x08FFFFFF),
              border: Border.all(color: TT.line, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.arrow_upward, size: 12, color: TT.ember),
          ),
        ],
      ),
    );
  }
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

class _ChatMsgData {
  final String time;
  final String? who;
  final String? initials;
  final Color? color;
  final String text;
  final bool mine;
  final bool system;
  final String? reaction;

  const _ChatMsgData({
    required this.time,
    required this.text,
    this.who,
    this.initials,
    this.color,
    this.mine = false,
    this.system = false,
    this.reaction,
  });
}

class _ChatView extends StatelessWidget {
  const _ChatView({super.key});

  static const List<_ChatMsgData> _messages = [
    _ChatMsgData(time: '09:42', who: 'Sarah L.', initials: 'SL', color: Color(0xFFFF8A4D),
        text: 'At Shadow Lake. Going to push for Liberty Cap by 11.'),
    _ChatMsgData(time: '09:46', mine: true,
        text: "Copy. We're 20 min behind. Mike's pace dropped a bit, all good though."),
    _ChatMsgData(time: '09:48', who: 'Mike K.', initials: 'MK', color: Color(0xFF4CC38A),
        text: "Took a bad step. Knee's stiff but walkable."),
    _ChatMsgData(time: '09:51', who: 'Emily R.', initials: 'ER', color: Color(0xFFF2A93B),
        text: "I'll wait at the Wonderland junction. Bring the trekking pole.",
        reaction: '🙏'),
    _ChatMsgData(time: '09:53', mine: true, text: 'On our way. ETA 14 min.', reaction: '👍'),
    _ChatMsgData(time: '09:58', who: 'Sarah L.', initials: 'SL', color: Color(0xFFFF8A4D),
        text: "Storm moving in around 13:00. Let's tag the summit and head down."),
    _ChatMsgData(time: '10:08', mine: true, system: true,
        text: 'You shared your location · Sunrise Camp'),
  ];

  @override
  Widget build(BuildContext context) {
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
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              return Padding(
                padding: EdgeInsets.only(bottom: i == _messages.length - 1 ? 0 : 10),
                child: _FadeUpDelayed(
                  delay: Duration(milliseconds: 180 + i * 80),
                  child: _ChatMsg(data: _messages[i]),
                ),
              );
            },
          ),
        ),
        const _ChatComposer(),
      ],
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
                Text('Alpine Adventure · Team Chat',
                    style: TT.body(size: 12.5, w: FontWeight.w800, color: TT.ember)),
                const SizedBox(height: 2),
                Text('4 ACTIVE · TRAIL #DAY-3',
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
  final _ChatMsgData data;
  const _ChatMsg({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          data.text,
          textAlign: TextAlign.center,
          style: TT.mono(size: 10, color: TT.text3)
              .copyWith(letterSpacing: 0.06 * 10),
        ),
      );
    }

    final mine = data.mine;
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

    return LayoutBuilder(builder: (_, c) {
      final maxBubbleW = c.maxWidth * 0.74;
      final avatar = !mine
          ? Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: data.color ?? TT.ember, width: 1.5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    data.color ?? TT.ember,
                    (data.color ?? TT.ember).withOpacity(0.66),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                data.initials ?? '',
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
                '${data.who ?? ''} · ${data.time}',
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
                data.text,
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
                    data.time,
                    style: TT.mono(size: 9.5, color: TT.text3)
                        .copyWith(letterSpacing: 0.04 * 9.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, size: 12, color: TT.green),
                ],
              ),
            ),
          if (data.reaction != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: TT.surf2,
                  border: Border.all(color: TT.line, width: 1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(data.reaction!, style: const TextStyle(fontSize: 13)),
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
  const _ChatComposer();

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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: TT.surf,
                  border: Border.all(color: TT.line, width: 1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Message…',
                        style: TT.body(size: 13, w: FontWeight.w500, color: TT.text3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.visibility_outlined, size: 16, color: TT.text3),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
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
              child: const Icon(Icons.send, size: 16, color: TT.emberInk),
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
