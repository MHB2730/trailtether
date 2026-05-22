import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Surface card matching the design's `.card` primitive — graphite surface
/// with a faint top-sheen and a single hairline border. Default radius is
/// [TT.rLg]. Pass [tight] for a smaller-radius variant used by tiles.
class TTCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final bool tight;
  final VoidCallback? onTap;

  const TTCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.tight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? (tight ? TT.rMd : TT.rLg);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x06FFFFFF), Color(0x00FFFFFF)],
        ),
        color: TT.surf,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: TT.line, width: 1),
        boxShadow: TT.shadowCard,
      ),
      child: child,
    );
    final onTapLocal = onTap;
    if (onTapLocal == null) return card;
    return _Pressable(onTap: onTapLocal, child: card);
  }
}

/// Glass surface for floating overlays (map stat cards, zoom controls) — uses
/// a saturated translucent fill rather than the solid graphite of [TTCard].
class TTGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;

  const TTGlass({
    super.key,
    required this.child,
    this.padding,
    this.radius = TT.rMd,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xB80D1116), // ~72% bg
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: TT.line2, width: 1),
      ),
      child: child,
    );
    final onTapLocal = onTap;
    if (onTapLocal == null) return glass;
    return _Pressable(onTap: onTapLocal, child: glass);
  }
}

class _Pressable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _Pressable({required this.onTap, required this.child});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.985 : 1.0,
        duration: TT.dFast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
