import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/cave_waypoint.dart';
import '../../providers/static_data_provider.dart';
import '../../screens/cave_detail_sheet.dart';

/// Renders a cave pin at the exact GPS location of every surveyed cave
/// from assets/data/caves.gpx (125 waypoints from two Garmin surveys).
class CaveMarkerLayer extends StatelessWidget {
  final void Function(CaveWaypoint)? onCaveTap;
  const CaveMarkerLayer({super.key, this.onCaveTap});

  static const _caveBrown = Color(0xFF795548);
  static const _shelterTeal = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StaticDataProvider>();
    final caves = data.caves;
    if (caves.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      // rotate: true keeps all markers upright (screen-aligned) even when the
      // user rotates the map, so labels never appear tilted.
      rotate: true,
      markers: caves.map((cave) {
        final color = cave.isShelter ? _shelterTeal : _caveBrown;
        return Marker(
          point: LatLng(cave.lat, cave.lon),
          width: 72,
          height: 56,
          child: GestureDetector(
            onTap: () => (onCaveTap != null)
                ? onCaveTap!(cave)
                : CaveDetailSheet.show(context, cave),
            child: _CavePinWithLabel(cave: cave, color: color),
          ),
        );
      }).toList(),
    );
  }
}

// ── Pin + label widget ───────────────────────────────────────────────────────

class _CavePinWithLabel extends StatelessWidget {
  final CaveWaypoint cave;
  final Color color;
  const _CavePinWithLabel({required this.cave, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.72),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.6), width: 0.8),
          ),
          child: Text(
            _shortName(cave.name),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        // ── Pin body ────────────────────────────────────────────
        SizedBox(
          width: 22,
          height: 28,
          child: CustomPaint(painter: _CavePinPainter(color: color)),
        ),
      ],
    );
  }

  /// Remove "Cave" / "Shelter" suffix to keep labels compact.
  String _shortName(String name) {
    return name
        .replaceAll(RegExp(r'\s+Cave\s*\d*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Caves$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Shelter$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Chalet$', caseSensitive: false), '')
        .trim();
  }
}

// ── Pin painter ──────────────────────────────────────────────────────────────

class _CavePinPainter extends CustomPainter {
  final Color color;
  const _CavePinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;

    // Shadow
    canvas.drawPath(
      _body(w, h, dy: 2),
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Body fill
    canvas.drawPath(_body(w, h), Paint()..color = color);

    // White inner circle
    canvas.drawCircle(
      Offset(r, r * 0.9),
      r * 0.55,
      Paint()..color = Colors.white.withOpacity(0.9),
    );

    // Stalactite icon in the circle
    final cx = r;
    final cy = r * 0.9;
    final sz = r * 0.38;
    final dark = Paint()..color = color;

    // Cave entrance shape (semi-circle/arch)
    final entrancePath = ui.Path()
      ..moveTo(cx - sz * 1.2, cy + sz * 0.4)
      ..quadraticBezierTo(cx, cy - sz * 1.8, cx + sz * 1.2, cy + sz * 0.4)
      ..close();

    canvas.drawPath(entrancePath, dark);

    // Cave floor line
    canvas.drawLine(
      Offset(cx - sz * 1.4, cy + sz * 0.1),
      Offset(cx + sz * 1.4, cy + sz * 0.1),
      Paint()
        ..color = color
        ..strokeWidth = 1.2,
    );
  }

  ui.Path _body(double w, double h, {double dy = 0}) {
    final r = w / 2;
    final path = ui.Path();
    // Circle
    path.addOval(Rect.fromCircle(center: Offset(r, r * 0.9 + dy), radius: r));
    // Teardrop tail
    path.moveTo(r - r * 0.38, r * 1.55 + dy);
    path.quadraticBezierTo(r, h + dy, r + r * 0.38, r * 1.55 + dy);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_CavePinPainter old) => old.color != color;
}
