// Trailtether 2.0 — Home screen.
//
// Recreates project/screens/home.jsx from the design bundle: layered mountain
// hero with an ember sun, welcome row, 4 quick-action tiles, upcoming hike
// with countdown, weather card (animated sun rotation + cloud drift + 5-hour
// strip), last-hike card backed by TTBigElevChart, and a field-intel strip.
// All sections enter via staggered fade-up animations.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_elev_chart.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

class TTHomeScreen extends StatefulWidget {
  final bool embedded;
  final ValueChanged<int>? onNavigate;

  const TTHomeScreen({
    super.key,
    this.embedded = false,
    this.onNavigate,
  });

  @override
  State<TTHomeScreen> createState() => _TTHomeScreenState();
}

class _TTHomeScreenState extends State<TTHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        const Positioned.fill(child: TTAmbient()),
        const Positioned.fill(child: TTTopoBackdrop(opacity: 0.5)),
        SafeArea(
          top: !widget.embedded,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const _HomeHero(),
              const SizedBox(height: 4),
              _HomeQuickActions(onNavigate: widget.onNavigate),
              const _UpcomingHikeCard(),
              const _WeatherCard(),
              const _LastHikeCard(),
              const _FieldIntelStrip(),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

// ─────────────────────────────────── HERO ───────────────────────────────────

class _HomeHero extends StatefulWidget {
  const _HomeHero();

  @override
  State<_HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<_HomeHero> with SingleTickerProviderStateMixin {
  late final AnimationController _starCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat();

  late final AnimationController _entryCtl = AnimationController(
    vsync: this,
    duration: TT.dSlow,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _entryCtl.forward();
    });
  }

  @override
  void dispose() {
    _starCtl.dispose();
    _entryCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _starCtl,
              builder: (_, __) => CustomPaint(
                painter: _HeroMountainPainter(starPhase: _starCtl.value),
              ),
            ),
          ),
          // Bottom fade to body
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x99070A0E),
                      TT.bg,
                    ],
                    stops: [0.0, 0.5, 0.8, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Top brand row
          Positioned(
            top: 14,
            left: 18,
            right: 18,
            child: _HeroBrandRow(entry: _entryCtl),
          ),
          // Greeting overlay
          Positioned(
            left: 22,
            right: 22,
            bottom: 18,
            child: AnimatedBuilder(
              animation: _entryCtl,
              builder: (_, child) {
                final t = TT.easeOut.transform(_entryCtl.value);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 14),
                    child: child,
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WELCOME BACK,',
                    style: TT.mono(size: 11, color: TT.ember).copyWith(
                      letterSpacing: 0.2 * 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'John D.',
                    style: TT.title(32, letterSpacing: -0.025 * 32).copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBrandRow extends StatelessWidget {
  final AnimationController entry;
  const _HeroBrandRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entry,
      builder: (_, child) {
        final t = TT.easeOut.transform(entry.value);
        return Opacity(opacity: t, child: child);
      },
      child: Row(
        children: [
          const Expanded(child: TTBrandMark()),
          TTIconBtn(icon: Icons.notifications_outlined, onTap: () {}),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TT.ember, width: 2),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6B3A1A), TT.ember2],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x73FF6A2C), blurRadius: 14),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'JD',
              style: TT.body(size: 13, w: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMountainPainter extends CustomPainter {
  final double starPhase;
  _HeroMountainPainter({required this.starPhase});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = w / 412.0; // design width
    final hs = h / 240.0; // design height

    // Sky gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1F28), Color(0xFF0D1116), Color(0xFF06080B)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // Ember sun glow (radial)
    final sunCenter = Offset(320 * s, 85 * hs);
    final sunGlow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xBFFF8A4D), Color(0x00FF6A2C)],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 80 * s));
    canvas.drawCircle(sunCenter, 80 * s, sunGlow);

    // Sun core layers
    canvas.drawCircle(
      sunCenter,
      38 * s,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xBFFF8A4D), Color(0x00FF6A2C)],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: 38 * s)),
    );
    canvas.drawCircle(
      sunCenter,
      22 * s,
      Paint()..color = const Color(0x8CFF8A4D),
    );
    canvas.drawCircle(
      sunCenter,
      14 * s,
      Paint()..color = const Color(0xD9FFB486),
    );

    // Distant stars (twinkle)
    const starPts = [
      [55.0, 40.0, 1.0, 0.0],
      [120.0, 30.0, 0.8, 0.4],
      [180.0, 22.0, 1.2, 0.8],
      [50.0, 80.0, 0.7, 1.2],
      [240.0, 38.0, 1.0, 1.6],
    ];
    for (final p in starPts) {
      final phase = (starPhase + p[3] / 3.0) % 1.0;
      final twinkle = 0.45 + 0.25 * math.sin(phase * 2 * math.pi);
      final paint = Paint()..color = Colors.white.withOpacity(twinkle);
      canvas.drawCircle(Offset(p[0] * s, p[1] * hs), p[2] * s, paint);
    }

    // Back range
    final backPath = Path()
      ..moveTo(-10 * s, 170 * hs)
      ..lineTo(50 * s, 115 * hs)
      ..lineTo(95 * s, 145 * hs)
      ..lineTo(140 * s, 95 * hs)
      ..lineTo(200 * s, 130 * hs)
      ..lineTo(250 * s, 105 * hs)
      ..lineTo(310 * s, 140 * hs)
      ..lineTo(360 * s, 110 * hs)
      ..lineTo(420 * s, 145 * hs)
      ..lineTo(420 * s, 240 * hs)
      ..lineTo(-10 * s, 240 * hs)
      ..close();
    canvas.drawPath(
      backPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A313C), Color(0xFF11161C)],
        ).createShader(Rect.fromLTWH(0, 100 * hs, w, 140 * hs))
        ..color = const Color(0xD9000000),
    );

    // Mid range
    final midPath = Path()
      ..moveTo(-10 * s, 200 * hs)
      ..lineTo(30 * s, 165 * hs)
      ..lineTo(80 * s, 185 * hs)
      ..lineTo(140 * s, 140 * hs)
      ..lineTo(180 * s, 170 * hs)
      ..lineTo(230 * s, 150 * hs)
      ..lineTo(290 * s, 180 * hs)
      ..lineTo(340 * s, 155 * hs)
      ..lineTo(420 * s, 185 * hs)
      ..lineTo(420 * s, 240 * hs)
      ..lineTo(-10 * s, 240 * hs)
      ..close();
    canvas.drawPath(midPath, Paint()..color = const Color(0xFF171C25));

    // Front range
    final frontPath = Path()
      ..moveTo(-10 * s, 240 * hs)
      ..lineTo(10 * s, 220 * hs)
      ..lineTo(60 * s, 205 * hs)
      ..lineTo(100 * s, 218 * hs)
      ..lineTo(170 * s, 198 * hs)
      ..lineTo(220 * s, 215 * hs)
      ..lineTo(280 * s, 200 * hs)
      ..lineTo(340 * s, 220 * hs)
      ..lineTo(420 * s, 210 * hs)
      ..lineTo(420 * s, 240 * hs)
      ..close();
    canvas.drawPath(
      frontPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2029), Color(0xFF0A0C0F)],
        ).createShader(Rect.fromLTWH(0, 195 * hs, w, 45 * hs)),
    );

    // Snow on top peak
    final snowPath = Path()
      ..moveTo(135 * s, 100 * hs)
      ..lineTo(140 * s, 95 * hs)
      ..lineTo(146 * s, 105 * hs)
      ..lineTo(142 * s, 102 * hs)
      ..close();
    canvas.drawPath(snowPath, Paint()..color = const Color(0xB3EEF1F4));

    // Topo motif overlay (very faint)
    final topoPaint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final topo1 = Path()
      ..moveTo(-10 * s, 180 * hs)
      ..quadraticBezierTo(100 * s, 165 * hs, 200 * s, 168 * hs)
      ..quadraticBezierTo(310 * s, 171 * hs, 420 * s, 175 * hs);
    final topo2 = Path()
      ..moveTo(-10 * s, 200 * hs)
      ..quadraticBezierTo(100 * s, 188 * hs, 200 * s, 190 * hs)
      ..quadraticBezierTo(310 * s, 192 * hs, 420 * s, 198 * hs);
    canvas.drawPath(topo1, topoPaint);
    canvas.drawPath(topo2, topoPaint);
  }

  @override
  bool shouldRepaint(_HeroMountainPainter old) => old.starPhase != starPhase;
}

