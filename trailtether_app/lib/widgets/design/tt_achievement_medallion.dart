// Trailtether — animated achievement medallion.
//
// Flutter port of `screens/profile.jsx#TopoMedallion`. The design ships a
// hexagonal topographic survey marker with multiple loops layered on it:
//   * a switchback trail drawing itself across a mountain silhouette
//   * a comet riding the trail head
//   * a summit pin that pulses
//   * radar ping rings expanding from the summit
//   * drifting embers (hero-size only)
// Locked-with-progress badges show an ember "magma" fill rising from the
// base of the hex up to (1 - progress) × height, with a wavefront on top.
//
// Single AnimationController drives everything. CustomPainter does the
// drawing — Flutter has no animated SVG runtime, so the JSX <animate>
// elements are replaced with tween-driven repaints.
//
// Performance:
//   * `repaint: _ctrl` rebuilds only this widget on each frame
//   * paint code allocates Paints once per build and reuses them
//   * controllers are paused via TickerMode when offscreen (Flutter
//     stops tickers automatically for screens that aren't visible)
//
// Usage:
//   TTAchievementMedallion(
//     icon: Icons.terrain,
//     color: TT.ember,
//     unlocked: true,
//     size: 56,
//   )

import 'dart:math' as math;
import 'package:flutter/material.dart';

class TTAchievementMedallion extends StatefulWidget {
  /// Centre icon (rendered in a small well on the trail line).
  final IconData icon;

  /// Tint used for the trail, summit pin and hex border. The fill is
  /// derived as a brighter shade of this colour.
  final Color color;

  /// True if the achievement has been earned. Unlocked medallions
  /// animate; locked ones render statically with a lock chip.
  final bool unlocked;

  /// 0–1 progress towards unlocking. Ignored when [unlocked] is true.
  /// Drives the ember magma fill height for locked-with-progress badges.
  final double progress;

  /// Drawn at this width × height. Hexagon viewBox is 100×100 internally
  /// and scaled to fit. Reasonable: 56 (grid), 96 (hero), 120 (detail).
  final double size;

  /// Hero mode — beefier border, larger icon well, drifting embers.
  final bool large;

  const TTAchievementMedallion({
    super.key,
    required this.icon,
    required this.color,
    required this.unlocked,
    this.progress = 0,
    this.size = 56,
    this.large = false,
  });

  @override
  State<TTAchievementMedallion> createState() => _TTAchievementMedallionState();
}

