import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

enum TTPillVariant { neutral, ember, live, danger }

/// Compact uppercase pill — used for status badges (LIVE, GPS, IN PROGRESS).
class TTPill extends StatelessWidget {
  final String label;
  final TTPillVariant variant;
  final IconData? leadingIcon;

  const TTPill({
    super.key,
    required this.label,
    this.variant = TTPillVariant.neutral,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg, fg, border;
    switch (variant) {
      case TTPillVariant.ember:
        bg = TT.emberDim;
        fg = TT.ember;
        border = const Color(0x59FF6A2C);
        break;
      case TTPillVariant.danger:
        bg = const Color(0x1AE63D2E);
        fg = TT.red;
        border = const Color(0x59E63D2E);
        break;
      case TTPillVariant.live:
      case TTPillVariant.neutral:
        bg = const Color(0x07FFFFFF);
        fg = TT.text2;
        border = TT.line2;
        break;
    }

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (variant == TTPillVariant.live) ...[
            const _PulseDot(color: TT.green),
            const SizedBox(width: 6),
          ] else if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 11, color: fg),
            const SizedBox(width: 5),
          ],
          Text(label, style: TT.mono(size: 9.5, color: fg, letterSpacing: 1.14)),
        ],
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
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

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
          boxShadow: [BoxShadow(color: widget.color, blurRadius: 8, spreadRadius: 0)],
        ),
      ),
    );
  }
}
