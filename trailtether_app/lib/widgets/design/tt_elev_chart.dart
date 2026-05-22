import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Animated elevation profile — bell-curve hike with grid lines, peak marker,
/// and a draw-in stroke. Used as the hero chart inside the FeaturedHike card.
class TTBigElevChart extends StatefulWidget {
  /// Sample points along the route; if null a synthetic bell-curve is used so
  /// the visual matches the design mock when real data isn't yet available.
  final List<double>? samples;
  final double? min;
  final double? max;
  final String peakLabel;

  const TTBigElevChart({
    super.key,
    this.samples,
    this.min,
    this.max,
    this.peakLabel = '5.8 mi · 3,950 ft',
  });

  @override
  State<TTBigElevChart> createState() => _TTBigElevChartState();
}

class _TTBigElevChartState extends State<TTBigElevChart> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  late final List<double> _pts;
  late final double _min, _max;

  @override
  void initState() {
    super.initState();
    if (widget.samples != null && widget.samples!.length >= 2) {
      _pts = List<double>.from(widget.samples!);
    } else {
      _pts = _syntheticBellCurve();
    }
    final dataMin = _pts.reduce((a, b) => a < b ? a : b);
    final dataMax = _pts.reduce((a, b) => a > b ? a : b);
    _min = widget.min ?? (dataMin - 200).clamp(0.0, dataMax);
    _max = widget.max ?? (dataMax + 200);
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) _ctl.forward(); });
  }

  static List<double> _syntheticBellCurve() {
    const n = 60;
    final out = <double>[];
    for (var i = 0; i < n; i++) {
      final t = i / (n - 1);
      // Higher exponent narrows the peak a touch
      final bell = (i == 0 || i == n - 1)
          ? 0.0
          : (((1 - (2 * t - 1) * (2 * t - 1))).clamp(0.0, 1.0));
      final bellShaped = (bell * bell) * 0.8 + bell * 0.2;
      final noise = _sinTable(t * 18) * 90 + _sinTable(t * 7) * 160;
      out.add(500 + bellShaped * 3500 + noise);
    }
    return out;
  }

  static double _sinTable(double v) {
    // Approx sin for the synthetic curve; no need for high precision.
    final x = v % (2 * 3.1415926535);
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120 - 0.0;
  }

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, __) => CustomPaint(
          painter: _ElevPainter(
            pts: _pts,
            min: _min,
            max: _max,
            progress: TT.drawCurve.transform(_ctl.value),
            peakLabel: widget.peakLabel,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ElevPainter extends CustomPainter {
  final List<double> pts;
  final double min, max;
  final double progress;
  final String peakLabel;

  _ElevPainter({
    required this.pts,
    required this.min,
    required this.max,
    required this.progress,
    required this.peakLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 38.0, padR = 8.0, padT = 10.0, padB = 22.0;
    final n = pts.length;
    final stepX = (size.width - padL - padR) / (n - 1);

    Offset ptToXY(double v, int i) {
      final x = padL + i * stepX;
      final y = size.height - padB - ((v - min) / (max - min)) * (size.height - padT - padB);
      return Offset(x, y);
    }

    // Y gridlines
    final gridPaint = Paint()..color = const Color(0x0DFFFFFF);
    const labelStyle = TextStyle(color: TT.text3, fontSize: 8.5, fontFamily: 'monospace');
    final yTicks = [3950.0, 2950.0, 1950.0, 950.0];
    for (final v in yTicks) {
      if (v < min || v > max) continue;
      final y = ptToXY(v, 0).dy;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
      _drawText(canvas, '${v.toInt()}ft', Offset(padL - 6, y - 4), labelStyle, alignRight: true);
    }

    // Fill under curve (animated reveal via clip)
    final path = Path();
    for (var i = 0; i < n; i++) {
      final p = ptToXY(pts[i], i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    final lastDrawIdx = (progress * (n - 1)).floor();
    final partial = Path();
    for (var i = 0; i <= lastDrawIdx && i < n; i++) {
      final p = ptToXY(pts[i], i);
      if (i == 0) {
        partial.moveTo(p.dx, p.dy);
      } else {
        partial.lineTo(p.dx, p.dy);
      }
    }
    // Final segment partial
    if (lastDrawIdx < n - 1 && lastDrawIdx >= 0) {
      final segFrac = progress * (n - 1) - lastDrawIdx;
      final a = ptToXY(pts[lastDrawIdx], lastDrawIdx);
      final b = ptToXY(pts[lastDrawIdx + 1], lastDrawIdx + 1);
      partial.lineTo(a.dx + (b.dx - a.dx) * segFrac, a.dy + (b.dy - a.dy) * segFrac);
    }

    final fillPath = Path.from(partial)
      ..lineTo(padL + (n - 1) * stepX * progress.clamp(0.0, 1.0), size.height - padB)
      ..lineTo(padL, size.height - padB)
      ..close();
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x8CFF6A2C), Color(0x05FF6A2C)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = TT.ember
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(partial, strokePaint);

    // Peak marker (only after a bit of progress)
    if (progress > 0.72) {
      var peakIdx = 0;
      for (var i = 1; i < pts.length; i++) {
        if (pts[i] > pts[peakIdx]) peakIdx = i;
      }
      final peak = ptToXY(pts[peakIdx], peakIdx);
      canvas.drawLine(peak, Offset(peak.dx, size.height - padB),
          Paint()..color = const Color(0x47FFFFFF)..strokeWidth = 1);
      canvas.drawCircle(peak, 4.5,
          Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawCircle(peak, 4.5,
          Paint()..color = TT.ember..strokeWidth = 2..style = PaintingStyle.stroke);

      // Peak label bubble
      final rect = Rect.fromCenter(center: Offset(peak.dx, peak.dy - 14), width: 68, height: 18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = TT.emberInk,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = TT.ember..strokeWidth = 0.8..style = PaintingStyle.stroke,
      );
      _drawText(canvas, peakLabel,
          Offset(peak.dx, peak.dy - 23),
          const TextStyle(color: TT.ember2, fontSize: 9.5, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
          alignCenter: true);
    }

    // X axis labels (mile markers 0..10)
    for (var v = 0; v <= 10; v += 2) {
      final x = padL + (v / 10) * (size.width - padL - padR);
      _drawText(canvas, '$v', Offset(x, size.height - 5),
          const TextStyle(color: TT.text3, fontSize: 8.5, fontFamily: 'monospace'),
          alignCenter: true);
    }
  }

  void _drawText(Canvas canvas, String text, Offset at, TextStyle style, {bool alignCenter = false, bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (alignCenter) dx -= tp.width / 2;
    if (alignRight) dx -= tp.width;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_ElevPainter old) => old.progress != progress;
}