class _TTAchievementMedallionState extends State<TTAchievementMedallion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 6 s loop — slow enough to read as ambient, long enough for the
    // trail draw + ember drift to feel coherent. Sub-loops (summit pulse,
    // radar ping) use `fmod` on this base inside the painter.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    if (widget.unlocked) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant TTAchievementMedallion old) {
    super.didUpdateWidget(old);
    if (widget.unlocked != old.unlocked) {
      if (widget.unlocked) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _fillColor() {
    // Lighter shade of the ring colour for the trail gradient tip.
    final hsl = HSLColor.fromColor(widget.color);
    return hsl
        .withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final fill = _fillColor();
    final centerWell = widget.large ? 22.0 : 14.0;
    final centerIconSize = widget.large ? 13.0 : 9.0;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The medallion itself — fully painted in a CustomPainter
          // driven by the animation controller.
          Positioned.fill(
            child: CustomPaint(
              painter: _MedallionPainter(
                ringColor: widget.color,
                fillColor: fill,
                unlocked: widget.unlocked,
                progress: widget.progress,
                large: widget.large,
                animation: _ctrl,
              ),
            ),
          ),

          // Centre icon, positioned roughly where the SVG places it (on
          // the trail line, just below the summit pin).
          Positioned(
            top: widget.size * 0.50 - centerWell / 2,
            left: widget.size * 0.50 - centerWell / 2,
            child: Container(
              width: centerWell,
              height: centerWell,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.unlocked ? const Color(0xFF0A0C0F) : Colors.transparent,
                border: widget.unlocked
                    ? Border.all(color: widget.color, width: 1.5)
                    : null,
                boxShadow: widget.unlocked
                    ? [
                        BoxShadow(
                          color: widget.color.withOpacity(0.55),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.icon,
                size: centerIconSize,
                color: widget.unlocked ? fill : const Color(0xFF5A6470),
              ),
            ),
          ),

          // Lock chip in the bottom-right when locked.
          if (!widget.unlocked)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F1318),
                  border: Border.all(
                    color: const Color(0x29FFFFFF),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_rounded,
                  size: 9,
                  color: Color(0xFF98A1AC),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MedallionPainter extends CustomPainter {
  final Color ringColor;
  final Color fillColor;
  final bool unlocked;
  final double progress;
  final bool large;
  final Animation<double> animation;

  _MedallionPainter({
    required this.ringColor,
    required this.fillColor,
    required this.unlocked,
    required this.progress,
    required this.large,
    required this.animation,
  }) : super(repaint: animation);

  // ── Geometry, in the JSX's 100×100 viewBox ──────────────────────────
  // Hex (rotated to point top/bottom flat); summit; switchback trail.
  static final Path _hexPath = Path()
    ..moveTo(50, 4)
    ..lineTo(92, 27)
    ..lineTo(92, 73)
    ..lineTo(50, 96)
    ..lineTo(8, 73)
    ..lineTo(8, 27)
    ..close();

  static final Path _mountainPath = Path()
    ..moveTo(5, 92)
    ..lineTo(22, 70)
    ..lineTo(32, 78)
    ..lineTo(44, 60)
    ..lineTo(56, 70)
    ..lineTo(70, 32)
    ..lineTo(84, 64)
    ..lineTo(95, 92)
    ..close();

  static final Path _trailPath = Path()
    ..moveTo(18, 82)
    ..cubicTo(28, 76, 34, 68, 38, 64)
    ..cubicTo(42, 60, 50, 58, 46, 50)
    ..cubicTo(42, 42, 54, 42, 60, 40)
    ..cubicTo(66, 38, 70, 36, 70, 32);

  static const _summit = Offset(70, 32);

  @override
  void paint(Canvas canvas, Size size) {
    // The JSX uses a 100×100 viewBox; scale to the actual draw size.
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    // Clip everything to the hex shape so contours / silhouette stay inside.
    canvas.save();
    canvas.clipPath(_hexPath);

    // Background fill — slightly warm when unlocked, cold when locked.
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1010), Color(0xFF06080B)],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    if (!unlocked) {
      bgPaint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF11161C), Color(0xFF06080B)],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    }
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), bgPaint);

    // ── Contour lines (static) ───────────────────────────────────────
    final contourPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = unlocked
          ? fillColor.withOpacity(0.20)
          : Colors.white.withOpacity(0.06);
    for (final y in const [40.0, 52.0, 64.0, 76.0, 88.0]) {
      final p = Path()
        ..moveTo(-10, y)
        ..quadraticBezierTo(30, y - 8, 50, y - 2)
        ..quadraticBezierTo(70, y + 4, 110, y);
      canvas.drawPath(p, contourPaint);
    }

    // ── Locked-with-progress: ember magma fill rising from the base ──
    if (!unlocked && progress > 0) {
      final magmaTop = 100 - progress * 92;
      // Flicker the opacity 0.55-0.85 over the loop.
      final t = animation.value;
      final flicker = 0.55 + 0.30 * (0.5 + 0.5 * math.sin(t * math.pi * 2 * 2.5));
      final magmaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            ringColor.withOpacity(0.85),
            ringColor.withOpacity(0),
          ],
        ).createShader(Rect.fromLTWH(0, magmaTop, 100, 100 - magmaTop + 8));
      magmaPaint.color = magmaPaint.color.withOpacity(flicker);
      canvas.drawRect(
        Rect.fromLTWH(0, magmaTop, 100, 100 - magmaTop + 8),
        magmaPaint,
      );
      // Wavefront stroke at the top of the magma.
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = fillColor.withOpacity(0.6 + 0.4 * flicker);
      final wave = Path()
        ..moveTo(0, magmaTop)
        ..quadraticBezierTo(30, magmaTop - 2, 50, magmaTop)
        ..quadraticBezierTo(70, magmaTop + 2, 100, magmaTop);
      canvas.drawPath(wave, wavePaint);
    }

    // ── Mountain silhouette ──────────────────────────────────────────
    final mountainFill = Paint()
      ..style = PaintingStyle.fill
      ..color = unlocked ? const Color(0xFF05060A) : const Color(0xFF0D1218);
    final mountainStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeJoin = StrokeJoin.round
      ..color = unlocked
          ? fillColor.withOpacity(0.40)
          : Colors.white.withOpacity(0.10);
    canvas.drawPath(_mountainPath, mountainFill);
    canvas.drawPath(_mountainPath, mountainStroke);

    if (unlocked) {
      // ── Radar ping ring expanding from summit (3.2 s) ──────────────
      final radarT = (animation.value * (6000 / 3200)) % 1.0;
      final radarR = 3 + radarT * 43;
      final radarPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = fillColor.withOpacity((0.7 * (1 - radarT)).clamp(0.0, 0.7));
      canvas.drawCircle(_summit, radarR, radarPaint);

      // Second offset radar ring (start half-cycle behind).
      final radar2T = ((animation.value * (6000 / 3200)) + 0.5) % 1.0;
      final radar2R = 3 + radar2T * 43;
      final radar2Paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = fillColor.withOpacity((0.7 * (1 - radar2T)).clamp(0.0, 0.7));
      canvas.drawCircle(_summit, radar2R, radar2Paint);

      // ── Trail under-glow ─────────────────────────────────────────
      final trailGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = fillColor.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
      canvas.drawPath(_trailPath, trailGlow);

      // ── Trail draw-in (2.6 s) ────────────────────────────────────
      // Cycle: 0 → 1 dashOffset, simulating <animate stroke-dashoffset>.
      final trailT = (animation.value * (6000 / 2600)) % 1.0;
      final pm = _trailPath.computeMetrics().first;
      final visible = pm.extractPath(0, pm.length * trailT);
      final trailPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            ringColor.withOpacity(0),
            fillColor,
            const Color(0xFFFFF4D6),
          ],
          stops: const [0.0, 0.3, 1.0],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
      canvas.drawPath(visible, trailPaint);

      // ── Tracer dot riding the trail head ─────────────────────────
      final pos = pm.getTangentForOffset(pm.length * trailT)?.position;
      if (pos != null) {
        final tracerPaint = Paint()..color = const Color(0xFFFFF4D6);
        canvas.drawCircle(pos, 1.4, tracerPaint);
      }
    } else {
      // Locked: static dashed-style trail hint so the path is still readable.
      final trailHint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.white.withOpacity(0.10);
      canvas.drawPath(_trailPath, trailHint);
    }

    // ── Summit pin ──────────────────────────────────────────────────
    if (unlocked) {
      // Pulse the radius 4 → 8 → 4 over 2 s.
      final pulseT = (animation.value * (6000 / 2000)) % 1.0;
      final pulseR = 4 + 4 * (0.5 + 0.5 * math.sin(pulseT * math.pi * 2));
      final pinGlow = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF4D6),
            fillColor,
            ringColor.withOpacity(0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: _summit, radius: pulseR));
      canvas.drawCircle(_summit, pulseR, pinGlow);
      canvas.drawCircle(
        _summit,
        1.8,
        Paint()..color = const Color(0xFFFFF4D6),
      );
    } else {
      canvas.drawCircle(
        _summit,
        1.2,
        Paint()..color = Colors.white.withOpacity(0.18),
      );
    }

    // ── Reticle corner brackets (static, survey-marker vibe) ───────
    final reticle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = (unlocked ? fillColor : Colors.white)
          .withOpacity(unlocked ? 0.85 : 0.45);
    canvas.drawLine(const Offset(10, 28), const Offset(16, 25), reticle);
    canvas.drawLine(const Offset(90, 28), const Offset(84, 25), reticle);
    canvas.drawLine(const Offset(10, 72), const Offset(16, 75), reticle);
    canvas.drawLine(const Offset(90, 72), const Offset(84, 75), reticle);

    canvas.restore(); // end clip

    // ── Hex border, drawn LAST so it sits above the clipped content ─
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = large ? 1.6 : 1.4
      ..color = unlocked
          ? ringColor
          : Colors.white.withOpacity(0.16);
    canvas.drawPath(_hexPath, borderPaint);

    // ── Drop glow around the whole hex on unlocked hero medallions ─
    if (unlocked && large) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = ringColor.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
      canvas.drawPath(_hexPath, glow);
    }

    // ── Drifting embers above hero medallion ───────────────────────
    if (unlocked && large) {
      // 4 embers, staggered through the loop.
      const embers = [
        [10.0, -22.0, 0.0],
        [-14.0, -18.0, 0.7],
        [18.0, -30.0, 1.4],
        [-6.0, -26.0, 2.1],
      ];
      for (final e in embers) {
        final delay = e[2] / 6.0;
        final t = ((animation.value - delay) % 1.0 + 1.0) % 1.0;
        if (t > 0.95) continue; // brief gap between cycles
        final fade = t < 0.18 ? t / 0.18 : (1 - (t - 0.18) / 0.82);
        final cx = 50 + e[0] * t;
        final cy = 30 + e[1] * t;
        final emberPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFE9C2),
              fillColor.withOpacity(0.6),
              ringColor.withOpacity(0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 4));
        emberPaint.color = emberPaint.color.withOpacity(fade.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(cx, cy), 2.5, emberPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MedallionPainter old) {
    return ringColor != old.ringColor ||
        fillColor != old.fillColor ||
        unlocked != old.unlocked ||
        progress != old.progress ||
        large != old.large;
  }
}
