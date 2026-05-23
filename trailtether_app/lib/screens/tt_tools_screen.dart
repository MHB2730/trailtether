// Trailtether 2.0 — Tools screen.
//
// Compass-focused tool picker recreating project/screens/tools.jsx from the
// design bundle: brand bar + a horizontally scrolling tool tab strip
// (Compass / Level / Torch / Altimeter / Sun / Info) over a body that
// AnimatedSwitch-fades between each tool's distinct visual.
//
// Each tool is wired up to real device sensors (flutter_compass, sensors_plus,
// torch_light, geolocator) using the same legacy mechanics as
// `tools_tab.dart` while keeping the v3.0 visual design intact.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:torch_light/torch_light.dart';

import '../core/design_tokens.dart';
import '../core/sun_utils.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
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

class _CompassTool extends StatefulWidget {
  const _CompassTool();

  @override
  State<_CompassTool> createState() => _CompassToolState();
}

class _CompassToolState extends State<_CompassTool> {
  double? _heading;
  bool _available = true;
  StreamSubscription<CompassEvent>? _sub;

  // Live altitude + GPS accuracy for the metric grid below the dial.
  Position? _pos;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _initCompass();
    _initLocation();
  }

  void _initCompass() {
    // flutter_compass has no Windows/macOS/Linux plugin implementation.
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      setState(() => _available = false);
      return;
    }
    try {
      final events = FlutterCompass.events;
      if (events == null) {
        setState(() => _available = false);
        return;
      }
      _sub = events.listen(
        (e) {
          if (mounted && e.heading != null) {
            setState(() => _heading = e.heading!);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _available = false);
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  void _initLocation() {
    try {
      _posSub = Geolocator.getPositionStream(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).listen(
        (p) {
          if (mounted) setState(() => _pos = p);
        },
        onError: (_) {/* leave _pos null — tile will show placeholders */},
      );
    } catch (_) {/* same */}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  String _toCardinal(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((deg + 22.5) / 45).floor() % 8];
  }

  String _toCardinalLong(double deg) {
    const names = [
      'NORTH',
      'NORTHEAST',
      'EAST',
      'SOUTHEAST',
      'SOUTH',
      'SOUTHWEST',
      'WEST',
      'NORTHWEST',
    ];
    return names[((deg + 22.5) / 45).floor() % 8];
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading ?? 0.0;
    final cardinal = _toCardinal(heading);
    final cardinalLong = _toCardinalLong(heading);

    return Stack(
      children: [
        ListView(
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
                      _CompassDial(bearing: heading),
                      const SizedBox(height: 18),
                      Text(
                        '${heading.toStringAsFixed(0)}°',
                        style: TT.numStyle(size: 38, letterSpacing: -0.025 * 38),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$cardinalLong · $cardinal',
                        style: TT.body(size: 12, w: FontWeight.w800, color: TT.ember)
                            .copyWith(letterSpacing: 0.2 * 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _MetricGrid(tiles: [
              _MetricSpec(
                icon: Icons.navigation_outlined,
                label: 'Heading',
                value: '${heading.toStringAsFixed(0)}°',
                unit: cardinal,
                ember: true,
              ),
              const _MetricSpec(
                icon: Icons.layers_outlined,
                label: 'Magnetic',
                value: '-3.2°',
                unit: 'DEC',
              ),
              _MetricSpec(
                icon: Icons.terrain_outlined,
                label: 'Altitude',
                value: _pos == null ? '—' : _pos!.altitude.toStringAsFixed(0),
                unit: 'm',
              ),
              _MetricSpec(
                icon: Icons.center_focus_strong_outlined,
                label: 'GPS Acc',
                value: _pos == null ? '—' : '+/- ${_pos!.accuracy.toStringAsFixed(0)}',
                unit: 'm',
              ),
            ]),
            const SizedBox(height: 14),
            const _Callout(
              icon: Icons.info_outline,
              color: TT.blue,
              text: 'Hold flat. Calibrate by drawing a figure-8 if values feel off.',
            ),
          ],
        ),
        if (!_available)
          const Positioned.fill(
            child: _ToolUnavailableOverlay(
              icon: Icons.explore_off,
              title: 'Compass unavailable',
              subtitle: 'This device has no magnetometer.',
            ),
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

    // Rotate the whole rose by -heading so the cardinal letters and ticks
    // physically align with magnetic compass directions. The needle below is
    // drawn AFTER the restore() so it stays fixed pointing up.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-bearing * math.pi / 180);

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
        Offset(math.cos(ang) * r1, math.sin(ang) * r1),
        Offset(math.cos(ang) * r2, math.sin(ang) * r2),
        p,
      );
    }

    // Cardinal labels: N (ember), E S W (muted). Drawn relative to origin
    // because the canvas has been translated above.
    _drawText(canvas, 'N', Offset(0, -r + 28), TT.ember, 14, FontWeight.w900);
    _drawText(canvas, 'E', Offset(r - 36, 0), TT.text2, 11, FontWeight.w800);
    _drawText(canvas, 'S', Offset(0, r - 25), TT.text2, 11, FontWeight.w800);
    _drawText(canvas, 'W', Offset(-r + 36, 0), TT.text2, 11, FontWeight.w800);

    canvas.restore();

    // Heading indicator wedge — a short 12-degree ember beam that always points
    // straight up at the direction the user is facing.
    final sectorPath = Path()..moveTo(c.dx, c.dy);
    final wedgeRect = Rect.fromCircle(center: c, radius: r - 22);
    sectorPath.arcTo(wedgeRect, -math.pi / 2 - 6 * math.pi / 180,
        12 * math.pi / 180, false);
    sectorPath.close();
    canvas.drawPath(
      sectorPath,
      Paint()..color = const Color(0x29FF6A2C),
    );

    // Fixed needle — ember tip up (= the heading the user is facing).
    canvas.save();
    canvas.translate(c.dx, c.dy);
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

class _LevelTool extends StatefulWidget {
  const _LevelTool();

  @override
  State<_LevelTool> createState() => _LevelToolState();
}

class _LevelToolState extends State<_LevelTool>
    with SingleTickerProviderStateMixin {
  // Accelerometer raw axis values (m/s^2).
  double _ax = 0, _ay = 0, _az = 9.8;
  bool _available = true;
  StreamSubscription<AccelerometerEvent>? _sub;

  // Idle wobble — runs even when no sensor data so the visuals never freeze.
  late final AnimationController _wobble =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))
        ..repeat();

  @override
  void initState() {
    super.initState();
    _initSensor();
  }

  void _initSensor() {
    try {
      _sub = accelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen((e) {
        if (mounted) {
          setState(() {
            _ax = e.x;
            _ay = e.y;
            _az = e.z;
          });
        }
      }, onError: (_) {
        if (mounted) setState(() => _available = false);
      });
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _wobble.dispose();
    super.dispose();
  }

  // Pitch + roll in degrees from raw accelerometer axes.
  double get _pitch =>
      math.atan2(_ay, math.sqrt(_ax * _ax + _az * _az)) * 180 / math.pi;
  double get _roll =>
      math.atan2(-_ax, _az) * 180 / math.pi;
  double get _tilt {
    final p = _pitch;
    final r = _roll;
    return math.sqrt(p * p + r * r);
  }

  @override
  Widget build(BuildContext context) {
    final tilt = _tilt;
    final pitchAbs = _pitch.abs();
    final rollAbs = _roll.abs();
    final level = tilt < 2.0;
    final statusText = level ? 'NEARLY LEVEL' : 'TILTED';
    final statusColor = level ? TT.green : TT.amber;

    return Stack(
      children: [
        ListView(
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
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.95,
                            colors: [statusColor.withOpacity(0.08), const Color(0x004CC38A)],
                            stops: const [0.0, 0.7],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(
                        width: 240, height: 240,
                        child: _BubbleLevel(ax: _ax, ay: _ay, wobble: _wobble),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${tilt.toStringAsFixed(1)}°',
                            style: TT.numStyle(size: 32, letterSpacing: -0.02 * 32),
                          ),
                          const SizedBox(width: 8),
                          Text('tilt', style: TT.body(size: 14, color: TT.text2)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusText,
                        style: TT.body(size: 11, w: FontWeight.w800, color: statusColor)
                            .copyWith(letterSpacing: 0.16 * 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _MetricGrid(tiles: [
              _MetricSpec(
                icon: Icons.swap_horiz,
                label: 'Pitch',
                value: '${pitchAbs.toStringAsFixed(1)}°',
                ember: true,
              ),
              _MetricSpec(
                icon: Icons.swap_vert,
                label: 'Roll',
                value: '${rollAbs.toStringAsFixed(1)}°',
              ),
            ]),
          ],
        ),
        if (!_available)
          const Positioned.fill(
            child: _ToolUnavailableOverlay(
              icon: Icons.bubble_chart_outlined,
              title: 'Accelerometer unavailable',
              subtitle: 'This device has no accelerometer.',
            ),
          ),
      ],
    );
  }
}

class _BubbleLevel extends StatelessWidget {
  final double ax;
  final double ay;
  final AnimationController wobble;
  const _BubbleLevel({required this.ax, required this.ay, required this.wobble});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: wobble,
      builder: (_, __) {
        // Subtle wobble — keeps the bubble alive even with zero tilt.
        final t = wobble.value * 2 * math.pi;
        final wobbleDx = math.sin(t) * 1.2;
        final wobbleDy = math.cos(t * 1.3) * 1.0;
        return CustomPaint(
          painter: _BubbleLevelPainter(ax: ax, ay: ay,
              wobble: Offset(wobbleDx, wobbleDy)),
        );
      },
    );
  }
}

class _BubbleLevelPainter extends CustomPainter {
  final double ax; // x accel (left/right tilt)
  final double ay; // y accel (forward/back tilt)
  final Offset wobble;
  _BubbleLevelPainter({required this.ax, required this.ay, required this.wobble});

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

    // Bubble position from raw accel. Standard phone orientation:
    //   ax > 0 → tilted right     → bubble should move LEFT (negative)
    //   ay > 0 → tilted forward   → bubble should move UP   (negative)
    // Normalize to [-1, 1] using gravity, clamp at ~0.85 of radius.
    final nx = (-ax / 9.8).clamp(-0.85, 0.85);
    final ny = (ay / 9.8).clamp(-0.85, 0.85);
    final mag = math.sqrt(nx * nx + ny * ny);
    final scale = mag > 0.85 ? 0.85 / mag : 1.0;
    const bubbleR = 22.0;
    final bx = c.dx + nx * scale * (r - bubbleR - 4) + wobble.dx;
    final by = c.dy + ny * scale * (r - bubbleR - 4) + wobble.dy;
    final bubble = Offset(bx, by);

    // Bubble — green glass with soft glow.
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
  bool shouldRepaint(_BubbleLevelPainter old) =>
      old.ax != ax || old.ay != ay || old.wobble != wobble;
}

// ──────────────────────────── TORCH ─────────────────────────────────────────

class _TorchTool extends StatefulWidget {
  const _TorchTool();

  @override
  State<_TorchTool> createState() => _TorchToolState();
}

class _TorchToolState extends State<_TorchTool> with SingleTickerProviderStateMixin {
  bool _on = false;
  bool _available = true;
  late final AnimationController _flicker =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    try {
      final ok = await TorchLight.isTorchAvailable();
      if (mounted) setState(() => _available = ok);
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  Future<void> _toggle() async {
    if (!_available) return;
    final next = !_on;
    try {
      if (next) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      if (mounted) setState(() => _on = next);
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  @override
  void dispose() {
    // Best-effort: turn the torch off when leaving so it doesn't get stuck on.
    if (_on) {
      // Fire-and-forget; we're disposing.
      TorchLight.disableTorch().catchError((_) {});
    }
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
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
                        _TorchButton(on: _on, onTap: _available ? _toggle : () {}),
                        const SizedBox(height: 18),
                        Text(
                          !_available
                              ? 'NO FLASHLIGHT AVAILABLE'
                              : 'TORCH · ${_on ? 'ON' : 'OFF'}',
                          style: TT.body(
                                  size: 13,
                                  w: FontWeight.w800,
                                  color: !_available
                                      ? TT.text3
                                      : (_on ? TT.ember : TT.text3))
                              .copyWith(letterSpacing: 0.2 * 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _available ? 'Tap to toggle' : 'This device has no torch.',
                          style: TT.mono(size: 11, color: TT.text3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _MetricGrid(tiles: [
              _MetricSpec(
                icon: Icons.local_fire_department_outlined,
                label: 'Mode',
                value: 'Steady',
                ember: _on,
              ),
              const _MetricSpec(
                icon: Icons.warning_amber_outlined,
                label: 'Strobe',
                value: 'OFF',
              ),
            ]),
          ],
        ),
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

class _AltimeterTool extends StatefulWidget {
  const _AltimeterTool();

  @override
  State<_AltimeterTool> createState() => _AltimeterToolState();
}

class _AltimeterToolState extends State<_AltimeterTool> {
  Position? _pos;
  double? _firstAltitude;
  double _minAlt = double.infinity;
  double _maxAlt = double.negativeInfinity;
  bool _available = true;
  String? _error;
  StreamSubscription<Position>? _sub;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  void _initLocation() {
    try {
      _sub = Geolocator.getPositionStream(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.best),
      ).listen(
        (p) {
          if (!mounted) return;
          setState(() {
            _pos = p;
            _firstAltitude ??= p.altitude;
            if (p.altitude < _minAlt) _minAlt = p.altitude;
            if (p.altitude > _maxAlt) _maxAlt = p.altitude;
          });
        },
        onError: (e) {
          if (mounted) setState(() => _error = e.toString());
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _available = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _fmtAlt(double m) {
    final rounded = m.round();
    if (rounded.abs() < 1000) return '$rounded';
    // Add a thousands separator.
    final s = rounded.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${rounded < 0 ? '-' : ''}$buf';
  }

  @override
  Widget build(BuildContext context) {
    final hasFix = _pos != null;
    final altM = _pos?.altitude ?? 0;
    final altFt = altM * 3.28084;
    final delta = (hasFix && _firstAltitude != null)
        ? (altM - _firstAltitude!)
        : 0.0;
    final deltaPositive = delta >= 0;

    return Stack(
      children: [
        ListView(
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
                          Text(
                            hasFix ? _fmtAlt(altM) : '—',
                            style: TT.numStyle(
                              size: 56,
                              color: TT.ember,
                              w: FontWeight.w900,
                              letterSpacing: -0.03 * 56,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('m', style: TT.body(size: 20, color: TT.text2, w: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            deltaPositive ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 12,
                            color: deltaPositive ? TT.green : TT.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasFix
                                ? '${deltaPositive ? '+' : ''}${delta.toStringAsFixed(0)} m this session'
                                : 'Waiting for GPS fix',
                            style: TT.mono(
                              size: 11,
                              color: hasFix
                                  ? (deltaPositive ? TT.green : TT.amber)
                                  : TT.text3,
                              w: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 3, height: 3,
                            decoration: const BoxDecoration(color: TT.text3, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            hasFix ? '${altFt.toStringAsFixed(0)} ft' : '— ft',
                            style: TT.mono(size: 11, color: TT.text3),
                          ),
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
            _MetricGrid(tiles: [
              _MetricSpec(
                icon: Icons.arrow_upward,
                label: 'Delta',
                value: hasFix
                    ? '${deltaPositive ? '+' : ''}${delta.toStringAsFixed(0)}'
                    : '—',
                unit: 'm',
                ember: true,
              ),
              _MetricSpec(
                icon: Icons.center_focus_strong_outlined,
                label: 'GPS Acc',
                value: hasFix ? '+/- ${_pos!.accuracy.toStringAsFixed(0)}' : '—',
                unit: 'm',
              ),
              _MetricSpec(
                icon: Icons.terrain_outlined,
                label: 'Max',
                value: _maxAlt.isFinite ? _fmtAlt(_maxAlt) : '—',
                unit: 'm',
              ),
              _MetricSpec(
                icon: Icons.layers_outlined,
                label: 'Min',
                value: _minAlt.isFinite ? _fmtAlt(_minAlt) : '—',
                unit: 'm',
              ),
            ]),
          ],
        ),
        if (!_available || _error != null)
          Positioned.fill(
            child: _ToolUnavailableOverlay(
              icon: Icons.gps_off_outlined,
              title: 'Location unavailable',
              subtitle: _error ?? 'Permission needed to read altitude.',
            ),
          ),
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

class _SunTool extends StatefulWidget {
  const _SunTool();

  @override
  State<_SunTool> createState() => _SunToolState();
}

class _SunToolState extends State<_SunTool> {
  Position? _pos;
  bool _waiting = true;
  String? _error;
  StreamSubscription<Position>? _sub;

  // Tick the UI every 30 seconds so "time to peak" / current time stay live.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _initLocation() {
    try {
      _sub = Geolocator.getPositionStream(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).listen(
        (p) {
          if (mounted) {
            setState(() {
              _pos = p;
              _waiting = false;
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _error = e.toString();
              _waiting = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _waiting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  String _hm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _hm12(DateTime dt) {
    final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    return '$h12:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasFix = _pos != null;
    DateTime? sunrise;
    DateTime? sunset;
    double progress = 0;
    final now = DateTime.now();

    if (hasFix) {
      final sun = SunUtils.calculate(now, _pos!.latitude, _pos!.longitude);
      sunrise = sun['sunrise'];
      sunset = sun['sunset'];
      if (sunrise != null && sunset != null) {
        if (now.isBefore(sunrise)) {
          progress = 0;
        } else if (now.isAfter(sunset)) {
          progress = 1;
        } else {
          progress = now.difference(sunrise).inMinutes /
              sunset.difference(sunrise).inMinutes;
        }
      }
    }

    final dayLen = (sunrise != null && sunset != null)
        ? SunUtils.formatDuration(sunset.difference(sunrise))
        : '—';

    // Status copy: time-to-peak when sun is up; otherwise countdown to next event.
    String fmt(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      if (h <= 0) return '${m}M';
      return '${h}H ${m}M';
    }

    String status = 'TAP TO ENABLE LOCATION';
    if (hasFix && sunrise != null && sunset != null) {
      final peak = sunrise.add(sunset.difference(sunrise) ~/ 2);
      if (now.isBefore(sunrise)) {
        status = 'SUN IS DOWN · ${fmt(sunrise.difference(now))} TO SUNRISE';
      } else if (now.isAfter(sunset)) {
        status = 'AFTER SUNSET · PLAN FOR DARKNESS';
      } else if (now.isBefore(peak)) {
        status = 'SUN IS UP · ${fmt(peak.difference(now))} TO PEAK';
      } else {
        status = 'SUN IS UP · ${fmt(sunset.difference(now))} TO SUNSET';
      }
    }

    final ampm = now.hour >= 12 ? 'PM' : 'AM';

    return Stack(
      children: [
        ListView(
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
                        child: CustomPaint(
                          painter: _SunArcPainter(progress: progress),
                          size: Size.infinite,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _hm12(now),
                            style: TT.numStyle(size: 38, w: FontWeight.w900, letterSpacing: -0.025 * 38),
                          ),
                          const SizedBox(width: 6),
                          Text(ampm, style: TT.body(size: 16, color: TT.text2)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: TT.body(size: 11, w: FontWeight.w800, color: TT.ember)
                            .copyWith(letterSpacing: 0.18 * 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _MetricGrid(tiles: [
              _MetricSpec(
                icon: Icons.wb_twilight,
                label: 'Sunrise',
                value: sunrise != null ? _hm(sunrise) : '—',
                ember: true,
              ),
              _MetricSpec(
                icon: Icons.nights_stay_outlined,
                label: 'Sunset',
                value: sunset != null ? _hm(sunset) : '—',
              ),
              _MetricSpec(
                icon: Icons.schedule,
                label: 'Daylight',
                value: dayLen,
              ),
              _MetricSpec(
                icon: Icons.place_outlined,
                label: 'Location',
                value: hasFix
                    ? '${_pos!.latitude.toStringAsFixed(2)},${_pos!.longitude.toStringAsFixed(2)}'
                    : '—',
              ),
            ]),
          ],
        ),
        if (!hasFix && !_waiting)
          Positioned.fill(
            child: _ToolUnavailableOverlay(
              icon: Icons.wb_sunny_outlined,
              title: 'No location fix',
              subtitle: _error ?? 'Tap to enable location for live data.',
            ),
          ),
      ],
    );
  }
}

class _SunArcPainter extends CustomPainter {
  /// 0..1 progress along the daytime arc (left = sunrise, right = sunset).
  final double progress;
  _SunArcPainter({required this.progress});

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

    // Sun position along the bezier at t = progress.
    final t = progress.clamp(0.0, 1.0);
    final sunX = (1 - t) * (1 - t) * 20 +
        2 * (1 - t) * t * (w / 2) +
        t * t * (w - 20);
    final sunY = (1 - t) * (1 - t) * 130 +
        2 * (1 - t) * t * (-20) +
        t * t * 130;

    // Only show the sun when it's actually above the horizon.
    final visible = t > 0.01 && t < 0.99;

    if (visible) {
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
    }

    // Sunrise/sunset markers.
    canvas.drawCircle(const Offset(20, 130), 3, Paint()..color = TT.ember3);
    canvas.drawCircle(Offset(w - 20, 130), 3, Paint()..color = TT.blue);
  }

  @override
  bool shouldRepaint(_SunArcPainter old) => old.progress != progress;
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

/// Translucent overlay shown on top of a tool view when its sensor is
/// unavailable or permission is denied. Centred icon + title + subtitle on
/// a dim glassy backdrop.
class _ToolUnavailableOverlay extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ToolUnavailableOverlay({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: const Color(0xCC07090C),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: TT.surf,
                shape: BoxShape.circle,
                border: Border.all(color: TT.line2, width: 1),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 32, color: TT.text3),
            ),
            const SizedBox(height: 14),
            Text(title, style: TT.title(16), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TT.body(size: 12, color: TT.text3),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