// ─────────────────────────── QUICK ACTION TILES ─────────────────────────────

class _HomeQuickActions extends StatelessWidget {
  final ValueChanged<int>? onNavigate;
  const _HomeQuickActions({this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.play_arrow_rounded,
        label: 'Start Hike',
        color: TT.ember,
        primary: true,
        onTap: () => onNavigate?.call(1),
      ),
      _QuickAction(
        icon: Icons.alt_route_rounded,
        label: 'Plan Route',
        color: TT.text2,
        onTap: () => onNavigate?.call(1),
      ),
      _QuickAction(
        icon: Icons.visibility_outlined,
        label: 'Live Track',
        color: TT.blue,
        onTap: () => onNavigate?.call(2),
      ),
      _QuickAction(
        icon: Icons.radio_button_checked,
        label: 'SOS',
        color: TT.red,
        onTap: () {},
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: TTStagger(
        axis: Axis.horizontal,
        base: const Duration(milliseconds: 350),
        step: const Duration(milliseconds: 70),
        gap: 8,
        children: actions.map((a) => Expanded(child: _QuickActionTile(action: a))).toList(),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final bool primary;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.primary = false,
    required this.onTap,
  });
}

class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final primary = a.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: a.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: TT.dFast,
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            color: primary ? TT.emberDim : TT.surf,
            border: Border.all(
              color: primary ? const Color(0x5CFF6A2C) : TT.line,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: primary
                ? const [
                    BoxShadow(
                      color: Color(0x2EFF6A2C),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary
                      ? const Color(0x2EFF6A2C)
                      : Color.alphaBlend(a.color.withOpacity(0.06), TT.surf),
                  border: Border.all(
                    color: primary ? const Color(0x80FF6A2C) : TT.line2,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(a.icon, size: 17, color: a.color),
              ),
              const SizedBox(height: 7),
              Text(
                a.label.toUpperCase(),
                style: TT.body(
                  size: 9.5,
                  w: FontWeight.w800,
                  color: primary ? TT.ember : TT.text,
                ).copyWith(letterSpacing: 0.1 * 9.5),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── UPCOMING HIKE CARD ─────────────────────────────

class _UpcomingHikeCard extends StatefulWidget {
  const _UpcomingHikeCard();

  @override
  State<_UpcomingHikeCard> createState() => _UpcomingHikeCardState();
}

class _UpcomingHikeCardState extends State<_UpcomingHikeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 650), () {
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, child) {
          final t = TT.easeOut.transform(_ctl.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 14),
              child: child,
            ),
          );
        },
        child: TTCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          onTap: () {},
          child: Stack(
            children: [
              // Ember corner glow
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x38FF6A2C), Color(0x00FF6A2C)],
                      stops: [0.0, 0.7],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _PulseDot(color: TT.ember),
                          const SizedBox(width: 6),
                          Text(
                            'UPCOMING · IN 2 DAYS',
                            style: TT.mono(size: 10, color: TT.ember).copyWith(
                              letterSpacing: 0.18 * 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const TTPill(label: '4 GOING', variant: TTPillVariant.ember),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Mt. Marcy Summit',
                    style: TT.title(19, letterSpacing: -0.01 * 19),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'OCT 28 · 06:00 START · 12.4 KM',
                    style: TT.mono(size: 11, color: TT.text3, w: FontWeight.w600)
                        .copyWith(letterSpacing: 0.04 * 11),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _AvatarStack(
                        entries: [
                          _AvatarEntry('J', Color(0xFFFF6A2C)),
                          _AvatarEntry('S', Color(0xFFFF8A4D)),
                          _AvatarEntry('M', Color(0xFF4CC38A)),
                          _AvatarEntry('E', Color(0xFFF2A93B)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'STARTS IN',
                                style: TT.body(size: 9, w: FontWeight.w700, color: TT.text3)
                                    .copyWith(letterSpacing: 0.16 * 9),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '2d 19h',
                                style: TT.numStyle(size: 17, letterSpacing: -0.02 * 17),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, size: 16, color: TT.text3),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarEntry {
  final String initial;
  final Color color;
  const _AvatarEntry(this.initial, this.color);
}

class _AvatarStack extends StatelessWidget {
  final List<_AvatarEntry> entries;
  const _AvatarStack({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: 30.0 + (entries.length - 1) * 20.0,
      child: Stack(
        children: List.generate(entries.length, (i) {
          final e = entries[i];
          return Positioned(
            left: i * 20.0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: e.color,
                shape: BoxShape.circle,
                border: Border.all(color: TT.surf, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                e.initial,
                style: TT.body(size: 11, w: FontWeight.w800, color: Colors.white),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
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
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color, blurRadius: 6)],
        ),
      ),
    );
  }
}

// ───────────────────────────── WEATHER CARD ─────────────────────────────────

class _WeatherCard extends StatefulWidget {
  const _WeatherCard();

  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<_WeatherCard> with TickerProviderStateMixin {
  late final AnimationController _sunCtl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();
  late final AnimationController _rayCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);
  late final AnimationController _cloudCtl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);
  late final AnimationController _entryCtl =
      AnimationController(vsync: this, duration: TT.dSlow);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) _entryCtl.forward();
    });
  }

  @override
  void dispose() {
    _sunCtl.dispose();
    _rayCtl.dispose();
    _cloudCtl.dispose();
    _entryCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: AnimatedBuilder(
        animation: _entryCtl,
        builder: (_, child) {
          final t = TT.easeOut.transform(_entryCtl.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 14),
              child: child,
            ),
          );
        },
        child: TTCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TT.body(size: 11, w: FontWeight.w700, color: TT.text2)
                            .copyWith(letterSpacing: 0.16 * 11),
                        children: const [
                          TextSpan(text: 'CONDITIONS · '),
                          TextSpan(
                            text: 'DRAKENSBERG N',
                            style: TextStyle(color: TT.text3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '7 DAYS →',
                    style: TT.mono(size: 10, color: TT.ember, w: FontWeight.w800)
                        .copyWith(letterSpacing: 0.1 * 10),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_sunCtl, _rayCtl, _cloudCtl]),
                      builder: (_, __) => CustomPaint(
                        painter: _WeatherIconPainter(
                          sunPhase: _sunCtl.value,
                          rayPhase: _rayCtl.value,
                          cloudPhase: _cloudCtl.value,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '14°',
                              style: TT.numStyle(
                                size: 32,
                                letterSpacing: -0.025 * 32,
                              ).copyWith(height: 1.0),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'C',
                                style: TT.body(
                                  size: 14,
                                  color: TT.text2,
                                  w: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PART CLOUDY · WIND 18 km/h',
                          style: TT.mono(size: 11, color: TT.text3, w: FontWeight.w600)
                              .copyWith(letterSpacing: 0.05 * 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x244CC38A),
                          border: Border.all(color: const Color(0x524CC38A), width: 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '8',
                              style: TT.numStyle(size: 13, color: TT.green),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '/10',
                              style: TT.body(size: 9.5, color: TT.green, w: FontWeight.w600)
                                  .copyWith(letterSpacing: 0.08 * 9.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HIKE SCORE',
                        style: TT.body(size: 9, color: TT.green, w: FontWeight.w700)
                            .copyWith(letterSpacing: 0.14 * 9),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: TT.line, width: 1)),
                ),
                child: _HourStrip(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HourStrip extends StatelessWidget {
  static const _hours = <_HourEntry>[
    _HourEntry('10', '14°', _WxKind.sun),
    _HourEntry('13', '17°', _WxKind.sun),
    _HourEntry('16', '15°', _WxKind.cloud),
    _HourEntry('19', '11°', _WxKind.cloud),
    _HourEntry('22', '8°', _WxKind.moon),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_hours.length, (i) {
        final h = _hours[i];
        return Expanded(
          child: Column(
            children: [
              Text(
                h.hour,
                style: TT.mono(size: 9, color: TT.text3, w: FontWeight.w700)
                    .copyWith(letterSpacing: 0.06 * 9),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 18,
                child: Center(
                  child: CustomPaint(
                    size: const Size(20, 18),
                    painter: _WxMiniIconPainter(h.icon),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(h.temp, style: TT.mono(size: 11, w: FontWeight.w700)),
            ],
          ),
        );
      }),
    );
  }
}

enum _WxKind { sun, cloud, moon }

class _HourEntry {
  final String hour;
  final String temp;
  final _WxKind icon;
  const _HourEntry(this.hour, this.temp, this.icon);
}

class _WxMiniIconPainter extends CustomPainter {
  final _WxKind kind;
  _WxMiniIconPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    switch (kind) {
      case _WxKind.sun:
        final p = Paint()..color = TT.ember2;
        canvas.drawCircle(Offset(cx, cy), 3, p);
        final ray = Paint()
          ..color = TT.ember2
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(cx + math.cos(a) * 5, cy + math.sin(a) * 5),
            Offset(cx + math.cos(a) * 7, cy + math.sin(a) * 7),
            ray,
          );
        }
        break;
      case _WxKind.cloud:
        final c = Paint()..color = const Color(0xFF5A6470);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx - 3, cy + 2), width: 10, height: 6), c);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx + 3, cy + 2), width: 8, height: 5), c);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy - 1), width: 7, height: 5), c);
        break;
      case _WxKind.moon:
        final m = Paint()..color = const Color(0xFF98A1AC);
        final path = Path()
          ..moveTo(cx + 3, cy + 1.5)
          ..arcToPoint(
            Offset(cx - 2.5, cy - 4),
            radius: const Radius.circular(4.5),
            clockwise: true,
          )
          ..arcToPoint(
            Offset(cx + 3, cy + 1.5),
            radius: const Radius.circular(3.5),
            clockwise: false,
          )
          ..close();
        canvas.drawPath(path, m);
        break;
    }
  }

  @override
  bool shouldRepaint(_WxMiniIconPainter old) => old.kind != kind;
}

