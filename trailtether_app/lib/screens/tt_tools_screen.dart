// Trailtether 2.0 — Tools screen.
//
// Compass-focused tool picker recreating project/screens/tools.jsx from the
// design bundle: brand bar + a horizontally scrolling tool tab strip
// (Compass / Level / Torch / Altimeter / Sun / Info) over a body that
// AnimatedSwitch-fades between each tool's distinct visual. Entirely
// self-contained — no provider/sensor reads — so it stays a pure
// presentation surface that can be wired up later.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

enum _Tool { compass, level, torch, altimeter, sun, info }

class _ToolSpec {
  final _Tool id;
  final String label;
  final IconData icon;
  const _ToolSpec(this.id, this.label, this.icon);
}

const List<_ToolSpec> _kTools = [
  _ToolSpec(_Tool.compass,   'Compass',   Icons.explore_outlined),
  _ToolSpec(_Tool.level,     'Level',     Icons.center_focus_strong_outlined),
  _ToolSpec(_Tool.torch,     'Torch',     Icons.local_fire_department_outlined),
  _ToolSpec(_Tool.altimeter, 'Altimeter', Icons.terrain_outlined),
  _ToolSpec(_Tool.sun,       'Sun',       Icons.wb_sunny_outlined),
  _ToolSpec(_Tool.info,      'Info',      Icons.tips_and_updates_outlined),
];

class TTToolsScreen extends StatefulWidget {
  final bool embedded;
  const TTToolsScreen({super.key, this.embedded = false});

  @override
  State<TTToolsScreen> createState() => _TTToolsScreenState();
}

class _TTToolsScreenState extends State<TTToolsScreen> {
  _Tool _tool = _Tool.compass;

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        const Positioned.fill(child: TTAmbient()),
        const Positioned.fill(child: TTTopoBackdrop(opacity: 0.55)),
        SafeArea(
          top: !widget.embedded,
          bottom: false,
          child: Column(
            children: [
              TTPageAppBar(
                title: 'Hiking Tools',
                trailing: [
                  TTIconBtn(icon: Icons.settings_outlined, onTap: () {}),
                ],
              ),
              _ToolPicker(
                active: _tool,
                onChange: (t) => setState(() => _tool = t),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: TT.dMed,
                  switchInCurve: TT.easeOut,
                  switchOutCurve: TT.easeOut,
                  transitionBuilder: (child, anim) {
                    final scale = Tween<double>(begin: 0.96, end: 1.0).animate(anim);
                    return FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: scale, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_tool),
                    child: _toolBody(_tool),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }

  Widget _toolBody(_Tool t) {
    switch (t) {
      case _Tool.compass:   return const _CompassTool();
      case _Tool.level:     return const _LevelTool();
      case _Tool.torch:     return const _TorchTool();
      case _Tool.altimeter: return const _AltimeterTool();
      case _Tool.sun:       return const _SunTool();
      case _Tool.info:      return const _InfoTool();
    }
  }
}

// ──────────────────────────── TOOL PICKER ───────────────────────────────────

class _ToolPicker extends StatelessWidget {
  final _Tool active;
  final ValueChanged<_Tool> onChange;
  const _ToolPicker({required this.active, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
        itemCount: _kTools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = _kTools[i];
          final a = t.id == active;
          return _ToolTab(spec: t, active: a, onTap: () => onChange(t.id));
        },
      ),
    );
  }
}

class _ToolTab extends StatefulWidget {
  final _ToolSpec spec;
  final bool active;
  final VoidCallback onTap;
  const _ToolTab({required this.spec, required this.active, required this.onTap});

