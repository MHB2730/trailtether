import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/trail.dart';
import '../../core/constants.dart';

/// A stable, dot-based layer for rendering trail paths.
/// This bypasses potential production build issues with the generic PolylineLayer.
class TrailMarkerLayer extends StatelessWidget {
  final List<Trail> trails;
  final String? selectedTrailId;

  const TrailMarkerLayer({
    super.key,
    required this.trails,
    this.selectedTrailId,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    for (final trail in trails) {
      final isSelected = trail.id == selectedTrailId;
      final color = (trail.isCave ? const Color(0xFF8D6E63) : kColorOrange);
      final opacity = isSelected ? 1.0 : 0.4;

      // For performance, we only render a subset of points as dots
      // unless the trail is selected.
      final step = isSelected ? 2 : 10;

      for (int i = 0; i < trail.coords.length; i += step) {
        final c = trail.coords[i];
        markers.add(
          Marker(
            point: LatLng(c.lat, c.lon),
            width: isSelected ? 4 : 3,
            height: isSelected ? 4 : 3,
            child: Container(
              decoration: BoxDecoration(
                color: color.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }
    }

    return MarkerLayer(
      markers: markers,
      rotate: true,
    );
  }
}