class _WeatherIconPainter extends CustomPainter {
  final double sunPhase;
  final double rayPhase;
  final double cloudPhase;
  _WeatherIconPainter({
    required this.sunPhase,
    required this.rayPhase,
    required this.cloudPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const sunCenter = Offset(24, 24);

    // Sun core
    canvas.drawCircle(
      sunCenter,
      14,
      Paint()
        ..shader = const RadialGradient(
          colors: [TT.ember3, TT.ember],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: 14)),
    );

    // Rotating rays
    final rayBase = sunPhase * 2 * math.pi;
    for (var i = 0; i < 8; i++) {
      final a = rayBase + i * math.pi / 4;
      final twinkleOffset = (rayPhase + i * 0.1) % 1.0;
      final opacity = 0.4 + 0.5 * math.sin(twinkleOffset * 2 * math.pi).abs();
      final ray = Paint()
        ..color = TT.ember2.withOpacity(opacity.clamp(0.0, 1.0))
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(sunCenter.dx + math.cos(a) * 18, sunCenter.dy + math.sin(a) * 18),
        Offset(sunCenter.dx + math.cos(a) * 24, sunCenter.dy + math.sin(a) * 24),
        ray,
      );
    }

    // Drifting cloud
    final drift = math.sin(cloudPhase * math.pi) * 3.0;
    final c = Paint()..color = const Color(0xFF2A313C);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(40 + drift, 44), width: 28, height: 18),
      c,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(50 + drift, 46), width: 22, height: 14),
      c,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(44 + drift, 38), width: 18, height: 12),
      c,
    );
  }

  @override
  bool shouldRepaint(_WeatherIconPainter old) =>
      old.sunPhase != sunPhase ||
      old.rayPhase != rayPhase ||
      old.cloudPhase != cloudPhase;
}