  @override
  State<_ToolTab> createState() => _ToolTabState();
}

class _ToolTabState extends State<_ToolTab> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: TT.dFast,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: TT.dMed,
          curve: TT.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: a ? TT.emberDim : TT.surf,
            border: Border.all(
              color: a ? const Color(0x5CFF6A2C) : TT.line,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: a
                ? const [BoxShadow(color: Color(0x40FF6A2C), blurRadius: 14, spreadRadius: -6)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.spec.icon, size: 14, color: a ? TT.ember : TT.text2),
              const SizedBox(width: 7),
              Text(
                widget.spec.label.toUpperCase(),
                style: TT.body(size: 11, w: FontWeight.w800, color: a ? TT.ember : TT.text2)
                    .copyWith(letterSpacing: 0.1 * 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── COMPASS ───────────────────────────────────────

class _CompassTool extends StatelessWidget {
  const _CompassTool();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        TTCard(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TT.rLg),
                      gradient: const RadialGradient(
                        center: Alignment.center,
                        radius: 0.9,
                        colors: [Color(0x1FFF6A2C), Color(0x00FF6A2C)],
                        stops: [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  const _CompassDial(bearing: 142),
                  const SizedBox(height: 18),
                  TTCountUp(
                    text: '142°',
                    style: TT.numStyle(size: 38, letterSpacing: -0.025 * 38),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SOUTHEAST · SE',
                    style: TT.body(size: 12, w: FontWeight.w800, color: TT.ember)
                        .copyWith(letterSpacing: 0.2 * 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _MetricGrid(tiles: [
          _MetricSpec(icon: Icons.navigation_outlined, label: 'Heading',  value: '142°',  unit: 'SE',  ember: true),
          _MetricSpec(icon: Icons.layers_outlined,     label: 'Magnetic', value: '-3.2°', unit: 'DEC'),
          _MetricSpec(icon: Icons.terrain_outlined,    label: 'Altitude', value: '1,842', unit: 'm'),
          _MetricSpec(icon: Icons.center_focus_strong_outlined, label: 'GPS Acc', value: '+/- 3', unit: 'm'),
        ]),
        const SizedBox(height: 14),
        const _Callout(
          icon: Icons.info_outline,
          color: TT.blue,
          text: 'Hold flat. Calibrate by drawing a figure-8 if values feel off.',
        ),
      ],
    );
  }
}

class _CompassDial extends StatefulWidget {
  final double bearing;
  const _CompassDial({required this.bearing});

  @override
  State<_CompassDial> createState() => _CompassDialState();
}

class _CompassDialState extends State<_CompassDial> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();

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
        // Sin-based wiggle: +/- 1.5 degrees around the current bearing.
        final wiggle = math.sin(_ctl.value * 2 * math.pi) * 1.5;
        return SizedBox(
          width: 220, height: 220,
          child: CustomPaint(
            painter: _CompassPainter(bearing: widget.bearing + wiggle),
          ),
        );
      },
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double bearing;
  _CompassPainter({required this.bearing});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Outer disc gradient + rim.
    final discPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF0D1116), Color(0xFF06080B)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r - 10, discPaint);
    final rim = Paint()
      ..color = TT.line2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(c, r - 10, rim);
    canvas.drawCircle(
      c, r - 24,
      Paint()
        ..color = TT.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Tick marks every 7.5 degrees: 48 total, every 12th = major, every 4th = mid.
    for (var i = 0; i < 48; i++) {
      final ang = (i * 7.5 - 90) * math.pi / 180;
      final major = i % 12 == 0;
      final mid = i % 4 == 0;
      final r1 = r - 14;
      final r2 = major ? r - 30 : (mid ? r - 24 : r - 20);
      final p = Paint()
        ..color = major ? TT.ember2 : (mid ? TT.text2 : TT.text4)
        ..strokeWidth = major ? 2 : (mid ? 1.2 : 0.8)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(c.dx + math.cos(ang) * r1, c.dy + math.sin(ang) * r1),
        Offset(c.dx + math.cos(ang) * r2, c.dy + math.sin(ang) * r2),
        p,
      );
    }

    // Cardinal labels: N (ember), E S W (muted).
    _drawText(canvas, 'N', Offset(c.dx, c.dy - r + 28), TT.ember, 14, FontWeight.w900);
    _drawText(canvas, 'E', Offset(c.dx + r - 36, c.dy), TT.text2, 11, FontWeight.w800);
    _drawText(canvas, 'S', Offset(c.dx, c.dy + r - 25), TT.text2, 11, FontWeight.w800);
    _drawText(canvas, 'W', Offset(c.dx - r + 36, c.dy), TT.text2, 11, FontWeight.w800);

    // Rotate canvas for the needle/sector by the bearing.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(bearing * math.pi / 180);

    // Heading sector arc — 65 degree wedge of soft ember to mark current bearing.
    final sectorPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, -(r - 22));
    final wedgeRect = Rect.fromCircle(center: Offset.zero, radius: r - 22);
    sectorPath.arcTo(wedgeRect, -math.pi / 2, 65 * math.pi / 180, false);
    sectorPath.close();
    canvas.drawPath(
      sectorPath,
      Paint()..color = const Color(0x29FF6A2C),
    );

