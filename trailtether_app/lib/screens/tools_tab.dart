import 'dart:math';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:torch_light/torch_light.dart';
import '../core/constants.dart';
import 'gpx_upload_screen.dart';
import 'hike_history_screen.dart';
import 'recorded_trails_screen.dart';
import 'package:provider/provider.dart';
import '../providers/static_data_provider.dart';
import '../services/logger_service.dart';
import '../tools/useful_info_tool.dart';
import '../tools/locations_tool.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Tools Tab  — Compass · Bubble Level · Flashlight · Altimeter · Sunrise/Sunset
// ══════════════════════════════════════════════════════════════════════════════

class ToolsTab extends StatefulWidget {
  const ToolsTab({super.key});
  @override
  State<ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<ToolsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _ctrl;

  static List<String> get _tools => [
        if (Platform.isAndroid) ...['Compass', 'Level', 'Torch', 'Altimeter'],
        'Sun',
        'Info',
        'Locations',
        'Activities',
        'Trails',
        'Tracks',
      ];

  @override
  void initState() {
    super.initState();
    _ctrl = TabController(length: _tools.length, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kColorOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.explore,
                        color: kColorOrange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('Hiking Tools',
                      style: GoogleFonts.outfit(
                          color: kColorCream,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Tool picker ──────────────────────────────────────────────
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _tools.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _ToolChip(
                  label: _tools[i],
                  icon: _toolIcon(i),
                  selected: _ctrl.index == i,
                  onTap: () => setState(() => _ctrl.animateTo(i)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _ctrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  if (Platform.isAndroid) ...[
                    const _CompassTool(),
                    const _BubbleLevelTool(),
                    const _FlashlightTool(),
                    const _AltimeterTool(),
                  ],
                  const _SunCalculatorTool(),
                  const UsefulInfoTool(),
                  const LocationsTool(),
                  const HikeHistoryScreen(embedded: true),
                  const RecordedTrailsScreen(embedded: true),
                  const _TracksTool(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _toolIcon(int i) {
    final tool = _tools[i];
    return switch (tool) {
      'Compass' => Icons.explore,
      'Level' => Icons.bubble_chart_outlined,
      'Torch' => Icons.flashlight_on_outlined,
      'Altimeter' => Icons.terrain,
      'Sun' => Icons.wb_sunny_outlined,
      'Info' => Icons.info_outline,
      'Locations' => Icons.hotel_outlined,
      'Activities' => Icons.query_stats_rounded,
      'Trails' => Icons.timeline,
      'Tracks' => Icons.route_outlined,
      _ => Icons.build,
    };
  }
}

class _ToolChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToolChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kColorOrange.withOpacity(0.18) : kColorPanel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? kColorOrange : kColorBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? kColorOrange : kColorCream.withOpacity(0.5),
                size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.outfit(
                    color:
                        selected ? kColorOrange : kColorCream.withOpacity(0.5),
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPASS TOOL
// ══════════════════════════════════════════════════════════════════════════════
class _CompassTool extends StatefulWidget {
  const _CompassTool();
  @override
  State<_CompassTool> createState() => _CompassToolState();
}

class _CompassToolState extends State<_CompassTool>
    with SingleTickerProviderStateMixin {
  double? _heading;
  bool _available = true;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: Duration.zero);
    _initCompass();
  }

  void _initCompass() {
    // flutter_compass has no Windows/macOS/Linux plugin implementation.
    // Guard here so we never try to subscribe and get MissingPluginException.
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
      events.listen(
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

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  String _toCardinal(double deg) {
    const dirs = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW'
    ];
    return dirs[((deg + 11.25) / 22.5).floor() % 16];
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const _UnavailableOverlay(
        icon: Icons.explore_off,
        title: 'Compass unavailable',
        subtitle:
            'This device does not have a magnetometer.\nUse a dedicated compass for navigation.',
      );
    }

    final heading = _heading ?? 0.0;
    final cardinal = _toCardinal(heading);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cardinal + degrees display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(cardinal,
                  style: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${heading.toStringAsFixed(1)}°',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.55),
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Magnetic heading',
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.35), fontSize: 12)),
          const SizedBox(height: 32),

          // Compass rose
          SizedBox(
            width: 270,
            height: 270,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: -heading * pi / 180),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (_, angle, __) => CustomPaint(
                painter: _CompassPainter(angle: angle),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Quadrant info cards
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoPill('TRUE NORTH',
                  '${(heading + 23.5).toStringAsFixed(1)}° (est)'),
              const SizedBox(width: 12),
              const _InfoPill('DECLINATION', '~23.5° E'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double angle; // rotation in radians (negative heading)
  const _CompassPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2;
    const pi = 3.14159265;

    // Background
    canvas.drawCircle(c, R, Paint()..color = const Color(0xFF111111));
    // Rim
    canvas.drawCircle(
        c,
        R,
        Paint()
          ..color = kColorOrange.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

    // Rotate canvas for the rose
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);

    // Degree tick marks
    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    for (int deg = 0; deg < 360; deg += 5) {
      final a = deg * pi / 180;
      final major = deg % 30 == 0;
      final card = deg % 90 == 0;
      final tLen = card
          ? 18.0
          : major
              ? 10.0
              : 5.0;
      tickPaint
        ..color = card
            ? kColorCream.withOpacity(0.9)
            : major
                ? kColorCream.withOpacity(0.45)
                : kColorCream.withOpacity(0.18)
        ..strokeWidth = card ? 2.0 : 1.0;
      final s = Offset(sin(a) * (R - tLen - 3), -cos(a) * (R - tLen - 3));
      final e = Offset(sin(a) * (R - 3), -cos(a) * (R - 3));
      canvas.drawLine(s, e, tickPaint);
    }

    // Cardinal letters
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final cardinals = {'N': 0, 'E': 90, 'S': 180, 'W': 270};
    for (final entry in cardinals.entries) {
      final a = entry.value * pi / 180;
      final p = Offset(sin(a) * (R - 35), -cos(a) * (R - 35));
      tp.text = TextSpan(
        text: entry.key,
        style: TextStyle(
          color: entry.key == 'N' ? kColorOrange : kColorCream,
          fontSize: entry.key == 'N' ? 22.0 : 16.0,
          fontWeight: FontWeight.w800,
        ),
      );
      tp.layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    canvas.restore();

    // Fixed needle (always points up = your heading direction)
    final northPath = Path()
      ..moveTo(c.dx, c.dy - R * 0.5)
      ..lineTo(c.dx - 7, c.dy + 4)
      ..lineTo(c.dx + 7, c.dy + 4)
      ..close();
    canvas.drawPath(
        northPath,
        Paint()
          ..color = kColorOrange
          ..style = PaintingStyle.fill);

    final southPath = Path()
      ..moveTo(c.dx, c.dy + R * 0.5)
      ..lineTo(c.dx - 7, c.dy - 4)
      ..lineTo(c.dx + 7, c.dy - 4)
      ..close();
    canvas.drawPath(
        southPath,
        Paint()
          ..color = kColorCream.withOpacity(0.25)
          ..style = PaintingStyle.fill);

    // Centre cap
    canvas.drawCircle(c, 10, Paint()..color = kColorBg);
    canvas.drawCircle(c, 7, Paint()..color = kColorOrange);
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.angle != angle;
}

// ══════════════════════════════════════════════════════════════════════════════
// BUBBLE LEVEL TOOL
// ══════════════════════════════════════════════════════════════════════════════
class _BubbleLevelTool extends StatefulWidget {
  const _BubbleLevelTool();
  @override
  State<_BubbleLevelTool> createState() => _BubbleLevelToolState();
}

class _BubbleLevelToolState extends State<_BubbleLevelTool> {
  double _x = 0, _y = 0;
  bool _available = true;
  StreamSubscription<AccelerometerEvent>? _sub;

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
            _x = e.x;
            _y = e.y;
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
    super.dispose();
  }

  Color get _levelColor {
    final tilt = sqrt(_x * _x + _y * _y) / 9.8;
    if (tilt < 0.03) return const Color(0xFF4CAF50);
    if (tilt < 0.10) return const Color(0xFFFFC107);
    return const Color(0xFFE53935);
  }

  String get _levelText {
    final tilt = sqrt(_x * _x + _y * _y) / 9.8;
    if (tilt < 0.03) return 'LEVEL ✓';
    final deg = (asin(tilt.clamp(0.0, 1.0)) * 180 / pi).toStringAsFixed(1);
    return '$deg° off level';
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const _UnavailableOverlay(
        icon: Icons.bubble_chart_outlined,
        title: 'Accelerometer unavailable',
        subtitle:
            'This tool requires a built-in accelerometer.\nAvailable on Android/iOS devices.',
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SLEEPING PAD / TENT LEVEL',
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.4),
                  fontSize: 11,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(_levelText,
              style: GoogleFonts.outfit(
                  color: _levelColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 32),

          // Bubble level circle
          SizedBox(
            width: 260,
            height: 260,
            child: CustomPaint(
              painter: _BubblePainter(x: _x, y: _y, color: _levelColor),
            ),
          ),
          const SizedBox(height: 24),
          Text('Place phone on the surface you want to level',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.35), fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoPill('X TILT', '${_x.toStringAsFixed(2)} m/s²'),
              const SizedBox(width: 12),
              _InfoPill('Y TILT', '${_y.toStringAsFixed(2)} m/s²'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final double x, y;
  final Color color;
  const _BubblePainter({required this.x, required this.y, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final R = size.width * 0.46;
    final bR = size.width * 0.085;

    // Outer ring
    canvas.drawCircle(c, R, Paint()..color = const Color(0xFF111111));
    canvas.drawCircle(
        c,
        R,
        Paint()
          ..color = color.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Grid cross
    final gridPaint = Paint()
      ..color = kColorCream.withOpacity(0.08)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(c.dx, c.dy - R + 4), Offset(c.dx, c.dy + R - 4), gridPaint);
    canvas.drawLine(
        Offset(c.dx - R + 4, c.dy), Offset(c.dx + R - 4, c.dy), gridPaint);

    // Inner target circle
    canvas.drawCircle(
        c,
        R * 0.18,
        Paint()
          ..color = color.withOpacity(0.12)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        c,
        R * 0.18,
        Paint()
          ..color = color.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // Degree rings
    for (final r in [0.4, 0.7, 1.0]) {
      canvas.drawCircle(
          c,
          R * r,
          Paint()
            ..color = kColorCream.withOpacity(0.06)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }

    // Bubble position
    final nx = (-x / 9.8).clamp(-0.85, 0.85);
    final ny = (y / 9.8).clamp(-0.85, 0.85);
    final mag = sqrt(nx * nx + ny * ny);
    final scale = mag > 0.85 ? 0.85 / mag : 1.0;
    final bx = c.dx + nx * scale * (R - bR - 2);
    final by = c.dy + ny * scale * (R - bR - 2);
    final bp = Offset(bx, by);

    // Bubble shadow
    canvas.drawCircle(
        bp + const Offset(2, 2),
        bR,
        Paint()
          ..color = Colors.black.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Bubble fill
    canvas.drawCircle(
        bp,
        bR,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withOpacity(0.75),
            color.withOpacity(0.9),
          ]).createShader(Rect.fromCircle(center: bp, radius: bR)));

    // Bubble highlight
    canvas.drawCircle(bp - Offset(bR * 0.3, bR * 0.3), bR * 0.25,
        Paint()..color = Colors.white.withOpacity(0.35));
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.x != x || old.y != y || old.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// FLASHLIGHT TOOL
// ══════════════════════════════════════════════════════════════════════════════
class _FlashlightTool extends StatefulWidget {
  const _FlashlightTool();
  @override
  State<_FlashlightTool> createState() => _FlashlightToolState();
}

class _FlashlightToolState extends State<_FlashlightTool>
    with TickerProviderStateMixin {
  bool _on = false;
  bool _available = true;
  bool _sosActive = false;
  late AnimationController _glow;
  late AnimationController _sosCtrl;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _sosCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    try {
      final ok = await _isTorchAvailable();
      if (mounted) setState(() => _available = ok);
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  Future<bool> _isTorchAvailable() async {
    try {
      return await TorchLight.isTorchAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<void> _setTorch(bool on) async {
    try {
      if (on) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
    } catch (e, stack) {
      LoggerService.error('TORCH', 'Failed to toggle torch: $e', stack);
    }
  }

  Future<void> _toggleTorch() async {
    if (!_available) return;
    final next = !_on;
    await _setTorch(next);
    setState(() {
      _on = next;
      _sosActive = false;
    });
  }

  Future<void> _sendSos() async {
    if (!_available || _sosActive) return;
    setState(() {
      _sosActive = true;
      _on = false;
    });

    // SOS: ... --- ...
    // timing: unit = 200ms
    // dot = 1 unit, dash = 3 units, internal gap = 1 unit, letter gap = 3 units
    final sequence = [
      // S: . . .
      true, 200, false, 200, true, 200, false, 200, true, 200,
      false, 600, // Letter gap
      // O: - - -
      true, 600, false, 200, true, 600, false, 200, true, 600,
      false, 600, // Letter gap
      // S: . . .
      true, 200, false, 200, true, 200, false, 200, true, 200,
      false, 1400, // Word gap (loop wait)
    ];

    while (_sosActive && mounted) {
      for (int i = 0; i < sequence.length; i += 2) {
        if (!mounted || !_sosActive) break;

        final state = sequence[i] as bool;
        final ms = sequence[i + 1] as int;

        await _setTorch(state);
        if (mounted) setState(() => _on = state);
        await Future.delayed(Duration(milliseconds: ms));
      }
    }

    if (mounted) {
      await _setTorch(false);
      setState(() {
        _on = false;
        _sosActive = false;
      });
    }
  }

  @override
  void dispose() {
    _setTorch(false);
    _glow.dispose();
    _sosCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main torch button
          GestureDetector(
            onTap: _available ? _toggleTorch : null,
            child: AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _on ? const Color(0xFFFFF9C4) : kColorPanel,
                  border: Border.all(
                      color: _on ? const Color(0xFFFFF176) : kColorBorder,
                      width: _on ? 2.5 : 1),
                  boxShadow: _on
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFF176)
                                .withOpacity(0.3 + _glow.value * 0.4),
                            blurRadius: 40 + _glow.value * 30,
                            spreadRadius: 10 + _glow.value * 15,
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  _on ? Icons.flashlight_on : Icons.flashlight_off,
                  color: _on
                      ? const Color(0xFFFF6F00)
                      : kColorCream.withOpacity(0.35),
                  size: 64,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            !_available
                ? 'No torch on this device'
                : _sosActive
                    ? 'SENDING SOS...'
                    : _on
                        ? 'TAP TO TURN OFF'
                        : 'TAP TO TURN ON',
            style: GoogleFonts.outfit(
              color: !_available
                  ? kColorCream.withOpacity(0.3)
                  : _sosActive
                      ? Colors.redAccent
                      : _on
                          ? const Color(0xFFFFF176)
                          : kColorCream.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 32),

          // SOS button
          GestureDetector(
            onTap: _available && !_sosActive ? _sendSos : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent
                    .withOpacity((_available && !_sosActive) ? 0.15 : 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.redAccent
                        .withOpacity((_available && !_sosActive) ? 0.5 : 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sos, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Text('SOS FLASHLIGHT',
                      style: GoogleFonts.outfit(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Flashes SOS in Morse code (3 short, 3 long, 3 short)',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.3), fontSize: 11)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ALTIMETER / GPS  TOOL
// ══════════════════════════════════════════════════════════════════════════════
class _AltimeterTool extends StatefulWidget {
  const _AltimeterTool();
  @override
  State<_AltimeterTool> createState() => _AltimeterToolState();
}

class _AltimeterToolState extends State<_AltimeterTool> {
  Position? _pos;
  bool _loading = false;
  String? _error;

  Future<void> _getPosition() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await Geolocator.requestPermission();
      if (ok == LocationPermission.denied ||
          ok == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied';
          _loading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.best));
      setState(() {
        _pos = pos;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Altitude gauge
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _AltimeterPainter(
                altitude: _pos?.altitude ?? 0,
                maxAlt: 3500,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _pos == null ? '-- m' : '${_pos!.altitude.toStringAsFixed(0)} m',
            style: GoogleFonts.outfit(
                color: kColorOrange, fontSize: 42, fontWeight: FontWeight.w900),
          ),
          Text('Altitude above sea level',
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.35), fontSize: 12)),
          if (_pos != null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _InfoPill('LAT', _pos!.latitude.toStringAsFixed(5)),
                const SizedBox(width: 12),
                _InfoPill('LON', _pos!.longitude.toStringAsFixed(5)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _InfoPill(
                    'ACCURACY', '±${_pos!.accuracy.toStringAsFixed(0)} m'),
                const SizedBox(width: 12),
                _InfoPill(
                    'SPEED', '${(_pos!.speed * 3.6).toStringAsFixed(1)} km/h'),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style:
                    GoogleFonts.outfit(color: Colors.redAccent, fontSize: 12)),
          ],
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _loading ? null : _getPosition,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                color: kColorOrange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kColorOrange.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loading)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: kColorOrange, strokeWidth: 2))
                  else
                    const Icon(Icons.gps_fixed, color: kColorOrange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                      _loading
                          ? 'Acquiring GPS…'
                          : _pos == null
                              ? 'Get GPS Fix'
                              : 'Refresh',
                      style: GoogleFonts.outfit(
                          color: kColorOrange, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AltimeterPainter extends CustomPainter {
  final double altitude, maxAlt;
  const _AltimeterPainter({required this.altitude, required this.maxAlt});

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final R = s.width / 2;
    final progress = (altitude / maxAlt).clamp(0.0, 1.0);
    const startAngle = 2.35619; // 135°
    const sweepMax = 4.71239; // 270°

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: R * 0.82),
      startAngle,
      sweepMax,
      false,
      Paint()
        ..color = kColorBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc (gradient)
    if (altitude > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: R * 0.82),
        startAngle,
        sweepMax * progress,
        false,
        Paint()
          ..color = kColorOrange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round,
      );
    }

    // Tick marks at 500m intervals
    for (int m = 0; m <= maxAlt.toInt(); m += 500) {
      final a = startAngle + sweepMax * (m / maxAlt);
      final inner = R * 0.62;
      final outer = R * 0.72;
      final tp = TextPainter(textDirection: TextDirection.ltr);
      tp.text = TextSpan(
        text: '${m}m',
        style: TextStyle(color: kColorCream.withOpacity(0.3), fontSize: 9),
      );
      tp.layout();
      final lp = Offset(
        c.dx + cos(a) * (inner - 14) - tp.width / 2,
        c.dy + sin(a) * (inner - 14) - tp.height / 2,
      );
      tp.paint(canvas, lp);

      canvas.drawLine(
        Offset(c.dx + cos(a) * inner, c.dy + sin(a) * inner),
        Offset(c.dx + cos(a) * outer, c.dy + sin(a) * outer),
        Paint()
          ..color = kColorCream.withOpacity(0.25)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_AltimeterPainter o) => o.altitude != altitude;
}

// ══════════════════════════════════════════════════════════════════════════════
// SUNRISE / SUNSET TOOL
// ══════════════════════════════════════════════════════════════════════════════
class _SunCalculatorTool extends StatefulWidget {
  const _SunCalculatorTool();
  @override
  State<_SunCalculatorTool> createState() => _SunCalculatorToolState();
}

class _SunCalculatorToolState extends State<_SunCalculatorTool> {
  double _lat = 0.0, _lon = 0.0;
  bool _locating = false;
  DateTime _date = DateTime.now();

  Map<String, DateTime?> get _sun => _calculateSun(_lat, _lon, _date);

  Map<String, DateTime?> _calculateSun(double lat, double lon, DateTime date) {
    const pi = 3.14159265;
    final day = date.difference(DateTime(date.year)).inDays + 1;
    final gamma = 2 * pi / 365 * (day - 1 + (12 - 12) / 24);

    final eqtime = 229.18 *
        (0.000075 +
            0.001868 * cos(gamma) -
            0.032077 * sin(gamma) -
            0.014615 * cos(2 * gamma) -
            0.04089 * sin(2 * gamma));

    final decl = 0.006918 -
        0.399912 * cos(gamma) +
        0.070257 * sin(gamma) -
        0.006758 * cos(2 * gamma) +
        0.000907 * sin(2 * gamma) -
        0.002697 * cos(3 * gamma) +
        0.00148 * sin(3 * gamma);

    final latR = lat * pi / 180;
    final cosHa = cos(90.833 * pi / 180) / (cos(latR) * cos(decl)) -
        tan(latR) * tan(decl);

    if (cosHa.abs() > 1) return {'sunrise': null, 'sunset': null}; // polar

    final ha = acos(cosHa);
    final haD = ha * 180 / pi;

    final sunriseMin = 720 - 4 * (lon + haD) - eqtime;
    final sunsetMin = 720 - 4 * (lon - haD) - eqtime;

    final tzOffset = (_lon / 15).round().clamp(-12, 14);
    final srMin = sunriseMin + tzOffset * 60;
    final ssMin = sunsetMin + tzOffset * 60;

    final base = DateTime(date.year, date.month, date.day);
    final sunrise = base.add(Duration(minutes: srMin.round()));
    final sunset = base.add(Duration(minutes: ssMin.round()));
    final dayLen = ssMin - srMin;

    return {
      'sunrise': sunrise,
      'sunset': sunset,
      'dayLen': DateTime(1970, 1, 1, 0, dayLen.round())
    };
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _dayLen() {
    final sr = _sun['sunrise'];
    final ss = _sun['sunset'];
    if (sr == null || ss == null) return '--';
    final mins = ss.difference(sr).inMinutes;
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  double get _sunProgress {
    final sr = _sun['sunrise'];
    final ss = _sun['sunset'];
    if (sr == null || ss == null) return 0;
    final now = DateTime.now();
    if (now.isBefore(sr)) return 0;
    if (now.isAfter(ss)) return 1;
    return now.difference(sr).inMinutes / ss.difference(sr).inMinutes;
  }

  String get _utcOffsetLabel {
    final offset = (_lon / 15).round().clamp(-12, 14);
    if (offset == 0) return 'UTC';
    return 'UTC${offset > 0 ? '+' : ''}$offset';
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Location services are off.');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sr = _sun['sunrise'];
    final ss = _sun['sunset'];
    final now = DateTime.now();
    final isDaytime =
        sr != null && ss != null && now.isAfter(sr) && now.isBefore(ss);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('TRAIL SUN TIMES',
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.4),
                  fontSize: 11,
                  letterSpacing: 1.2)),
          const SizedBox(height: 20),

          // Sun arc
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter:
                  _SunArcPainter(progress: _sunProgress, isDaytime: isDaytime),
              size: Size(MediaQuery.of(context).size.width - 48, 140),
            ),
          ),
          const SizedBox(height: 24),

          // Times row
          Row(
            children: [
              Expanded(
                  child: _SunCard(
                icon: Icons.wb_twilight,
                label: 'SUNRISE',
                time: _fmt(sr),
                color: const Color(0xFFFFA726),
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _SunCard(
                icon: Icons.nightlight_round,
                label: 'SUNSET',
                time: _fmt(ss),
                color: const Color(0xFF7E57C2),
              )),
            ],
          ),
          const SizedBox(height: 16),

          // Daylight length
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kColorPanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kColorBorder),
            ),
            child: Column(
              children: [
                Text('DAYLIGHT',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.4),
                        fontSize: 10,
                        letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(_dayLen(),
                    style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  isDaytime
                      ? '☀️  Currently daytime at this location'
                      : now.isBefore(sr ?? DateTime(2000))
                          ? '🌙  Sunrise in ${sr!.difference(now).inHours}h ${sr.difference(now).inMinutes % 60}m'
                          : '🌑  After sunset — plan for reduced visibility',
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.55), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Date picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2024),
                lastDate: DateTime(DateTime.now().year + 3),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.dark(
                        primary: kColorOrange,
                        surface: kColorPanel,
                        onSurface: kColorCream),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kColorPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kColorBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: kColorOrange, size: 16),
                  const SizedBox(width: 10),
                  Text('${_date.day}/${_date.month}/${_date.year}',
                      style: GoogleFonts.outfit(color: kColorCream)),
                  const Spacer(),
                  Text('Change date',
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.4), fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 16),
              label: Text(
                _locating ? 'Locating...' : 'Use current location',
                style: GoogleFonts.outfit(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kColorCream,
                side: const BorderSide(color: kColorBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
              'Times calculated for ${_lat.toStringAsFixed(2)}, ${_lon.toStringAsFixed(2)} · $_utcOffsetLabel',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.25), fontSize: 10)),
        ],
      ),
    );
  }
}

class _SunArcPainter extends CustomPainter {
  final double progress;
  final bool isDaytime;
  const _SunArcPainter({required this.progress, required this.isDaytime});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height);
    // Cap R so the arc peak never escapes the canvas on wide (desktop) screens.
    // On narrow mobile screens the width constraint still governs.
    final R = min(size.height * 0.90, size.width * 0.46);
    const pi = 3.14159265;

    // Horizon line
    canvas.drawLine(
      Offset(c.dx - R * 1.2, c.dy),
      Offset(c.dx + R * 1.2, c.dy),
      Paint()
        ..color = kColorBorder
        ..strokeWidth = 1,
    );

    // Arc track
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: R),
      pi,
      pi,
      false,
      Paint()
        ..color = kColorCream.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Filled progress arc
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: R),
      pi,
      pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = const Color(0xFFFFA726).withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Sunrise marker
    const srAngle = pi;
    canvas.drawCircle(
      Offset(c.dx + cos(srAngle) * R, c.dy + sin(srAngle) * R),
      5,
      Paint()..color = const Color(0xFFFFA726),
    );
    // Sunset marker
    const ssAngle = 0.0;
    canvas.drawCircle(
      Offset(c.dx + cos(ssAngle) * R, c.dy + sin(ssAngle) * R),
      5,
      Paint()..color = const Color(0xFF7E57C2),
    );

    if (progress > 0 && progress < 1) {
      // Sun position dot
      final a = pi + pi * progress;
      final sx = c.dx + cos(a) * R;
      final sy = c.dy + sin(a) * R;
      // Glow
      canvas.drawCircle(
        Offset(sx, sy),
        14,
        Paint()
          ..color = const Color(0xFFFFF176).withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
          Offset(sx, sy), 10, Paint()..color = const Color(0xFFFFF176));
      canvas.drawCircle(
          Offset(sx, sy), 6, Paint()..color = const Color(0xFFFFA726));
    }
  }

  @override
  bool shouldRepaint(_SunArcPainter o) => o.progress != progress;
}

class _SunCard extends StatelessWidget {
  final IconData icon;
  final String label, time;
  final Color color;
  const _SunCard(
      {required this.icon,
      required this.label,
      required this.time,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.4),
                    fontSize: 10,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(time,
                style: GoogleFonts.outfit(
                    color: kColorCream,
                    fontSize: 26,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  final String label, value;
  const _InfoPill(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.35),
                    fontSize: 9,
                    letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.outfit(
                    color: kColorCream,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// TRACKS / GPX TOOL
// ══════════════════════════════════════════════════════════════════════════════
class _TracksTool extends StatelessWidget {
  const _TracksTool();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kColorPanel,
              shape: BoxShape.circle,
              border: Border.all(color: kColorOrange.withOpacity(0.2)),
            ),
            child:
                const Icon(Icons.route_outlined, color: kColorOrange, size: 48),
          ),
          const SizedBox(height: 24),
          Text('GPX TRACK MANAGER',
              style: GoogleFonts.outfit(
                  color: kColorCream,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Upload and manage your personal GPX tracks to overlay them on the 3D map.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.4),
                  fontSize: 13,
                  height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GpxUploadScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: Text('Manage Tracks',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kColorOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableOverlay extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _UnavailableOverlay({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: kColorPanel,
                  shape: BoxShape.circle,
                  border: Border.all(color: kColorBorder),
                ),
                child:
                    Icon(icon, color: kColorCream.withOpacity(0.25), size: 36),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.6),
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.35),
                      fontSize: 13,
                      height: 1.5)),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// DEBUG LOGS TOOL
// ══════════════════════════════════════════════════════════════════════════════
class _LogsTool extends StatefulWidget {
  const _LogsTool();
  @override
  State<_LogsTool> createState() => _LogsToolState();
}

class _LogsToolState extends State<_LogsTool> {
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _logs = LoggerService.memoryLogs.reversed.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final staticData = context.watch<StaticDataProvider>();
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // ── Stats Summary ────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kColorPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kColorBorder),
            ),
            child: Column(
              children: [
                const _DataRow(
                    label: 'Database Connection', value: 'ACTIVE (Supabase)'),
                const Divider(color: kColorBorder, height: 20),
                _DataRow(
                    label: 'Trails Loaded',
                    value: '${staticData.allTrails.length}'),
                const Divider(color: kColorBorder, height: 20),
                _DataRow(
                    label: 'Caves Loaded', value: '${staticData.caves.length}'),
                const Divider(color: kColorBorder, height: 20),
                _DataRow(
                    label: 'Lodging Loaded',
                    value: '${staticData.accommodations.length}'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Header for Logs ──────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live Debug Output',
                  style: GoogleFonts.outfit(
                      color: kColorCream,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.refresh, color: kColorOrange, size: 20),
                onPressed: _refresh,
              ),
            ],
          ),

          // ── Logs List ──────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kColorBorder),
              ),
              child: _logs.isEmpty
                  ? Center(
                      child: Text('No logs captured yet.',
                          style: GoogleFonts.outfit(color: Colors.white24)))
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (_, i) {
                        final log = _logs[i];
                        final isError = log.contains('[ERROR]');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            log,
                            style: GoogleFonts.firaCode(
                              color: isError
                                  ? Colors.redAccent
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // ── Action Buttons ──────────────
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => LoggerService.shareLogs(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: kColorOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.share,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('EXPORT LOGS',
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  await LoggerService.clearLogs();
                  _refresh();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Log history cleared')),
                    );
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: kColorPanel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kColorBorder),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label, value;
  const _DataRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.4), fontSize: 13)),
        Text(value,
            style: GoogleFonts.outfit(
                color: kColorOrange,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