// ───────────────────────────── LAST HIKE CARD ───────────────────────────────

class _LastHikeCard extends StatefulWidget {
  const _LastHikeCard();

  @override
  State<_LastHikeCard> createState() => _LastHikeCardState();
}

class _LastHikeCardState extends State<_LastHikeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LAST HIKE',
                  style: TT.body(size: 11, w: FontWeight.w700, color: TT.text2)
                      .copyWith(letterSpacing: 0.16 * 11),
                ),
                Text(
                  'VIEW ALL →',
                  style: TT.body(size: 10, w: FontWeight.w800, color: TT.ember)
                      .copyWith(letterSpacing: 0.1 * 10),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _ctl,
            builder: (_, child) {
              final t = TT.easeOut.transform(_ctl.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 14),
                  child: child,
                ),
              );
            },
            child: TTCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              onTap: () {},
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mt. Marcy Trail',
                              style: TT.body(size: 14, w: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'OCT 26 · 5.8 mi · 5:14:22',
                              style: TT.mono(size: 10.5, color: TT.text3, w: FontWeight.w600)
                                  .copyWith(letterSpacing: 0.04 * 10.5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x214CC38A),
                          border: Border.all(color: const Color(0x4D4CC38A), width: 1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'SYNCED',
                          style: TT.mono(size: 9, color: TT.green, w: FontWeight.w800)
                              .copyWith(letterSpacing: 0.12 * 9),
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Icon(Icons.chevron_right, size: 15, color: TT.text3),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const TTBigElevChart(peakLabel: '5.8 mi · 3,950 ft'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const _StatChip(
                        leading: '↑',
                        value: '3,950',
                        unit: 'ft',
                        valueColor: TT.ember,
                      ),
                      const SizedBox(width: 14),
                      Container(width: 1, height: 12, color: TT.line3),
                      const SizedBox(width: 14),
                      const _StatChip(leading: 'kcal', value: '1,189', unit: 'kcal'),
                      const SizedBox(width: 14),
                      Container(width: 1, height: 12, color: TT.line3),
                      const SizedBox(width: 14),
                      const _StatChip(leading: 'steps', value: '18,432', unit: ''),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String leading;
  final String value;
  final String unit;
  final Color? valueColor;
  const _StatChip({
    required this.leading,
    required this.value,
    required this.unit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          leading,
          style: TT.mono(size: 10, color: TT.text2, w: FontWeight.w700),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TT.numStyle(size: 11, color: valueColor ?? TT.text, w: FontWeight.w800),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(unit, style: TT.mono(size: 10, color: TT.text2, w: FontWeight.w700)),
        ],
      ],
    );
  }
}