    // Needle — ember north tip, graphite south tip.
    final needleN = Path()
      ..moveTo(0, -(r - 36))
      ..lineTo(6, 0)
      ..lineTo(0, 6)
      ..lineTo(-6, 0)
      ..close();
    final needleS = Path()
      ..moveTo(0, r - 36)
      ..lineTo(6, 0)
      ..lineTo(0, -6)
      ..lineTo(-6, 0)
      ..close();
    canvas.drawPath(needleN, Paint()..color = TT.ember);
    canvas.drawPath(needleS, Paint()..color = TT.text4);

    canvas.restore();

    // Pivot.
    canvas.drawCircle(
      c, 6,
      Paint()..color = TT.emberInk,
    );
    canvas.drawCircle(
      c, 6,
      Paint()
        ..color = TT.ember2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(c, 2, Paint()..color = TT.ember2);
  }

  void _drawText(Canvas canvas, String text, Offset center, Color color, double size, FontWeight w) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TT.body(size: size, w: w, color: color)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.bearing != bearing;
}

// ──────────────────────────── LEVEL ─────────────────────────────────────────

class _LevelTool extends StatelessWidget {
  const _LevelTool();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        TTCard(
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TT.rLg),
                      gradient: const RadialGradient(
                        center: Alignment.center,
                        radius: 0.95,
                        colors: [Color(0x144CC38A), Color(0x004CC38A)],
                        stops: [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  const SizedBox(
                    width: 240, height: 240,
                    child: _BubbleLevel(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      TTCountUp(
                        text: '2.4°',
                        style: TT.numStyle(size: 32, letterSpacing: -0.02 * 32),
                      ),
                      const SizedBox(width: 8),
                      Text('tilt', style: TT.body(size: 14, color: TT.text2)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'NEARLY LEVEL',
                    style: TT.body(size: 11, w: FontWeight.w800, color: TT.green)
                        .copyWith(letterSpacing: 0.16 * 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _MetricGrid(tiles: [
          _MetricSpec(icon: Icons.swap_horiz, label: 'Pitch', value: '2.4°', ember: true),
          _MetricSpec(icon: Icons.swap_vert,  label: 'Roll',  value: '1.1°'),
        ]),
      ],
    );
  }
}

class _BubbleLevel extends StatefulWidget {
  const _BubbleLevel();

  @override
  State<_BubbleLevel> createState() => _BubbleLevelState();
}

class _BubbleLevelState extends State<_BubbleLevel> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat();

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
        // Subtle wobble — two-axis sin so the bubble drifts in a small orbit.
        final t = _ctl.value * 2 * math.pi;
        final dx = math.sin(t) * 5;
        final dy = math.cos(t * 1.3) * 4;
        return CustomPaint(
          painter: _BubbleLevelPainter(offset: Offset(dx, dy)),
        );
      },
    );
  }
}

class _BubbleLevelPainter extends CustomPainter {
  final Offset offset;
  _BubbleLevelPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 10;

    canvas.drawCircle(
      c, r,
      Paint()..color = const Color(0xFF06080B),
    );
    canvas.drawCircle(
      c, r,
      Paint()
        ..color = TT.line2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Concentric rings.
    for (final rr in [90.0, 70.0, 50.0, 30.0]) {
      canvas.drawCircle(
        c, rr,
        Paint()
          ..color = const Color(0x0FFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Crosshair.
    final ch = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), ch);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), ch);

