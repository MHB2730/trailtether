// Trailtether 2.0 — Trail Detail screen.
//
// Recreates project/screens/trail-detail.jsx from the design bundle: a layered
// mountain-silhouette hero with an ember sun, a title card overlapping the
// fade, the 3-up stats row (distance / ascent / duration), a big elevation
// chart with a draggable pace slider overlay, a reviews summary block, a
// horizontal caves-on-route list, and a sticky shimmering "START HIKE" CTA.
//
// Placeholder data only — wiring to the live trail providers belongs to the
// caller; this screen accepts a trailId purely so it can slot into the
// existing navigation surface without modifying other files.

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

class TTTrailDetailScreen extends StatefulWidget {
  final String? trailId;

  const TTTrailDetailScreen({super.key, this.trailId});

  @override
  State<TTTrailDetailScreen> createState() => _TTTrailDetailScreenState();
}

class _TTTrailDetailScreenState extends State<TTTrailDetailScreen>
    with TickerProviderStateMixin {
  // Master entry controller — staggered tweens read fractions off this.
  late final AnimationController _entryCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  // CTA shimmer/breathe controller (subtle pulse on the ember bar).
  late final AnimationController _ctaCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  // Pace slider position, 0 (Slow) .. 1 (Fast). Default is Steady (0.55).
  double _pace = 0.55;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entryCtl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtl.dispose();
    _ctaCtl.dispose();
    super.dispose();
  }

  /// Maps the master controller progress into a per-section [0..1] tween,
  /// fading in `width` of the total run starting at `start`.
  double _stage(double start, {double width = 0.45}) {
    final v = ((_entryCtl.value - start) / width).clamp(0.0, 1.0);
    return TT.easeOut.transform(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop(opacity: 0.45)),
          SafeArea(
            bottom: false,
            child: AnimatedBuilder(
              animation: _entryCtl,
              builder: (_, __) {
                return Column(
                  children: [
                    _TopBar(t: _stage(0.0, width: 0.25)),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 110),
                        children: [
                          _Hero(t: _stage(0.05, width: 0.4)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SlideIn(
                                  t: _stage(0.18, width: 0.4),
                                  offset: const Offset(0, 18),
                                  child: const _TitleCard(),
                                ),
                                const SizedBox(height: 14),
                                _SlideIn(
                                  t: _stage(0.28),
                                  child: const _StatsRow(),
                                ),
                                const SizedBox(height: 14),
                                _SlideIn(
                                  t: _stage(0.36),
                                  child: _ElevationCard(
                                    pace: _pace,
                                    onPaceChange: (v) =>
                                        setState(() => _pace = v),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _SlideIn(
                                  t: _stage(0.46),
                                  child: const _AboutBlock(),
                                ),
                                const SizedBox(height: 18),
                                _SlideIn(
                                  t: _stage(0.54),
                                  child: const _ReviewsBlock(),
                                ),
                                const SizedBox(height: 18),
                                _SlideIn(
                                  t: _stage(0.62),
                                  child: const _CavesBlock(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Sticky CTA — anchored at bottom with a bg fade behind it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyCTA(controller: _ctaCtl),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────── TOP BAR ──────────────────────────────────

class _TopBar extends StatelessWidget {
  final double t;
  const _TopBar({required this.t});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * -8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              TTIconBtn(
                icon: Icons.chevron_left,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TRAIL DETAIL',
                  style: TT.mono(size: 11, color: TT.text3)
                      .copyWith(letterSpacing: 0.16 * 11, fontWeight: FontWeight.w700),
                ),
              ),
              const TTIconBtn(icon: Icons.favorite, ember: true),
              const SizedBox(width: 8),
              const TTIconBtn(icon: Icons.ios_share),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────── HERO IMAGE ────────────────────────────────

class _Hero extends StatefulWidget {
  final double t;
  const _Hero({required this.t});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ctl,
              builder: (_, __) => CustomPaint(
                painter: _HeroMountainPainter(phase: _ctl.value),
              ),
            ),
          ),
          // Bottom fade to body for the title card overlap.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x80070A0E),
                      TT.bg,
                    ],
                    stops: [0.0, 0.5, 0.82, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Top pills
          Positioned(
            top: 14,
            left: 18,
            child: Opacity(
              opacity: widget.t,
              child: Transform.translate(
                offset: Offset(0, (1 - widget.t) * -6),
                child: const Row(
                  children: [
                    TTPill(label: 'FEATURED', variant: TTPillVariant.ember),
                    SizedBox(width: 6),
                    TTPill(label: 'CAVES NEARBY'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMountainPainter extends CustomPainter {
  final double phase;
  _HeroMountainPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = w / 412.0;
    final hs = h / 280.0;

    // Sky gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1D242C), Color(0xFF0A0C0F)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // Ember sun: outer glow → bright core layered three deep.
    final sunCenter = Offset(330 * s, 78 * hs);
    canvas.drawCircle(
      sunCenter,
      54 * s,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xBFFF8A4D), Color(0x00FF6A2C)],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: 54 * s)),
    );
    canvas.drawCircle(
      sunCenter,
      26 * s,
      Paint()..color = const Color(0x8CFF8A4D),
    );
    canvas.drawCircle(
      sunCenter,
      14 * s,
      Paint()..color = const Color(0xE6FFB486),
    );

    // Distant twinkling stars
    const stars = [
      [40.0, 30.0, 1.0, 0.0],
      [110.0, 22.0, 0.8, 0.4],
      [165.0, 38.0, 1.1, 0.8],
      [60.0, 65.0, 0.9, 1.2],
      [230.0, 28.0, 0.7, 1.5],
      [275.0, 55.0, 0.9, 1.9],
    ];
    for (final p in stars) {
      final ph = (phase + p[3] / 3.0) % 1.0;
      final twinkle = 0.45 + 0.3 * math.sin(ph * 2 * math.pi);
      canvas.drawCircle(
        Offset(p[0] * s, p[1] * hs),
        p[2] * s,
        Paint()..color = Colors.white.withOpacity(twinkle),
      );
    }

    // Back range silhouette
    final backPath = Path()
      ..moveTo(-10 * s, 175 * hs)
      ..lineTo(50 * s, 115 * hs)
      ..lineTo(95 * s, 150 * hs)
      ..lineTo(140 * s, 95 * hs)
      ..lineTo(200 * s, 135 * hs)
      ..lineTo(250 * s, 110 * hs)
      ..lineTo(310 * s, 145 * hs)
      ..lineTo(360 * s, 115 * hs)
      ..lineTo(420 * s, 155 * hs)
      ..lineTo(420 * s, 280 * hs)
      ..lineTo(-10 * s, 280 * hs)
      ..close();
    canvas.drawPath(
      backPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A313C), Color(0xFF11161C)],
        ).createShader(Rect.fromLTWH(0, 95 * hs, w, 185 * hs)),
    );

    // Mid range
    final midPath = Path()
      ..moveTo(-10 * s, 220 * hs)
      ..lineTo(30 * s, 185 * hs)
      ..lineTo(80 * s, 200 * hs)
      ..lineTo(140 * s, 165 * hs)
      ..lineTo(195 * s, 195 * hs)
      ..lineTo(240 * s, 175 * hs)
      ..lineTo(300 * s, 200 * hs)
      ..lineTo(355 * s, 175 * hs)
      ..lineTo(420 * s, 205 * hs)
      ..lineTo(420 * s, 280 * hs)
      ..lineTo(-10 * s, 280 * hs)
      ..close();
    canvas.drawPath(midPath, Paint()..color = const Color(0xFF161B23));

    // Front range
    final frontPath = Path()
      ..moveTo(-10 * s, 280 * hs)
      ..lineTo(10 * s, 245 * hs)
      ..lineTo(60 * s, 225 * hs)
      ..lineTo(100 * s, 250 * hs)
      ..lineTo(170 * s, 220 * hs)
      ..lineTo(220 * s, 245 * hs)
      ..lineTo(280 * s, 225 * hs)
      ..lineTo(340 * s, 250 * hs)
      ..lineTo(420 * s, 235 * hs)
      ..lineTo(420 * s, 280 * hs)
      ..close();
    canvas.drawPath(
      frontPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2029), Color(0xFF06080B)],
        ).createShader(Rect.fromLTWH(0, 220 * hs, w, 60 * hs)),
    );

    // Snow flecks on the highest peak
    final snowPath = Path()
      ..moveTo(135 * s, 102 * hs)
      ..lineTo(140 * s, 95 * hs)
      ..lineTo(146 * s, 110 * hs)
      ..lineTo(142 * s, 106 * hs)
      ..close();
    canvas.drawPath(snowPath, Paint()..color = const Color(0xD9EEF1F4));
  }

  @override
  bool shouldRepaint(_HeroMountainPainter old) => old.phase != phase;
}

// ─────────────────────────────── TITLE CARD ─────────────────────────────────

class _TitleCard extends StatelessWidget {
  const _TitleCard();

  @override
  Widget build(BuildContext context) {
    // Pull up so the card visually overlaps the hero fade.
    return Transform.translate(
      offset: const Offset(0, -34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place, size: 12, color: TT.ember),
              const SizedBox(width: 5),
              Text(
                'DRAKENSBERG NORTH · CATHEDRAL PEAK',
                style: TT.mono(size: 10.5, color: TT.ember)
                    .copyWith(letterSpacing: 0.12 * 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mt. Marcy Summit Trail',
            style: TT.title(28, letterSpacing: -0.025 * 28)
                .copyWith(fontWeight: FontWeight.w900, height: 1.05),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x26F2A93B),
                  border: Border.all(color: const Color(0x66F2A93B), width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '◆',
                      style: TT.mono(size: 9, color: TT.amber)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'DIFFICULT',
                      style: TT.mono(size: 9.5, color: TT.amber)
                          .copyWith(letterSpacing: 0.14 * 9.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.star, size: 13, color: TT.ember2),
              const SizedBox(width: 4),
              Text('4.7', style: TT.body(size: 12, w: FontWeight.w800)),
              const SizedBox(width: 5),
              Text(
                '(312)',
                style: TT.body(size: 12, color: TT.text3, w: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────── STATS ROW ─────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -20),
      child: const TTCard(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.navigation,
                label: 'Distance',
                value: '12.4',
                unit: 'km',
              ),
            ),
            _Divider(),
            Expanded(
              child: _StatTile(
                icon: Icons.arrow_upward,
                label: 'Ascent',
                value: '1,205',
                unit: 'm',
                ember: true,
              ),
            ),
            _Divider(),
            Expanded(
              child: _StatTile(
                icon: Icons.schedule,
                label: 'Duration',
                value: '5–7',
                unit: 'hrs',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 38, color: TT.line);
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool ember;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: ember ? TT.ember : TT.text3),
            const SizedBox(width: 5),
            Text(
              label.toUpperCase(),
              style: TT.label(size: 9.5, color: TT.text3, letterSpacing: 0.16 * 9.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TTCountUp(
              text: value,
              style: TT.numStyle(
                size: 20,
                color: ember ? TT.ember : TT.text,
                letterSpacing: -0.02 * 20,
              ),
              delay: const Duration(milliseconds: 450),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: TT.mono(size: 10, color: TT.text2, w: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────────── ELEVATION CARD ───────────────────────────────

class _ElevationCard extends StatelessWidget {
  final double pace;
  final ValueChanged<double> onPaceChange;
  const _ElevationCard({required this.pace, required this.onPaceChange});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ELEVATION PROFILE',
                style: TT.label(size: 11, color: TT.text2, letterSpacing: 0.16 * 11),
              ),
              Text(
                '+1,205 m',
                style: TT.mono(size: 10, color: TT.ember, w: FontWeight.w800)
                    .copyWith(letterSpacing: 0.1 * 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const TTBigElevChart(peakLabel: '7.2 km · 1,820 m'),
          const SizedBox(height: 14),
          _PaceSlider(pace: pace, onChange: onPaceChange),
        ],
      ),
    );
  }
}

class _PaceSlider extends StatelessWidget {
  final double pace;
  final ValueChanged<double> onChange;
  const _PaceSlider({required this.pace, required this.onChange});

  String get _label {
    if (pace < 0.33) return 'SLOW · 6h 40m';
    if (pace < 0.66) return 'STEADY · 5h 12m';
    return 'FAST · 4h 18m';
  }

  @override
  Widget build(BuildContext context) {
    const trackHeight = 6.0;
    const handleSize = 22.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PACE',
              style: TT.label(size: 10, color: TT.text3, letterSpacing: 0.12 * 10),
            ),
            Text(
              _label,
              style: TT.mono(size: 10, color: TT.ember, w: FontWeight.w800)
                  .copyWith(letterSpacing: 0.08 * 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (_, c) {
          final width = c.maxWidth;
          final fillW = (width * pace).clamp(0.0, width);
          final handleX = (fillW - handleSize / 2).clamp(0.0, width - handleSize);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) {
              final v = (d.localPosition.dx / width).clamp(0.0, 1.0);
              onChange(v);
            },
            onHorizontalDragUpdate: (d) {
              final v = (d.localPosition.dx / width).clamp(0.0, 1.0);
              onChange(v);
            },
            onTapDown: (d) {
              final v = (d.localPosition.dx / width).clamp(0.0, 1.0);
              onChange(v);
            },
            child: SizedBox(
              height: handleSize,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Track
                  Container(
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: TT.surf2,
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                  ),
                  // Filled portion
                  Container(
                    height: trackHeight,
                    width: fillW,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [TT.ember, TT.ember2],
                      ),
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66FF6A2C), blurRadius: 12),
                      ],
                    ),
                  ),
                  // Vertical bar indicator on the curve
                  Positioned(
                    left: fillW.clamp(0.0, width) - 1,
                    top: -2,
                    bottom: -2,
                    child: Container(width: 2, color: const Color(0x66FFFFFF)),
                  ),
                  // Handle
                  Positioned(
                    left: handleX,
                    child: Container(
                      width: handleSize,
                      height: handleSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: TT.ember, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x80FF6A2C), blurRadius: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SLOW',
                style: TT.mono(size: 9.5, color: TT.text3)
                    .copyWith(letterSpacing: 0.06 * 9.5)),
            Text('STEADY',
                style: TT.mono(size: 9.5, color: TT.text3)
                    .copyWith(letterSpacing: 0.06 * 9.5)),
            Text('FAST',
                style: TT.mono(size: 9.5, color: TT.text3)
                    .copyWith(letterSpacing: 0.06 * 9.5)),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────────────── ABOUT ────────────────────────────────────

class _AboutBlock extends StatelessWidget {
  const _AboutBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'ABOUT',
            style: TT.label(size: 11, color: TT.text2, letterSpacing: 0.16 * 11),
          ),
        ),
        Text(
          'Strenuous out-and-back along the Cathedral spine. Expect exposed '
          'ridges, fast-changing weather, and one technical scramble at km 7. '
          'Two cave shelters available mid-route. Start before 06:00 to summit '
          'before the afternoon front.',
          style: TT.body(size: 12.5, color: TT.text2, w: FontWeight.w500)
              .copyWith(height: 1.55),
        ),
      ],
    );
  }
}

// ──────────────────────────────── REVIEWS ───────────────────────────────────

class _ReviewsBlock extends StatelessWidget {
  const _ReviewsBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRAIL REPORTS',
                style: TT.label(size: 11, color: TT.text2, letterSpacing: 0.16 * 11),
              ),
              Text(
                'SEE ALL →',
                style: TT.body(size: 10, w: FontWeight.w800, color: TT.ember)
                    .copyWith(letterSpacing: 0.1 * 10),
              ),
            ],
          ),
        ),
        TTCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TTCountUp(
                    text: '4.7',
                    style: TT.numStyle(size: 36, letterSpacing: -0.025 * 36)
                        .copyWith(fontWeight: FontWeight.w900),
                    delay: const Duration(milliseconds: 600),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 11, color: TT.ember2),
                      Icon(Icons.star, size: 11, color: TT.ember2),
                      Icon(Icons.star, size: 11, color: TT.ember2),
                      Icon(Icons.star, size: 11, color: TT.ember2),
                      Icon(Icons.star, size: 11, color: TT.ember2),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  children: [
                    _RatingBar(stars: 5, percent: 85),
                    SizedBox(height: 3),
                    _RatingBar(stars: 4, percent: 12),
                    SizedBox(height: 3),
                    _RatingBar(stars: 3, percent: 2),
                    SizedBox(height: 3),
                    _RatingBar(stars: 2, percent: 1),
                    SizedBox(height: 3),
                    _RatingBar(stars: 1, percent: 0),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _ReviewSnippet(
          initials: 'MK',
          name: 'Mike K.',
          meta: '4 DAYS AGO · COMPLETED 4h 51m',
          body:
              'Bridge at km 4 is washed out — went around via the upper switchback. '
              'Adds about 30 min. Otherwise the trail is in great shape.',
          accent: TT.green,
        ),
        const SizedBox(height: 8),
        const _ReviewSnippet(
          initials: 'SP',
          name: 'Sarah P.',
          meta: '1 WEEK AGO · COMPLETED 5h 22m',
          body:
              'Cathedral lower cave saved us from a hailstorm. Bring a shell — '
              'wind picks up fast after the scramble.',
          accent: TT.blue,
        ),
      ],
    );
  }
}

