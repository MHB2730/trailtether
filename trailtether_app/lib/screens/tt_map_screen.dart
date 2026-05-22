// Trailtether 2.0 — Map / Peak Tracker screen.
//
// Recreates project/screens/maps.jsx from the design bundle: full-bleed
// topographic map (custom painter) with animated route, You / Summit / Start
// markers, KM markers, floating glass stat cards, zoom + crosshair + layer
// controls, scale bar, and a bottom RecordingPanel with Pause / Stop buttons
// and a mini elevation chart. Self-contained — does not touch providers.

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';

class TTMapScreen extends StatefulWidget {
  final bool embedded;
  const TTMapScreen({super.key, this.embedded = false});

  @override
  State<TTMapScreen> createState() => _TTMapScreenState();
}

class _TTMapScreenState extends State<TTMapScreen>
    with TickerProviderStateMixin {
  // Drives the route draw + dashed traversed trace.
  late final AnimationController _routeCtl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _routeCtl.forward();
    });
  }

  @override
  void dispose() {
    _routeCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      top: !widget.embedded,
      bottom: false,
      child: Column(
        children: [
          TTPageAppBar(
            title: 'Peak Tracker',
            trailing: [
              TTIconBtn(icon: Icons.search, onTap: () {}),
              TTIconBtn(icon: Icons.menu, onTap: () {}),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _MapView(routeCtl: _routeCtl)),
                _RecordingPanel(),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

// ───────────────────────────── MAP VIEW ──────────────────────────────────────

class _MapView extends StatelessWidget {
  final AnimationController routeCtl;
  const _MapView({required this.routeCtl});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        color: const Color(0xFF0A0C0F),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Topographic map (contours + labels + lakes + route + markers)
            AnimatedBuilder(
              animation: routeCtl,
              builder: (_, __) => CustomPaint(
                painter: _TopoMapPainter(progress: routeCtl.value),
                size: Size.infinite,
              ),
            ),

            // KM markers fade in on top of the painter
            const Positioned.fill(child: _KmMarkers()),

            // You / Summit / Start markers pop in
            const Positioned.fill(child: _RouteMarkers()),

            // Floating top stat cards
            const Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  Expanded(
                    child: _AnimUp(
                      delay: Duration(milliseconds: 120),
                      child: _FloatingStat(
                        icon: Icons.navigation,
                        label: 'Distance',
                        value: '4.8',
                        unit: 'km',
                        sublabel: 'Completed',
                        countDelayMs: 320,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _AnimUp(
                      delay: Duration(milliseconds: 220),
                      child: _FloatingStat(
                        icon: Icons.schedule,
                        label: 'Time',
                        value: '2h 15m',
                        sublabel: 'Duration',
                        countDelayMs: 420,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Right-side controls
            const Positioned(
              top: 152,
              right: 14,
              child: _MapControls(),
            ),

            // Scale bar
            const Positioned(
              bottom: 14,
              left: 14,
              child: _AnimUp(
                delay: Duration(milliseconds: 900),
                child: _ScaleBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── ROUTE GEOMETRY ──────────────────────────────────
//
// All marker positions and the route path are defined in a fixed 412 × 460
// design space and rescaled to the actual canvas size. This mirrors the
// SVG viewBox in maps.jsx so the layout matches the design exactly.

class _RouteGeo {
  static const double w = 412;
  static const double h = 460;

  static const Offset you = Offset(170, 230);
  static const Offset summit = Offset(340, 100);
  static const Offset start = Offset(70, 410);

  // KM marker positions (label, position, animation delay)
  static const List<_KmMarker> kms = [
    _KmMarker(label: '5 km', pos: Offset(80, 320), delay: Duration(milliseconds: 1100)),
    _KmMarker(label: '10 km', pos: Offset(225, 230), delay: Duration(milliseconds: 1300)),
    _KmMarker(label: '15 km', pos: Offset(325, 155), delay: Duration(milliseconds: 1500)),
  ];

  /// Build the route path scaled to [size]. Mirrors:
  ///   M 70 410 Q 50 350 80 290 Q 120 240 170 230
  ///   Q 230 230 270 200 Q 320 170 340 130 L 340 100
  static Path routePath(Size size) {
    final sx = size.width / w;
    final sy = size.height / h;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final path = Path()
      ..moveTo(p(70, 410).dx, p(70, 410).dy)
      ..quadraticBezierTo(p(50, 350).dx, p(50, 350).dy, p(80, 290).dx, p(80, 290).dy)
      ..quadraticBezierTo(p(120, 240).dx, p(120, 240).dy, p(170, 230).dx, p(170, 230).dy)
      ..quadraticBezierTo(p(230, 230).dx, p(230, 230).dy, p(270, 200).dx, p(270, 200).dy)
      ..quadraticBezierTo(p(320, 170).dx, p(320, 170).dy, p(340, 130).dx, p(340, 130).dy)
      ..lineTo(p(340, 100).dx, p(340, 100).dy);
    return path;
  }

  static Offset scale(Offset designPt, Size size) =>
      Offset(designPt.dx / w * size.width, designPt.dy / h * size.height);
}

class _KmMarker {
  final String label;
  final Offset pos;
  final Duration delay;
  const _KmMarker({required this.label, required this.pos, required this.delay});
}

// ─────────────────────────── TOPO MAP PAINTER ────────────────────────────────

class _TopoMapPainter extends CustomPainter {
  /// 0..1 — animates the route draw and the dashed traversed trace.
  final double progress;
  _TopoMapPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Base background
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF06080B));

    // 2) Radial terrain glow (warm centre)
    final terrainRect = Offset.zero & size;
    final terrainPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.2),
        radius: 0.95,
        colors: [
          Color(0xCC1D242C),
          Color(0x9911161C),
          Color(0x0006080B),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(terrainRect);
    canvas.drawRect(terrainRect, terrainPaint);

    // 3) Contour lines — two stacked layers (light + darker)
    _drawContours(
      canvas,
      size,
      const [
        [Offset(-20, 400), Offset(100, 380), Offset(200, 380), Offset(440, 390)],
        [Offset(-20, 360), Offset(100, 330), Offset(200, 335), Offset(440, 355)],
        [Offset(-20, 320), Offset(100, 260), Offset(220, 270), Offset(440, 310)],
        [Offset(0, 280), Offset(120, 200), Offset(230, 215), Offset(440, 260)],
        [Offset(30, 240), Offset(140, 160), Offset(240, 175), Offset(420, 220)],
        [Offset(60, 210), Offset(160, 130), Offset(250, 145), Offset(400, 200)],
        [Offset(90, 180), Offset(190, 110), Offset(250, 130), Offset(380, 180)],
        [Offset(120, 160), Offset(200, 110), Offset(250, 120), Offset(360, 150)],
        [Offset(150, 140), Offset(210, 110), Offset(250, 115), Offset(340, 135)],
      ],
      strokeColor: const Color(0x8C2A3038),
      strokeWidth: 0.5,
    );
    _drawContours(
      canvas,
      size,
      const [
        [Offset(-20, 420), Offset(100, 400), Offset(200, 398), Offset(440, 410)],
        [Offset(-20, 380), Offset(100, 360), Offset(200, 358), Offset(440, 370)],
        [Offset(-20, 340), Offset(100, 300), Offset(200, 305), Offset(440, 330)],
        [Offset(-20, 300), Offset(120, 230), Offset(220, 245), Offset(440, 285)],
        [Offset(20, 260), Offset(140, 180), Offset(240, 195), Offset(430, 240)],
        [Offset(50, 225), Offset(150, 150), Offset(250, 165), Offset(410, 210)],
      ],
      strokeColor: const Color(0xA61C2127),
      strokeWidth: 0.4,
    );

    // 4) Lakes — subtle blue ellipses
    final lakePaint1 = Paint()..color = const Color(0xB3162A3C);
    final lakePaint2 = Paint()..color = const Color(0x8C162A3C);
    final lake1 = _scaleOffset(const Offset(48, 380), size);
    final lake2 = _scaleOffset(const Offset(360, 280), size);
    final sx = size.width / _RouteGeo.w;
    final sy = size.height / _RouteGeo.h;
    canvas.drawOval(
      Rect.fromCenter(center: lake1, width: 44 * sx, height: 16 * sy),
      lakePaint1,
    );
    canvas.drawOval(
      Rect.fromCenter(center: lake2, width: 28 * sx, height: 12 * sy),
      lakePaint2,
    );

    // 5) Region labels
    _drawLabel(
      canvas,
      'NISQUALLY  VALLEY',
      _scaleOffset(const Offset(200, 350), size),
      const TextStyle(
        color: Color(0xFF3D454D),
        fontFamily: 'Manrope',
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.98,
      ),
    );
    _drawLabel(
      canvas,
      'PARADISE  RIDGE',
      _scaleOffset(const Offset(80, 200), size),
      const TextStyle(
        color: Color(0xFF3D454D),
        fontFamily: 'Manrope',
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.44,
      ),
    );

    // 6) Route — shadow + animated glow + animated sharp stroke + dashed trace
    final routePath = _RouteGeo.routePath(size);
    final metrics = routePath.computeMetrics().toList();
    final totalLen = metrics.fold<double>(0, (a, m) => a + m.length);

    // Shadow (always full)
    canvas.drawPath(
      routePath,
      Paint()
        ..color = const Color(0x8C000000)
        ..strokeWidth = 9
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Animated glow + sharp stroke (staggered)
    final glowProgress = (progress * 1.0).clamp(0.0, 1.0);
    final sharpProgress = ((progress - 0.04) * 1.04).clamp(0.0, 1.0);
    final tracerProgress = ((progress - 0.10) * 1.11).clamp(0.0, 1.0);

    _drawPartialPath(canvas, metrics, totalLen, glowProgress,
        Paint()
          ..color = const Color(0x66FF6A2C)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2));
    _drawPartialPath(canvas, metrics, totalLen, sharpProgress,
        Paint()
          ..color = TT.ember2
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // Dashed traversed trace — uses extractPath on tiny dash segments
    if (tracerProgress > 0) {
      final dashPaint = Paint()
        ..color = const Color(0x73FFFFFF)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      _drawDashedPartial(canvas, metrics, totalLen, tracerProgress, dashPaint,
          dashOn: 2, dashOff: 7);
    }
  }

  void _drawContours(
    Canvas canvas,
    Size size,
    List<List<Offset>> waves, {
    required Color strokeColor,
    required double strokeWidth,
  }) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final pts in waves) {
      if (pts.length < 4) continue;
      final s = <Offset>[];
      for (final o in pts) {
        s.add(_scaleOffset(o, size));
      }
      // SVG-style Q with smooth-T mirroring. Mock JSX uses Q + T; we use a
      // simple quadratic through the first three then a smooth second segment.
      final path = Path()..moveTo(s[0].dx, s[0].dy);
      final c1 = s[1];
      final mid = s[2];
      path.quadraticBezierTo(c1.dx, c1.dy, mid.dx, mid.dy);
      // Smooth-T reflection: control point reflected across mid.
      final c2 = Offset(2 * mid.dx - c1.dx, 2 * mid.dy - c1.dy);
      path.quadraticBezierTo(c2.dx, c2.dy, s[3].dx, s[3].dy);
      canvas.drawPath(path, paint);
    }
  }

  void _drawPartialPath(
    Canvas canvas,
    List<PathMetric> metrics,
    double totalLen,
    double progress,
    Paint paint,
  ) {
    if (progress <= 0) return;
    final target = totalLen * progress;
    double drawn = 0;
    for (final m in metrics) {
      if (drawn >= target) break;
      final remain = target - drawn;
      final segLen = math.min(m.length, remain);
      final extracted = m.extractPath(0, segLen);
      canvas.drawPath(extracted, paint);
      drawn += segLen;
    }
  }

  void _drawDashedPartial(
    Canvas canvas,
    List<PathMetric> metrics,
    double totalLen,
    double progress,
    Paint paint, {
    required double dashOn,
    required double dashOff,
  }) {
    final target = totalLen * progress;
    double drawn = 0;
    for (final m in metrics) {
      if (drawn >= target) break;
      double pos = 0;
      while (pos < m.length && drawn < target) {
        final remainTarget = target - drawn;
        final on = math.min(dashOn, math.min(m.length - pos, remainTarget));
        if (on <= 0) break;
        canvas.drawPath(m.extractPath(pos, pos + on), paint);
        pos += on;
        drawn += on;
        pos += dashOff;
      }
    }
  }

  Offset _scaleOffset(Offset designPt, Size size) =>
      Offset(designPt.dx / _RouteGeo.w * size.width,
          designPt.dy / _RouteGeo.h * size.height);

  void _drawLabel(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_TopoMapPainter old) => old.progress != progress;
}

// ───────────────────────── KM MARKERS OVERLAY ────────────────────────────────

class _KmMarkers extends StatelessWidget {
  const _KmMarkers();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return Stack(
        children: [
          for (final m in _RouteGeo.kms)
            Positioned(
              left: _RouteGeo.scale(m.pos, size).dx - 18,
              top: _RouteGeo.scale(m.pos, size).dy - 7.5,
              child: _AnimIn(
                delay: m.delay,
                child: Container(
                  width: 36,
                  height: 15,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0D04),
                    borderRadius: BorderRadius.circular(3.5),
                    border: Border.all(color: TT.ember, width: 0.8),
                  ),
                  child: Text(
                    m.label,
                    style: TT.mono(size: 9.5, color: TT.ember2, w: FontWeight.w700)
                        .copyWith(letterSpacing: 0),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

// ─────────────────────────── ROUTE MARKERS ───────────────────────────────────

class _RouteMarkers extends StatelessWidget {
  const _RouteMarkers();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      final youPx = _RouteGeo.scale(_RouteGeo.you, size);
      final summitPx = _RouteGeo.scale(_RouteGeo.summit, size);
      final startPx = _RouteGeo.scale(_RouteGeo.start, size);
      return Stack(
        children: [
          // You marker
          Positioned(
            left: youPx.dx - 26,
            top: youPx.dy - 26,
            width: 52,
            height: 52,
            child: const _AnimPop(
              delay: Duration(milliseconds: 1400),
              child: _YouMarker(),
            ),
          ),
          // Summit marker with label bubble above
          Positioned(
            left: summitPx.dx - 50,
            top: summitPx.dy - 32,
            width: 100,
            height: 50,
            child: const _AnimPop(
              delay: Duration(milliseconds: 1600),
              child: _SummitMarker(),
            ),
          ),
          // Start marker with label tag to the right
          Positioned(
            left: startPx.dx - 12,
            top: startPx.dy - 12,
            width: 80,
            height: 24,
            child: const _AnimPop(
              delay: Duration(milliseconds: 1700),
              child: _StartMarker(),
            ),
          ),
        ],
      );
    });
  }
}

class _YouMarker extends StatelessWidget {
  const _YouMarker();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _YouMarkerPainter(), size: const Size(52, 52));
  }
}

class _YouMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, 26, Paint()..color = const Color(0x1AFF6A2C));
    canvas.drawCircle(c, 16, Paint()..color = const Color(0x38FF6A2C));
    canvas.drawCircle(c, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      10,
      Paint()
        ..color = TT.ember
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Direction chevron
    final chev = Path()
      ..moveTo(c.dx, c.dy - 3)
      ..lineTo(c.dx + 4, c.dy + 5)
      ..lineTo(c.dx, c.dy + 3)
      ..lineTo(c.dx - 4, c.dy + 5)
      ..close();
    canvas.drawPath(chev, Paint()..color = TT.ember);
  }

  @override
  bool shouldRepaint(_YouMarkerPainter old) => false;
}

class _SummitMarker extends StatelessWidget {
  const _SummitMarker();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label bubble
        Container(
          width: 100,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xEB0A0C0F),
            border: Border.all(color: TT.ember, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'SUMMIT · 4,392 m',
            style: TT.body(size: 10, w: FontWeight.w800, color: TT.ember2)
                .copyWith(letterSpacing: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        // Triangle marker
        SizedBox(
          width: 28,
          height: 26,
          child: CustomPaint(painter: _SummitDotPainter()),
        ),
      ],
    );
  }
}

class _SummitDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, 8, Paint()..color = const Color(0xFF1A0D04));
    canvas.drawCircle(
      c,
      8,
      Paint()
        ..color = TT.ember
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final tri = Path()
      ..moveTo(c.dx, c.dy - 3)
      ..lineTo(c.dx - 3, c.dy + 2)
      ..lineTo(c.dx + 3, c.dy + 2)
      ..close();
    canvas.drawPath(tri, Paint()..color = TT.ember);
  }

  @override
  bool shouldRepaint(_SummitDotPainter old) => false;
}

class _StartMarker extends StatelessWidget {
  const _StartMarker();
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Diamond
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: TT.ember,
              border: Border.all(color: const Color(0xFF1A0D04), width: 1.5),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Tag
        Container(
          width: 46,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xEB0A0C0F),
            border: Border.all(color: const Color(0x26FFFFFF), width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'START',
            style: TT.body(size: 9.5, w: FontWeight.w700, color: TT.text)
                .copyWith(letterSpacing: 0.95),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── FLOATING STAT CARDS ───────────────────────────────

class _FloatingStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? sublabel;
  final int countDelayMs;

  const _FloatingStat({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.sublabel,
    this.countDelayMs = 300,
  });

  @override
  Widget build(BuildContext context) {
    return TTGlass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x1AFF6A2C),
              border: Border.all(color: const Color(0x40FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(TT.rSm),
            ),
            child: Icon(icon, size: 14, color: TT.ember),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TT.body(size: 10, w: FontWeight.w600, color: TT.text3)
                      .copyWith(letterSpacing: 0.4),
                ),
                const SizedBox(height: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: TTCountUp(
                        text: value,
                        style: TT.numStyle(size: 17, letterSpacing: -0.02 * 17),
                        delay: Duration(milliseconds: countDelayMs),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 3),
                      Text(unit!, style: TT.mono(size: 10, color: TT.text2)),
                    ],
                  ],
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    sublabel!,
                    style: TT.mono(size: 9.5, color: TT.text3, w: FontWeight.w500)
                        .copyWith(letterSpacing: 0.2),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── MAP CONTROLS ───────────────────────────────────

class _MapControls extends StatelessWidget {
  const _MapControls();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimPop(
          delay: Duration(milliseconds: 420),
          child: _ZoomGroup(),
        ),
        SizedBox(height: 8),
        _AnimPop(
          delay: Duration(milliseconds: 520),
          child: _CircleBtn(icon: Icons.gps_fixed, ember: true),
        ),
        SizedBox(height: 8),
        _AnimPop(
          delay: Duration(milliseconds: 580),
          child: _CircleBtn(icon: Icons.layers_outlined),
        ),
      ],
    );
  }
}

class _ZoomGroup extends StatelessWidget {
  const _ZoomGroup();
  @override
  Widget build(BuildContext context) {
    return TTGlass(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(icon: Icons.add, onTap: () {}),
          Container(width: 38, height: 1, color: TT.line2),
          _ZoomBtn(icon: Icons.remove, onTap: () {}),
        ],
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 16, color: TT.text),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool ember;
  const _CircleBtn({required this.icon, this.ember = false});
  @override
  Widget build(BuildContext context) {
    return TTGlass(
      onTap: () {},
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 16, color: ember ? TT.ember : TT.text2),
      ),
    );
  }
}

