// Trailtether 2.0 — Team screen.
//
// Recreates project/screens/team.jsx from the design bundle: brand bar +
// three summary stat tiles, a live team map preview with avatar pins +
// animated blue trail, scrollable team roster, and an ember "START HIKE"
// FAB. Uses placeholder team data only — no provider/service imports.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

enum _MemberStatus { onTrail, atCamp, offGrid }

class _TeamMember {
  final String name;
  final String initial;
  final String subStatus; // e.g. "Sunrise Camp"
  final _MemberStatus status;
  final int batteryPct;
  final String lastSeen;
  final double mapX; // 0..1
  final double mapY; // 0..1
  final bool lead;

  const _TeamMember({
    required this.name,
    required this.initial,
    required this.subStatus,
    required this.status,
    required this.batteryPct,
    required this.lastSeen,
    required this.mapX,
    required this.mapY,
    this.lead = false,
  });
}

const List<_TeamMember> _kTeam = [
  _TeamMember(
    name: 'John D.',
    initial: 'J',
    subStatus: 'Sunrise Camp',
    status: _MemberStatus.onTrail,
    batteryPct: 84,
    lastSeen: '00:12',
    mapX: 0.36,
    mapY: 0.53,
    lead: true,
  ),
  _TeamMember(
    name: 'Sarah L.',
    initial: 'S',
    subStatus: 'Shadow Lake',
    status: _MemberStatus.onTrail,
    batteryPct: 64,
    lastSeen: '00:35',
    mapX: 0.61,
    mapY: 0.44,
  ),
  _TeamMember(
    name: 'Mike K.',
    initial: 'M',
    subStatus: 'Berkeley Park',
    status: _MemberStatus.atCamp,
    batteryPct: 71,
    lastSeen: '01:08',
    mapX: 0.27,
    mapY: 0.78,
  ),
  _TeamMember(
    name: 'Emily R.',
    initial: 'E',
    subStatus: 'Frozen Lake',
    status: _MemberStatus.offGrid,
    batteryPct: 22,
    lastSeen: '04:47',
    mapX: 0.76,
    mapY: 0.49,
  ),
];

Color _statusColor(_MemberStatus s) {
  switch (s) {
    case _MemberStatus.onTrail:
      return TT.green;
    case _MemberStatus.atCamp:
      return TT.amber;
    case _MemberStatus.offGrid:
      return TT.red;
  }
}

Color _pinColor(_MemberStatus s) {
  switch (s) {
    case _MemberStatus.onTrail:
      return TT.ember;
    case _MemberStatus.atCamp:
      return TT.amber;
    case _MemberStatus.offGrid:
      return TT.red;
  }
}

String _statusLabel(_MemberStatus s) {
  switch (s) {
    case _MemberStatus.onTrail:
      return 'On trail';
    case _MemberStatus.atCamp:
      return 'At camp';
    case _MemberStatus.offGrid:
      return 'Off grid';
  }
}

class TTTeamScreen extends StatefulWidget {
  final bool embedded;
  const TTTeamScreen({super.key, this.embedded = false});

  @override
  State<TTTeamScreen> createState() => _TTTeamScreenState();
}

