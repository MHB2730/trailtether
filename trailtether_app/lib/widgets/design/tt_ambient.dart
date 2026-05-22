import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Slow-drifting radial ember glow stack used behind every Trailtether 2.0
/// screen. Two large radial gradients (top-right + bottom-left) that breathe
/// over ~14s, set behind the content. Add as the first child of a Stack.
class TTAmbient extends StatefulWidget {
  const TTAmbient({super.key});
  @override
  State<TTAmbient> createState() => _TTAmbientState();
}

class _TTAmbientState extends State<TTAmbient> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat(reverse: true);

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_ctl.value);
          final dy = -12 * t;
          final scale = 1.0 + 0.08 * t;
          final opacity = 0.85 + 0.15 * t;
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.9, -1.1),
                      radius: 1.0,
                      colors: [Color(0x1AFF6A2C), Color(0x00FF6A2C)],
                      stops: [0.0, 0.5],
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-1.2, 1.1),
                        radius: 1.0,
                        colors: [Color(0x0FFF6A2C), Color(0x00FF6A2C)],
                        stops: [0.0, 0.5],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shimmering band overlay — for promotion banners (Health Connect synced).
class TTShimmerBand extends StatefulWidget {
  final BorderRadius? borderRadius;
  const TTShimmerBand({super.key, this.borderRadius});

  @override
  State<TTShimmerBand> createState() => _TTShimmerBandState();
}

class _TTShimmerBandState extends State<TTShimmerBand> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(TT.rMd),
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (_, __) {
            final dx = -1.5 + _ctl.value * 3.0; // -1.5 → 1.5
            return Stack(
              fit: StackFit.expand,
              children: [
                FractionalTranslation(
                  translation: Offset(dx, 0),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-0.5, -0.2),
                        end: Alignment(0.5, 0.2),
                        colors: [Color(0x00FFFFFF), Color(0x2EFFFFFF), Color(0x00FFFFFF)],
                        stops: [0.3, 0.5, 0.7],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