    // Ember target ring (dashed).
    _drawDashedCircle(canvas, c, 22,
        Paint()
          ..color = TT.ember
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Bubble — green glass with soft glow.
    final bubble = c + Offset(18 + offset.dx, -12 + offset.dy);
    canvas.drawCircle(
      bubble, 22,
      Paint()
        ..color = const Color(0x224CC38A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      bubble, 18,
      Paint()..color = const Color(0x404CC38A),
    );
    canvas.drawCircle(
      bubble, 18,
      Paint()
        ..color = TT.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Highlight pip on the bubble.
    canvas.drawCircle(
      bubble + const Offset(-5, -5), 4,
      Paint()..color = const Color(0xB3FFFFFF),
    );
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const segments = 24;
    for (var i = 0; i < segments; i++) {
      if (i.isOdd) continue;
      final a1 = (i / segments) * 2 * math.pi;
      final a2 = ((i + 1) / segments) * 2 * math.pi;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final path = Path()..addArc(rect, a1, a2 - a1);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BubbleLevelPainter old) => old.offset != offset;
}

// ──────────────────────────── TORCH ─────────────────────────────────────────

class _TorchTool extends StatefulWidget {
  const _TorchTool();

  @override
  State<_TorchTool> createState() => _TorchToolState();
}

class _TorchToolState extends State<_TorchTool> with SingleTickerProviderStateMixin {
  bool _on = true;
  late final AnimationController _flicker =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        TTCard(
          padding: const EdgeInsets.fromLTRB(18, 32, 18, 28),
          child: SizedBox(
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_on)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _flicker,
                        builder: (_, __) {
                          final t = Curves.easeInOut.transform(_flicker.value);
                          return Opacity(
                            opacity: 0.9 + 0.1 * t,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(TT.rLg),
                                gradient: const RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.9,
                                  colors: [Color(0x73FFEFAA), Color(0x26FF8A4D), Color(0x00FF8A4D)],
                                  stops: [0.0, 0.4, 0.75],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TorchButton(on: _on, onTap: () => setState(() => _on = !_on)),
                    const SizedBox(height: 18),
                    Text(
                      'TORCH · ${_on ? 'ON' : 'OFF'}',
                      style: TT.body(size: 13, w: FontWeight.w800, color: _on ? TT.ember : TT.text3)
                          .copyWith(letterSpacing: 0.2 * 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to toggle',
                      style: TT.mono(size: 11, color: TT.text3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _MetricGrid(tiles: [
          _MetricSpec(icon: Icons.local_fire_department_outlined, label: 'Mode',   value: 'Steady'),
          _MetricSpec(icon: Icons.warning_amber_outlined,         label: 'Strobe', value: 'OFF'),
        ]),
      ],
    );
  }
}

class _TorchButton extends StatefulWidget {
  final bool on;
  final VoidCallback onTap;
  const _TorchButton({required this.on, required this.onTap});

  @override
  State<_TorchButton> createState() => _TorchButtonState();
}

class _TorchButtonState extends State<_TorchButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: TT.dFast,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: TT.dMed,
          width: 140, height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: on
                ? const RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    radius: 0.95,
                    colors: [Color(0xFFFFEFAA), Color(0xFFFF8A4D), Color(0xFFD6291F)],
                    stops: [0.0, 0.6, 1.0],
                  )
                : const RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    radius: 0.95,
                    colors: [Color(0xFF2A313C), Color(0xFF0A0C0F)],
                  ),
            border: Border.all(
              color: on ? const Color(0xFFFFD5A0) : const Color(0xFF2A313C),
              width: 3,
            ),
            boxShadow: on
                ? const [BoxShadow(color: Color(0xB3FF8A4D), blurRadius: 50, spreadRadius: 0)]
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.local_fire_department,
            size: 56,
            color: on ? TT.emberInk : TT.text3,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── ALTIMETER ─────────────────────────────────────

class _AltimeterTool extends StatelessWidget {
  const _AltimeterTool();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        TTCard(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TT.rLg),
                      gradient: const RadialGradient(
                        center: Alignment(0, 1.0),
                        radius: 0.9,
                        colors: [Color(0x1FFF6A2C), Color(0x00FF6A2C)],
                        stops: [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CURRENT ELEVATION',
                    textAlign: TextAlign.center,
                    style: TT.label(size: 11, color: TT.text3, letterSpacing: 0.18 * 11),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      TTCountUp(
                        text: '1,842',
                        style: TT.numStyle(size: 56, color: TT.ember, w: FontWeight.w900, letterSpacing: -0.03 * 56),
                      ),
                      const SizedBox(width: 6),
                      Text('m', style: TT.body(size: 20, color: TT.text2, w: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_upward, size: 12, color: TT.green),
                      const SizedBox(width: 4),
                      Text('+12 m last hour',
                          style: TT.mono(size: 11, color: TT.green, w: FontWeight.w700)),
                      const SizedBox(width: 10),
                      Container(width: 3, height: 3, decoration: const BoxDecoration(color: TT.text3, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text('6,043 ft',
                          style: TT.mono(size: 11, color: TT.text3)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 80,
                    child: CustomPaint(painter: _SparkPainter(), size: Size.infinite),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('06:00', style: TT.mono(size: 9, color: TT.text3)),
                        Text('08:00', style: TT.mono(size: 9, color: TT.text3)),
                        Text('10:00', style: TT.mono(size: 9, color: TT.text3)),
                        Text('NOW', style: TT.mono(size: 9, color: TT.ember)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _MetricGrid(tiles: [
          _MetricSpec(icon: Icons.arrow_upward,        label: 'Ascent',  value: '+842',  unit: 'm', ember: true),
          _MetricSpec(icon: Icons.arrow_downward,      label: 'Descent', value: '-210',  unit: 'm'),
          _MetricSpec(icon: Icons.terrain_outlined,    label: 'Max',     value: '1,842', unit: 'm'),
          _MetricSpec(icon: Icons.layers_outlined,     label: 'Min',     value: '1,210', unit: 'm'),
        ]),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Sample curve — ascending elevation profile.
    final path = Path()
      ..moveTo(0, h * 0.85)
      ..quadraticBezierTo(w * 0.15, h * 0.75, w * 0.28, h * 0.60)
      ..quadraticBezierTo(w * 0.45, h * 0.50, w * 0.55, h * 0.40)
      ..quadraticBezierTo(w * 0.7, h * 0.32, w * 0.82, h * 0.22)
      ..quadraticBezierTo(w * 0.92, h * 0.18, w, h * 0.12);

    // Fill underneath.
    final fill = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x80FF6A2C), Color(0x00FF6A2C)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Stroke.
    canvas.drawPath(
      path,
      Paint()
        ..color = TT.ember
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Endpoint dot.
    final endpoint = Offset(w, h * 0.12);
    canvas.drawCircle(
      endpoint, 5,
      Paint()..color = const Color(0x40FF6A2C),
    );
    canvas.drawCircle(
      endpoint, 3,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      endpoint, 3,
      Paint()
        ..color = TT.ember
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => false;
}

// ──────────────────────────── SUN ───────────────────────────────────────────

class _SunTool extends StatelessWidget {
  const _SunTool();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        TTCard(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TT.rLg),
                      gradient: const RadialGradient(
                        center: Alignment(0, 1.0),
                        radius: 0.95,
                        colors: [Color(0x2EFF8A4D), Color(0x00FF8A4D)],
                        stops: [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    height: 160,
                    child: CustomPaint(painter: _SunArcPainter(), size: Size.infinite),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      TTCountUp(
                        text: '10:09',
                        style: TT.numStyle(size: 38, w: FontWeight.w900, letterSpacing: -0.025 * 38),
                      ),
                      const SizedBox(width: 6),
                      Text('AM', style: TT.body(size: 16, color: TT.text2)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SUN IS UP · 4h 22m TO PEAK',
                    style: TT.body(size: 11, w: FontWeight.w800, color: TT.ember)
                        .copyWith(letterSpacing: 0.18 * 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _MetricGrid(tiles: [
          _MetricSpec(icon: Icons.wb_twilight,    label: 'Sunrise',  value: '05:47', ember: true),
          _MetricSpec(icon: Icons.nights_stay_outlined, label: 'Sunset',   value: '18:23'),
          _MetricSpec(icon: Icons.schedule,       label: 'Daylight', value: '12h 36m'),
          _MetricSpec(icon: Icons.wb_sunny_outlined, label: 'UV Index', value: '6', unit: 'HIGH'),
        ]),
      ],
    );
  }
}

class _SunArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;

    // Horizon line.
    canvas.drawLine(
      const Offset(0, 130), Offset(w, 130),
      Paint()
        ..color = const Color(0x1AFFFFFF)
        ..strokeWidth = 1,
    );

    // Arc — Q curve approximation: M 20 130 Q w/2 -20 (w-20) 130
    final arc = Path()
      ..moveTo(20, 130)
      ..quadraticBezierTo(w / 2, -20, w - 20, 130);

    canvas.drawPath(
      arc,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FF8A4D), Color(0xE6FF8A4D), Color(0x00FF8A4D)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, 160))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Sun (~midway along the arc — t=0.45).
    const t = 0.45;
    final sunX = (1 - t) * (1 - t) * 20 + 2 * (1 - t) * t * (w / 2) + t * t * (w - 20);
    const sunY = (1 - t) * (1 - t) * 130 + 2 * (1 - t) * t * (-20) + t * t * 130;

    // Sun rays.
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        Offset(sunX + math.cos(a) * 18, sunY + math.sin(a) * 18),
        Offset(sunX + math.cos(a) * 24, sunY + math.sin(a) * 24),
        Paint()
          ..color = const Color(0xB3FF8A4D)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
    // Sun glow + disc.
    canvas.drawCircle(
      Offset(sunX, sunY), 22,
      Paint()
        ..color = const Color(0x66FF8A4D)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      Offset(sunX, sunY), 14,
      Paint()..color = TT.ember2,
    );

    // Sunrise/sunset markers.
    canvas.drawCircle(const Offset(20, 130), 3, Paint()..color = TT.ember3);
    canvas.drawCircle(Offset(w - 20, 130), 3, Paint()..color = TT.blue);
  }

  @override
  bool shouldRepaint(_SunArcPainter old) => false;
}

// ──────────────────────────── INFO ──────────────────────────────────────────

class _InfoTool extends StatelessWidget {
  const _InfoTool();

  static const _tips = <_InfoTip>[
    _InfoTip(icon: Icons.place_outlined,          title: 'Tell someone your route',          body: 'Share trail name + expected return.'),
    _InfoTip(icon: Icons.local_fire_department_outlined, title: 'Pack layers, not weight',   body: 'Mountain temps drop 6 degrees C per 1,000m.'),
    _InfoTip(icon: Icons.air,                      title: 'Watch the wind shift',             body: 'A sudden change often precedes a front.'),
    _InfoTip(icon: Icons.water_drop_outlined,      title: 'Hydrate before you are thirsty',   body: 'Thirst lags 1-2 hours behind dehydration.'),
    _InfoTip(icon: Icons.bolt_outlined,            title: 'Lightning: count then crouch',     body: 'Under 30s between flash and thunder = strike risk.'),
    _InfoTip(icon: Icons.battery_charging_full,    title: 'Conserve your phone battery',      body: 'Airplane mode + offline maps stretches charge.'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      itemCount: _tips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _FadeUpDelayed(
        delay: Duration(milliseconds: 100 + i * 70),
        child: _InfoRow(tip: _tips[i]),
      ),
    );
  }
}

class _InfoTip {
  final IconData icon;
  final String title;
  final String body;
  const _InfoTip({required this.icon, required this.title, required this.body});
}

class _InfoRow extends StatelessWidget {
  final _InfoTip tip;
  const _InfoRow({required this.tip});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () {},
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: TT.emberDim,
              border: Border.all(color: const Color(0x52FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(tip.icon, size: 16, color: TT.ember),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title, style: TT.body(size: 13.5, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(tip.body, style: TT.body(size: 11.5, color: TT.text2).copyWith(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── SHARED PIECES ─────────────────────────────────

class _MetricSpec {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final bool ember;
  const _MetricSpec({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.ember = false,
  });
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricSpec> tiles;
  const _MetricGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.95,
      ),
      itemBuilder: (_, i) => _FadeUpDelayed(
        delay: Duration(milliseconds: 250 + i * 80),
        child: _MetricTile(spec: tiles[i]),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _MetricSpec spec;
  const _MetricTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 12, color: spec.ember ? TT.ember : TT.text3),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  spec.label.toUpperCase(),
                  style: TT.label(size: 9.5, color: TT.text3, letterSpacing: 0.16 * 9.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  spec.value,
                  style: TT.numStyle(
                    size: 20,
                    color: spec.ember ? TT.ember : TT.text,
                    letterSpacing: -0.02 * 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (spec.unit != null) ...[
                const SizedBox(width: 4),
                Text(spec.unit!, style: TT.mono(size: 10, color: TT.text2, w: FontWeight.w600)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Callout({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TT.body(size: 11, w: FontWeight.w600, color: TT.text2).copyWith(height: 1.4),
            ),
          ),
          // Tiny status pill to keep the visual recipe consistent with other screens.
          const SizedBox(width: 8),
          const TTPill(label: 'TIP'),
        ],
      ),
    );
  }
}

class _FadeUpDelayed extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _FadeUpDelayed({required this.delay, required this.child});

  @override
  State<_FadeUpDelayed> createState() => _FadeUpDelayedState();
}

class _FadeUpDelayedState extends State<_FadeUpDelayed> with SingleTickerProviderStateMixin {
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
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: widget.child,
          ),
        );
      },
    );
  }
}