class _TTTeamScreenState extends State<TTTeamScreen> {
  @override
  Widget build(BuildContext context) {
    final activeCount = _kTeam
        .where((m) => m.status != _MemberStatus.offGrid)
        .length;
    const totalDistanceMi = 8.4;

    final body = Stack(
      children: [
        const Positioned.fill(child: TTAmbient()),
        const Positioned.fill(child: TTTopoBackdrop(opacity: 0.5)),
        SafeArea(
          top: !widget.embedded,
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  TTPageAppBar(
                    title: 'Team',
                    trailing: [
                      TTIconBtn(icon: Icons.chat_bubble_outline, onTap: () {}),
                      TTIconBtn(icon: Icons.settings_outlined, onTap: () {}),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                          child: _SummaryRow(
                            members: _kTeam.length,
                            active: activeCount,
                            distanceMi: totalDistanceMi,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                          child: _TeamMapPreview(members: _kTeam),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text('ACTIVE TEAM',
                                      style: TT.label(
                                          size: 11,
                                          color: TT.ember,
                                          letterSpacing: 0.16 * 11)),
                                  const SizedBox(width: 8),
                                  TTPill(
                                    label: '${_kTeam.length}',
                                    variant: TTPillVariant.ember,
                                  ),
                                ],
                              ),
                              Text('UPDATED 10:09:11',
                                  style: TT.mono(size: 10, color: TT.text3)),
                            ],
                          ),
                        ),
                        ...List.generate(_kTeam.length, (i) {
                          return Padding(
                            padding:
                                const EdgeInsets.fromLTRB(18, 0, 18, 10),
                            child: _FadeUpDelayed(
                              delay: Duration(milliseconds: 400 + i * 90),
                              child: _TeamRow(member: _kTeam[i]),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 18,
                bottom: 24,
                child: TTFAB(
                  icon: Icons.play_arrow,
                  label: 'START HIKE',
                  onTap: () {},
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

// ──────────────────────────── SUMMARY ROW ───────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int members;
  final int active;
  final double distanceMi;
  const _SummaryRow({
    required this.members,
    required this.active,
    required this.distanceMi,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.group_outlined,
            label: 'Members',
            value: '$members',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.bolt_outlined,
            label: 'Active',
            value: '$active',
            ember: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.place_outlined,
            label: 'Distance',
            value: distanceMi.toStringAsFixed(1),
            unit: 'mi',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final bool ember;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: ember ? TT.emberDim : const Color(0x08FFFFFF),
                  border: Border.all(
                    color: ember ? const Color(0x52FF6A2C) : TT.line2,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(icon,
                    size: 12, color: ember ? TT.ember : TT.text2),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TT.label(size: 10, color: TT.text3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TTCountUp(
                text: value,
                style: TT.numStyle(
                    size: 22, color: ember ? TT.ember : TT.text),
                delay: const Duration(milliseconds: 250),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!, style: TT.mono(size: 11, color: TT.text2)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── MAP PREVIEW ───────────────────────────────────

class _TeamMapPreview extends StatefulWidget {
  final List<_TeamMember> members;
  const _TeamMapPreview({required this.members});

  @override
  State<_TeamMapPreview> createState() => _TeamMapPreviewState();
}

class _TeamMapPreviewState extends State<_TeamMapPreview>
    with TickerProviderStateMixin {
  late final AnimationController _drawCtl;
  late final AnimationController _pulseCtl;
  late final List<AnimationController> _popCtls;

  @override
  void initState() {
    super.initState();
    _drawCtl = AnimationController(vsync: this, duration: TT.dDraw)..forward();
    _pulseCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _popCtls = List.generate(widget.members.length, (i) {
      final c =
          AnimationController(vsync: this, duration: TT.dSlow);
      Future.delayed(Duration(milliseconds: 500 + i * 100), () {
        if (mounted) c.forward();
      });
      return c;
    });
  }

  @override
  void dispose() {
    _drawCtl.dispose();
    _pulseCtl.dispose();
    for (final c in _popCtls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(TT.rLg),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_drawCtl, _pulseCtl, ..._popCtls]),
              builder: (_, __) {
                return CustomPaint(
                  painter: _TeamMapPainter(
                    members: widget.members,
                    drawT: TT.drawCurve.transform(_drawCtl.value),
                    pulseT: _pulseCtl.value,
                    popT: _popCtls
                        .map((c) => TT.easeOut.transform(c.value))
                        .toList(),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              left: 10,
              child: _LiveTag(),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: TTGlass(
                padding: const EdgeInsets.all(8),
                onTap: () {},
                child:
                    const Icon(Icons.gps_fixed, size: 16, color: TT.ember),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TTGlass(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _MapPulseDot(color: TT.green),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: TT.mono(size: 9.5, color: TT.green)
                .copyWith(letterSpacing: 0.12 * 9.5),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 10, color: TT.line3),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: TT.body(size: 10, w: FontWeight.w800, color: TT.text)
                  .copyWith(letterSpacing: 0.18 * 10),
              children: const [
                TextSpan(text: 'TREK-'),
                TextSpan(text: 'WATCH', style: TextStyle(color: TT.ember)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPulseDot extends StatefulWidget {
  final Color color;
  const _MapPulseDot({required this.color});
  @override
  State<_MapPulseDot> createState() => _MapPulseDotState();
}

class _MapPulseDotState extends State<_MapPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_ctl),
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color, blurRadius: 6)],
        ),
      ),
    );
  }
}

class _TeamMapPainter extends CustomPainter {
  final List<_TeamMember> members;
  final double drawT;
  final double pulseT;
  final List<double> popT;

  _TeamMapPainter({
    required this.members,
    required this.drawT,
    required this.pulseT,
    required this.popT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Backdrop wash — deep moss green to ink, like the design's radial.
    final bgRect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.1),
        radius: 0.9,
        colors: [Color(0xFF1F3327), Color(0xFF152821), Color(0xFF0A0C0F)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Topo contours
    final topoBack = Paint()
      ..color = const Color(0x99041109)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    final topoFront = Paint()
      ..color = const Color(0x8C2A4036)
      ..strokeWidth = 0.45
      ..style = PaintingStyle.stroke;

    void drawWaves(Paint paint, List<List<double>> rows) {
      for (final r in rows) {
        final p = Path()..moveTo(-20, r[0] * size.height);
        p.quadraticBezierTo(
          size.width * 0.25,
          r[1] * size.height,
          size.width * 0.5,
          r[2] * size.height,
        );
        p.quadraticBezierTo(
          size.width * 0.75,
          r[3] * size.height,
          size.width + 20,
          r[4] * size.height,
        );
        canvas.drawPath(p, paint);
      }
    }

    drawWaves(topoBack, const [
      [0.82, 0.76, 0.74, 0.73, 0.78],
      [0.69, 0.57, 0.59, 0.62, 0.67],
      [0.56, 0.41, 0.47, 0.51, 0.56],
      [0.47, 0.28, 0.36, 0.42, 0.47],
      [0.38, 0.19, 0.28, 0.34, 0.39],
      [0.30, 0.13, 0.23, 0.27, 0.34],
      [0.24, 0.09, 0.19, 0.22, 0.30],
    ]);
    drawWaves(topoFront, const [
      [0.88, 0.81, 0.80, 0.79, 0.84],
      [0.75, 0.66, 0.66, 0.67, 0.73],
      [0.63, 0.50, 0.53, 0.56, 0.63],
      [0.50, 0.34, 0.41, 0.45, 0.50],
      [0.41, 0.23, 0.31, 0.36, 0.42],
    ]);

    // Trail path — animated draw line, two stacked strokes for glow.
    final trail = Path()
      ..moveTo(size.width * 0.10, size.height * 0.89)
      ..quadraticBezierTo(
        size.width * 0.24, size.height * 0.69,
        size.width * 0.36, size.height * 0.56,
      )
      ..quadraticBezierTo(
        size.width * 0.49, size.height * 0.44,
        size.width * 0.63, size.height * 0.41,
      )
      ..quadraticBezierTo(
        size.width * 0.78, size.height * 0.41,
        size.width * 0.88, size.height * 0.25,
      );

    final metrics = trail.computeMetrics().toList();
    final totalLen =
        metrics.fold<double>(0, (sum, m) => sum + m.length);
    final drawLen = totalLen * drawT.clamp(0.0, 1.0);

    final drawn = Path();
    double consumed = 0;
    for (final m in metrics) {
      if (consumed >= drawLen) break;
      final remain = drawLen - consumed;
      final extract = m.extractPath(0, math.min(m.length, remain));
      drawn.addPath(extract, Offset.zero);
      consumed += m.length;
    }

    final trailGlow = Paint()
      ..color = TT.blue.withOpacity(0.35)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final trailStroke = Paint()
      ..color = TT.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(drawn, trailGlow);
    canvas.drawPath(drawn, trailStroke);

    // Peaks
    _drawPeak(canvas, Offset(size.width * 0.85, size.height * 0.24));
    _drawPeak(canvas,
        Offset(size.width * 0.93, size.height * 0.41), small: true);
    _drawPeak(canvas,
        Offset(size.width * 0.54, size.height * 0.53), small: true);

    // Member pins (drawn on top of trail)
    for (var i = 0; i < members.length; i++) {
      final m = members[i];
      final c = Offset(size.width * m.mapX, size.height * m.mapY);
      final t = popT[i];
      if (t <= 0) continue;
      _drawAvatarPin(canvas, c, m, t);
    }
  }

  void _drawPeak(Canvas canvas, Offset c, {bool small = false}) {
    final r = small ? 4.0 : 5.0;
    final p = Path()
      ..moveTo(c.dx - r, c.dy + r)
      ..lineTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy + r)
      ..close();
    canvas.drawPath(
      p,
      Paint()..color = const Color(0xFFEEF1F4),
    );
    canvas.drawPath(
      p,
      Paint()
        ..color = const Color(0xFF0A0C0F)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawAvatarPin(
      Canvas canvas, Offset c, _TeamMember m, double t) {
    final color = _pinColor(m.status);
    final scale = 0.7 + 0.3 * t;

    // Pulsing halo
    final haloT = pulseT;
    final haloR = (16 + 10 * haloT) * scale;
    final haloOpacity = (0.18 * (1 - haloT)).clamp(0.0, 0.18) * t;
    final halo = Paint()..color = color.withOpacity(haloOpacity);
    canvas.drawCircle(c, haloR, halo);

    // Pin tail (triangle pointing down)
    final tail = Path()
      ..moveTo(c.dx, c.dy + 18 * scale)
      ..lineTo(c.dx - 5 * scale, c.dy + 10 * scale)
      ..lineTo(c.dx + 5 * scale, c.dy + 10 * scale)
      ..close();
    canvas.drawPath(
      tail,
      Paint()..color = color.withOpacity(t),
    );

    // Ring
    final ringR = 12.0 * scale;
    canvas.drawCircle(
      c,
      ringR,
      Paint()..color = const Color(0xFF1A1D22).withOpacity(t),
    );
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..color = color.withOpacity(t)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      c,
      ringR - 2,
      Paint()..color = color.withOpacity(0.18 * t),
    );

    // Initial letter
    final tp = TextPainter(
      text: TextSpan(
        text: m.initial,
        style: TT
            .body(
              size: 11,
              w: FontWeight.w900,
              color: Colors.white.withOpacity(t),
            )
            .copyWith(height: 1),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_TeamMapPainter old) =>
      old.drawT != drawT ||
      old.pulseT != pulseT ||
      !_listEq(old.popT, popT);

  bool _listEq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ──────────────────────────── TEAM ROW ──────────────────────────────────────

class _TeamRow extends StatelessWidget {
  final _TeamMember member;
  const _TeamRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final ringColor = _statusColor(member.status);
    final tileColor = _pinColor(member.status);
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () {},
      child: Stack(
        children: [
          if (member.lead)
            Positioned(
              left: -14,
              top: 6,
              bottom: 6,
              child: Container(
                width: 3,
                decoration: const BoxDecoration(
                  color: TT.ember,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x80FF6A2C), blurRadius: 8),
                  ],
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AvatarBlock(
                  initial: member.initial,
                  tileColor: tileColor,
                  ringColor: ringColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            style: TT.body(size: 14.5, w: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (member.lead) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: TT.emberDim,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LEAD',
                              style: TT
                                  .mono(
                                      size: 8.5,
                                      color: TT.ember,
                                      w: FontWeight.w800)
                                  .copyWith(letterSpacing: 0.12 * 8.5),
                            ),
                          ),
                        ],
                        if (member.status == _MemberStatus.offGrid) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.warning_amber_rounded,
                              size: 14, color: TT.red),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: ringColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: ringColor, blurRadius: 5),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _statusLabel(member.status),
                          style: TT.mono(
                              size: 10.5,
                              color: ringColor,
                              w: FontWeight.w800),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 1, height: 9, color: TT.line3),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            member.subStatus,
                            style: TT.mono(size: 10.5, color: TT.text3),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BattRow(pct: member.batteryPct),
                  const SizedBox(height: 6),
                  Text(
                    member.lastSeen,
                    style: TT.mono(size: 10, color: TT.text3),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 16, color: TT.text3),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  final String initial;
  final Color tileColor;
  final Color ringColor;
  const _AvatarBlock({
    required this.initial,
    required this.tileColor,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tileColor, tileColor.withOpacity(0.66)],
              ),
              border: Border.all(color: tileColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: tileColor.withOpacity(0.33),
                  blurRadius: 14,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style:
                  TT.body(size: 16, w: FontWeight.w800, color: Colors.white),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ringColor,
                border: Border.all(color: TT.surf, width: 2.5),
                boxShadow: [
                  BoxShadow(color: ringColor, blurRadius: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattRow extends StatelessWidget {
  final int pct;
  const _BattRow({required this.pct});

  @override
  Widget build(BuildContext context) {
    final lowBatt = pct <= 25;
    final mediumBatt = pct > 25 && pct <= 50;
    final color = lowBatt
        ? TT.red
        : mediumBatt
            ? TT.amber
            : TT.green;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Battery icon
        Container(
          width: 22,
          height: 10,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            border: Border.all(color: TT.line3, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: (pct / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$pct%',
          style: TT.mono(size: 10.5, color: color, w: FontWeight.w800),
        ),
      ],
    );
  }
}

// ──────────────────────────── ANIMATION HELPER ──────────────────────────────

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

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
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
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = TT.easeOut.transform(_ctl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: widget.child,
          ),
        );
      },
    );
  }
}