// ───────────────────────────── FIELD INTEL STRIP ────────────────────────────

class _FieldIntelStrip extends StatelessWidget {
  const _FieldIntelStrip();

  @override
  Widget build(BuildContext context) {
    const rows = [
      _IntelEntry(
        icon: Icons.warning_amber_rounded,
        color: TT.amber,
        title: 'Loose rock near km 4.8',
        sub: 'Wonderland Trail · reported 18m ago',
      ),
      _IntelEntry(
        icon: Icons.air,
        color: TT.blue,
        title: 'Storm forecast in 90 min',
        sub: 'Consider shelter at km 5.8 · Cave #47',
      ),
      _IntelEntry(
        icon: Icons.group_outlined,
        color: TT.green,
        title: '3 hikers ahead of you',
        sub: 'Last contact 11 min · Sunrise Camp',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'FIELD INTEL',
              style: TT.body(size: 11, w: FontWeight.w700, color: TT.text2)
                  .copyWith(letterSpacing: 0.16 * 11),
            ),
          ),
          TTStagger(
            base: const Duration(milliseconds: 1050),
            step: const Duration(milliseconds: 80),
            gap: 8,
            children: rows.map((e) => _IntelRow(entry: e)).toList(),
          ),
        ],
      ),
    );
  }
}

class _IntelEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  const _IntelEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
  });
}

class _IntelRow extends StatelessWidget {
  final _IntelEntry entry;
  const _IntelRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: TT.surf,
          border: Border(
            top: BorderSide(color: entry.color.withOpacity(0.2), width: 1),
            right: BorderSide(color: entry.color.withOpacity(0.2), width: 1),
            bottom: BorderSide(color: entry.color.withOpacity(0.2), width: 1),
            left: BorderSide(color: entry.color, width: 3),
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: entry.color.withOpacity(0.12),
                border: Border.all(color: entry.color.withOpacity(0.25), width: 1),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(entry.icon, size: 14, color: entry.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: TT.body(size: 12, w: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.sub,
                    style: TT.mono(size: 10, color: TT.text3, w: FontWeight.w500)
                        .copyWith(letterSpacing: 0.02 * 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 14, color: TT.text3),
          ],
        ),
      ),
    );
  }
}