class _RatingBar extends StatelessWidget {
  final int stars;
  final int percent;
  const _RatingBar({required this.stars, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 9,
          child: Text(
            '$stars',
            style: TT.mono(size: 9, color: TT.text3, w: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(height: 4, color: TT.surf2),
                FractionallySizedBox(
                  widthFactor: percent / 100.0,
                  child: Container(
                    height: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [TT.ember, TT.ember2]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 26,
          child: Text(
            '$percent%',
            textAlign: TextAlign.right,
            style: TT.mono(size: 9, color: TT.text3, w: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ReviewSnippet extends StatelessWidget {
  final String initials;
  final String name;
  final String meta;
  final String body;
  final Color accent;

  const _ReviewSnippet({
    required this.initials,
    required this.name,
    required this.meta,
    required this.body,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accent.withOpacity(0.66)],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style:
                      TT.body(size: 12, w: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name,
                            style: TT.body(size: 12.5, w: FontWeight.w800)),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 10, color: TT.ember2),
                            Icon(Icons.star, size: 10, color: TT.ember2),
                            Icon(Icons.star, size: 10, color: TT.ember2),
                            Icon(Icons.star, size: 10, color: TT.ember2),
                            Icon(Icons.star, size: 10, color: TT.ember2),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: TT.mono(size: 9.5, color: TT.text3)
                          .copyWith(letterSpacing: 0.06 * 9.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TT.body(size: 12, color: TT.text2, w: FontWeight.w500)
                .copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────── CAVES ────────────────────────────────────

class _CavesBlock extends StatelessWidget {
  const _CavesBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SHELTER & CAVES',
                style: TT.label(size: 11, color: TT.text2, letterSpacing: 0.16 * 11),
              ),
              Text(
                '2 ON ROUTE',
                style: TT.mono(size: 10, color: TT.text3, w: FontWeight.w600),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 116,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: const [
              _CaveCard(
                name: 'Cave #47',
                subtitle: 'Sunrise Camp',
                distance: '5.8 km',
                capacity: '6 sleepers',
                hasWater: true,
              ),
              SizedBox(width: 10),
              _CaveCard(
                name: 'Cave #62',
                subtitle: 'Cathedral Lower',
                distance: '9.2 km',
                capacity: '4 sleepers',
                hasWater: false,
              ),
              SizedBox(width: 10),
              _CaveCard(
                name: 'Cave #71',
                subtitle: 'Echo Notch',
                distance: '11.0 km',
                capacity: '2 sleepers',
                hasWater: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaveCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String distance;
  final String capacity;
  final bool hasWater;

  const _CaveCard({
    required this.name,
    required this.subtitle,
    required this.distance,
    required this.capacity,
    required this.hasWater,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: TT.surf,
          border: const Border(
            top: BorderSide(color: Color(0x334CC38A), width: 1),
            right: BorderSide(color: Color(0x334CC38A), width: 1),
            bottom: BorderSide(color: Color(0x334CC38A), width: 1),
            left: BorderSide(color: TT.green, width: 3),
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0x224CC38A),
                    border: Border.all(color: const Color(0x524CC38A), width: 1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.terrain, size: 16, color: TT.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TT.body(size: 12.5, w: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TT.body(
                          size: 11,
                          color: TT.text3,
                          w: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  distance,
                  style: TT.mono(size: 10, color: TT.text2, w: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Text('·', style: TT.mono(size: 10, color: TT.line3)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    capacity,
                    style:
                        TT.mono(size: 10, color: TT.text3, w: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasWater) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.water_drop, size: 11, color: TT.blue),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────── STICKY CTA ────────────────────────────────

class _StickyCTA extends StatelessWidget {
  final AnimationController controller;
  const _StickyCTA({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return IgnorePointer(
      ignoring: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 14 + bottomInset),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00070A0E), Color(0xD9070A0E), TT.bg],
            stops: [0.0, 0.35, 0.75],
          ),
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, child) {
            final t = Curves.easeInOut.transform(controller.value);
            return Transform.scale(scale: 1.0 + 0.01 * t, child: child);
          },
          child: _CTAButton(onTap: () {}),
        ),
      ),
    );
  }
}

class _CTAButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CTAButton({required this.onTap});

  @override
  State<_CTAButton> createState() => _CTAButtonState();
}

class _CTAButtonState extends State<_CTAButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.98 : 1.0,
        duration: TT.dFast,
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [TT.ember2, TT.ember],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: TT.shadowEmber,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: TTShimmerBand(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, size: 16, color: TT.emberInk),
                        const SizedBox(width: 10),
                        Text(
                          'START HIKE · 12.4 KM',
                          style: TT.body(
                            size: 13,
                            color: TT.emberInk,
                            w: FontWeight.w900,
                          ).copyWith(letterSpacing: 0.16 * 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── ENTRY TRANSITION ──────────────────────────────

/// Generic per-section fade + translate driven by an externally computed
/// progress value (so all sections stagger off the same master controller).
class _SlideIn extends StatelessWidget {
  final double t;
  final Widget child;
  final Offset offset;

  const _SlideIn({
    required this.t,
    required this.child,
    this.offset = const Offset(0, 16),
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(offset.dx * (1 - t), offset.dy * (1 - t)),
        child: child,
      ),
    );
  }
}
