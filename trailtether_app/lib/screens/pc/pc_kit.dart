// PC "Base Camp" shared UI kit.
//
// Small, self-contained primitives shared across the PC desktop screens
// (Mission Control, Hikers, Hike Watch, Alerts, History, Settings). These
// depend only on the TT design tokens so any PC screen file can import this
// without pulling in the whole shell. Larger primitives (PCBtn / PCCard /
// PCStat / PCPill / PCPageHeader) still live in pc_shell.dart and are imported
// from there.
//
// Mirrors basecamp/shared.jsx from the v3 design handoff: BCMiniBattery,
// BCAvatar, the pulse dot, and the mono section eyebrow.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';

/// A softly-pulsing status dot (1 → 0.35 → 1 over 1.4s). Used for "live" /
/// "watching" indicators in the sidebar, pills and panel headers.
class PcPulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PcPulseDot({super.key, this.color = TT.green, this.size = 6});

  @override
  State<PcPulseDot> createState() => _PcPulseDotState();
}

class _PcPulseDotState extends State<PcPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

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
        final t = _ctl.value;
        final opacity = 0.35 + 0.65 * (0.5 + 0.5 * math.cos(t * math.pi * 2));
        return Opacity(
          opacity: opacity,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(color: widget.color.withOpacity(0.55), blurRadius: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Initials avatar with a colour derived from the name hash. Mirrors the
/// design's BCAvatar / the old _AvatarCircle.
class PcAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool ring;
  const PcAvatar(
      {super.key, required this.name, this.size = 38, this.ring = true});

  static const _palette = [
    Color(0xFFFF6A2C),
    Color(0xFF4CC38A),
    Color(0xFFF2A93B),
    Color(0xFF5AA1D6),
    Color(0xFFE63D2E),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials =
        parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty
            ? (parts.first[0] + parts.last[0]).toUpperCase()
            : (parts.first.isEmpty
                ? '?'
                : parts.first
                    .substring(0, parts.first.length >= 2 ? 2 : 1)
                    .toUpperCase());
    final c = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring ? Border.all(color: c, width: 2) : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c, c.withOpacity(0.66)],
        ),
      ),
      child: Text(
        initials,
        style:
            TT.body(size: size * 0.34, w: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

/// Compact battery gauge with a colour ramp (green > 50, amber > 25, red ≤ 25).
/// Renders an em-dash when the percentage is unknown (null). Mirrors
/// BCMiniBattery from the design.
class PcMiniBattery extends StatelessWidget {
  final int? pct;
  const PcMiniBattery({super.key, required this.pct});

  @override
  Widget build(BuildContext context) {
    final p = pct;
    if (p == null) {
      return Text('—', style: TT.mono(size: 10, color: TT.text4));
    }
    final c = p > 50 ? TT.green : (p > 25 ? TT.amber : TT.red);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 11,
          padding: const EdgeInsets.all(1.2),
          decoration: BoxDecoration(
            border: Border.all(color: TT.text3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (p / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text('$p%',
            style: TT
                .mono(size: 9, color: c, letterSpacing: 0.04 * 9)
                .copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// The mono eyebrow used as a panel header ("ACTIVE HIKERS", "SUMMIT WEATHER").
class PcSectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const PcSectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TT
          .body(size: 11, w: FontWeight.w800, color: color ?? TT.text2)
          .copyWith(letterSpacing: 0.16 * 11),
    );
  }
}
