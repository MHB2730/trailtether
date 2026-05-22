import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Subtle wave-contour overlay — Trailtether's signature backdrop motif.
/// Renders 7 stacked curves at ~4% opacity so it never competes with content.
class TTTopoBackdrop extends StatelessWidget {
  final double opacity;
  const TTTopoBackdrop({super.key, this.opacity = 0.7});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(painter: _TopoPainter(), size: Size.infinite),
      ),
    );
  }
}

class _TopoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // Six layered waves drifting top to bottom of the screen.
    const lines = <List<Offset>>[
      [Offset(0, 0.50), Offset(0.25, 0.33), Offset(0.5, 0.43), Offset(1.0, 0.40)],
      [Offset(0, 0.57), Offset(0.25, 0.42), Offset(0.5, 0.50), Offset(1.0, 0.48)],
      [Offset(0, 0.63), Offset(0.25, 0.50), Offset(0.5, 0.57), Offset(1.0, 0.57)],
      [Offset(0, 0.70), Offset(0.25, 0.58), Offset(0.5, 0.63), Offset(1.0, 0.65)],
      [Offset(0, 0.43), Offset(0.25, 0.27), Offset(0.5, 0.37), Offset(1.0, 0.33)],
      [Offset(0, 0.37), Offset(0.25, 0.20), Offset(0.5, 0.30), Offset(1.0, 0.27)],
      [Offset(0, 0.30), Offset(0.25, 0.13), Offset(0.5, 0.23), Offset(1.0, 0.20)],
    ];
    for (final pts in lines) {
      final path = Path()..moveTo(pts[0].dx * size.width, pts[0].dy * size.height);
      for (var i = 1; i < pts.length; i++) {
        final c1x = (pts[i - 1].dx + 0.1) * size.width;
        final c1y = pts[i - 1].dy * size.height;
        final c2x = (pts[i].dx - 0.1) * size.width;
        final c2y = pts[i].dy * size.height;
        path.cubicTo(c1x, c1y, c2x, c2y, pts[i].dx * size.width, pts[i].dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TopoPainter old) => false;
}

/// Pulsing concentric rings (SOS dial, urgent markers).
class TTPulseRings extends StatefulWidget {
  final double size;
  final Color color;
  final int rings;
  const TTPulseRings({
    super.key,
    this.size = 200,
    this.color = TT.ember,
    this.rings = 3,
  });

  @override
  State<TTPulseRings> createState() => _TTPulseRingsState();
}

class _TTPulseRingsState extends State<TTPulseRings> with TickerProviderStateMixin {
  late final List<AnimationController> _ctls;

  @override
  void initState() {
    super.initState();
    _ctls = List.generate(widget.rings, (i) {
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
      Future.delayed(Duration(milliseconds: i * 800), () { if (mounted) c.repeat(); });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _ctls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: _ctls.map((c) {
          return AnimatedBuilder(
            animation: c,
            builder: (_, __) {
              final t = c.value;
              final scale = 0.7 + 0.8 * t;
              final opacity = (1 - t).clamp(0.0, 1.0) * 0.7;
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 2),
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

/// Floating ember FAB used on Map / Team / etc.
class TTFAB extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  const TTFAB({super.key, required this.icon, this.label, this.onTap});

  @override
  State<TTFAB> createState() => _TTFABState();
}

class _TTFABState extends State<TTFAB> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -4 * Curves.easeInOut.transform(_ctl.value)),
        child: child,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: widget.label == null ? 18 : 18, vertical: 14),
          decoration: BoxDecoration(
            color: TT.ember,
            borderRadius: BorderRadius.circular(widget.label == null ? 999 : 16),
            boxShadow: TT.shadowEmber,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: TT.emberInk),
              if (widget.label != null) ...[
                const SizedBox(width: 8),
                Text(widget.label!,
                    style: TT.body(size: 12, w: FontWeight.w900, color: TT.emberInk)
                        .copyWith(letterSpacing: 0.12 * 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