// ─────────────────────────────── SCALE BAR ──────────────────────────────────

class _ScaleBar extends StatelessWidget {
  const _ScaleBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xC70A0C0F),
        border: Border.all(color: TT.line2, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 22, height: 4, color: TT.text),
          Container(
            width: 22,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0C0F),
              border: Border.all(color: TT.text, width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '500 m',
            style: TT.mono(size: 9.5, color: TT.text, w: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── RECORDING PANEL ───────────────────────────────────

class _RecordingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _AnimUp(
      delay: const Duration(milliseconds: 700),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x000F1318), Color(0xF20B0E12), TT.bg2],
            stops: [0.0, 0.3, 1.0],
          ),
          border: Border(top: BorderSide(color: TT.line, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: TT.line3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mt. Elbert Summit Trail',
                        style: TT.title(16, letterSpacing: -0.01 * 16),
                      ),
                      const SizedBox(height: 6),
                      const TTPill(
                        label: 'IN PROGRESS',
                        variant: TTPillVariant.live,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PauseButton(),
                const SizedBox(width: 8),
                _StopButton(),
              ],
            ),
            const SizedBox(height: 14),
            // 3-stat row
            const _StatRow(),
            const SizedBox(height: 12),
            // Mini elevation chart card
            const _MiniElevCard(),
          ],
        ),
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: TT.ember,
        borderRadius: BorderRadius.circular(11),
        boxShadow: TT.shadowEmber,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause, size: 12, color: TT.emberInk),
          const SizedBox(width: 6),
          Text(
            'PAUSE',
            style: TT.body(size: 12, w: FontWeight.w800, color: TT.emberInk)
                .copyWith(letterSpacing: 0.12 * 12),
          ),
        ],
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: TT.line3, width: 1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        'STOP',
        style: TT.body(size: 12, w: FontWeight.w800, color: TT.text2)
            .copyWith(letterSpacing: 0.12 * 12),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        border: Border.all(color: TT.line, width: 1),
        borderRadius: BorderRadius.circular(TT.rMd),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TT.rMd),
        child: Row(
          children: [
            const Expanded(
              child: _MiniStat(label: 'Elev', value: '3,950', unit: 'm', ember: true),
            ),
            _StatDivider(),
            const Expanded(
              child: _MiniStat(label: 'Pace', value: '3.2', unit: 'km/h'),
            ),
            _StatDivider(),
            const Expanded(
              child: _MiniStat(label: 'Time', value: '02:34', unit: ':56'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 48, color: TT.line);
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool ember;
  const _MiniStat({
    required this.label,
    required this.value,
    this.unit,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TT.surf,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TT.label(size: 9.5, color: TT.text3, letterSpacing: 0.14 * 9.5),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TTCountUp(
                text: value,
                style: TT.numStyle(
                  size: 19,
                  color: ember ? TT.ember : TT.text,
                  letterSpacing: -0.02 * 19,
                ),
                delay: const Duration(milliseconds: 900),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(unit!, style: TT.mono(size: 10, color: TT.text2)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniElevCard extends StatelessWidget {
  const _MiniElevCard();

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ELEVATION PROFILE',
                style: TT.label(size: 10.5, color: TT.text2, letterSpacing: 0.14 * 10.5),
              ),
              Text(
                '0 → 17.5 km',
                style: TT.mono(size: 10, color: TT.text3, w: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _MiniElevChart(),
        ],
      ),
    );
  }
}

class _MiniElevChart extends StatefulWidget {
  const _MiniElevChart();
  @override
  State<_MiniElevChart> createState() => _MiniElevChartState();
}

class _MiniElevChartState extends State<_MiniElevChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

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
    return SizedBox(
      height: 56,
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

  static const _pts = <double>[
    1500, 1620, 1850, 2100, 2380, 2740, 3120, 3500,
    3850, 4200, 4340, 4180, 3900, 3600, 3300, 3000,
  ];
  static const _min = 1400.0;
  static const _max = 4500.0;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 4.0;
    final n = _pts.length;
    final stepX = (size.width - pad * 2) / (n - 1);

    Offset xy(double v, int i) {
      final x = pad + i * stepX;
      final y = size.height - pad - ((v - _min) / (_max - _min)) * (size.height - pad * 2);
      return Offset(x, y);
    }

    // Full top path
    final top = Path();
    for (var i = 0; i < n; i++) {
      final p = xy(_pts[i], i);
      if (i == 0) {
        top.moveTo(p.dx, p.dy);
      } else {
        top.lineTo(p.dx, p.dy);
      }
    }

    // Partial path up to progress
    final partial = Path();
    final progressIdx = progress * (n - 1);
    final lastIdx = progressIdx.floor().clamp(0, n - 1);
    for (var i = 0; i <= lastIdx; i++) {
      final p = xy(_pts[i], i);
      if (i == 0) {
        partial.moveTo(p.dx, p.dy);
      } else {
        partial.lineTo(p.dx, p.dy);
      }
    }
    if (lastIdx < n - 1 && progress > 0) {
      final segFrac = progressIdx - lastIdx;
      final a = xy(_pts[lastIdx], lastIdx);
      final b = xy(_pts[lastIdx + 1], lastIdx + 1);
      partial.lineTo(a.dx + (b.dx - a.dx) * segFrac, a.dy + (b.dy - a.dy) * segFrac);
    }

    // Filled area under partial
    if (progress > 0) {
      final lastDrawnX = pad + progressIdx * stepX;
      final fillPath = Path.from(partial)
        ..lineTo(lastDrawnX.clamp(pad, size.width - pad), size.height - pad)
        ..lineTo(pad, size.height - pad)
        ..close();
      final fillPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x8CFF6A2C), Color(0x00FF6A2C)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);
    }

    // Stroke
    final stroke = Paint()
      ..color = TT.ember
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(partial, stroke);

    // Peak marker (after most of the line is drawn)
    if (progress > 0.7) {
      var peakIdx = 0;
      for (var i = 1; i < n; i++) {
        if (_pts[i] > _pts[peakIdx]) peakIdx = i;
      }
      if (peakIdx <= lastIdx) {
        final peak = xy(_pts[peakIdx], peakIdx);
        canvas.drawLine(
          peak,
          Offset(peak.dx, size.height - pad),
          Paint()
            ..color = const Color(0x4DFFFFFF)
            ..strokeWidth = 1,
        );
        canvas.drawCircle(peak, 3.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          peak,
          3.5,
          Paint()
            ..color = TT.ember
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MiniElevPainter old) => old.progress != progress;
}

// ──────────────────────── ANIMATION PRIMITIVES ───────────────────────────────

/// `anim-up` — fade + rise from 14px.
class _AnimUp extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _AnimUp({required this.delay, required this.child});
  @override
  State<_AnimUp> createState() => _AnimUpState();
}

class _AnimUpState extends State<_AnimUp> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);

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
      animation: _ctl,
      builder: (_, __) {
        final t = TT.easeOut.transform(_ctl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: widget.child),
        );
      },
    );
  }
}

/// `anim-pop` — fade + scale from 0.7.
class _AnimPop extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _AnimPop({required this.delay, required this.child});
  @override
  State<_AnimPop> createState() => _AnimPopState();
}

class _AnimPopState extends State<_AnimPop> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 480));

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
      animation: _ctl,
      builder: (_, __) {
        final t = TT.easeOut.transform(_ctl.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.7 + 0.3 * t, child: widget.child),
        );
      },
    );
  }
}

/// `anim-in` — simple fade in.
class _AnimIn extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _AnimIn({required this.delay, required this.child});
  @override
  State<_AnimIn> createState() => _AnimInState();
}

class _AnimInState extends State<_AnimIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dMed);

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
      animation: _ctl,
      builder: (_, __) => Opacity(
        opacity: TT.easeOut.transform(_ctl.value),
        child: widget.child,
      ),
    );
  }
}
