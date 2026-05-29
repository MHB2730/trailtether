import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/incident.dart';
import '../../providers/safety_provider.dart';

/// Renders all incident markers on the 2-D flutter_map.
/// Tap a marker → [onIncidentTap] is called with the incident.
class IncidentMarkerLayer extends StatelessWidget {
  final void Function(Incident) onIncidentTap;

  const IncidentMarkerLayer({super.key, required this.onIncidentTap});

  @override
  Widget build(BuildContext context) {
    final safety = context.watch<SafetyProvider>();
    final incidents = safety.incidents;
    if (incidents.isEmpty) return const SizedBox.shrink();

    final markers = incidents.map((inc) {
      return Marker(
        point: LatLng(inc.lat, inc.lon),
        width: 36,
        height: 44,
        child: GestureDetector(
          onTap: () => onIncidentTap(inc),
          child: _IncidentPin(incident: inc),
        ),
      );
    }).toList();

    // rotate: true keeps markers upright when map is rotated by the user.
    return MarkerLayer(rotate: true, markers: markers);
  }
}

class _IncidentPin extends StatelessWidget {
  final Incident incident;
  const _IncidentPin({required this.incident});

  @override
  Widget build(BuildContext context) {
    final color = incident.type.color;
    final hasTitle =
        incident.trailName != null && incident.trailName!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasTitle)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.5), width: 0.5),
            ),
            child: Text(
              incident.trailName!.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        const SizedBox(height: 2),
        // Pin head
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  incident.type.emoji,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (incident.verifiedUids.isNotEmpty)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Color(0xFF4CAF50),
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Pin tail
        CustomPaint(
          size: const Size(10, 7),
          painter: _PinTailPainter(color: color),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}
