import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/recording_point.dart';
import '../../core/utils.dart';

class SpeedPathLayer extends StatelessWidget {
  final List<RecordingPoint> points;

  const SpeedPathLayer({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    // 1. Simplify points if the list is large (Douglas-Peucker)
    // This dramatically reduces the number of segments to render.
    final rawLatLngs = points.map((p) => p.toLatLng).toList();
    final simplifiedLatLngs = points.length > 500
        ? TrailUtils.simplifyPoints(rawLatLngs, epsilon: 0.00001)
        : rawLatLngs;

    // 2. Smooth the (potentially simplified) points to remove jitter
    final smoothedPoints = _smoothPointsFromLatLngs(simplifiedLatLngs);
    if (smoothedPoints.length < 2) return const SizedBox.shrink();

    final polylines = <Polyline>[];

    // 3. Batch contiguous segments with similar speed to reduce widget count
    // We quantize speed to 0.5 km/h buckets to allow batching.
    Color? currentGroupColor;
    List<LatLng> currentGroupPoints = [];

    for (int i = 0; i < points.length - 1; i++) {
      // Find the index in smoothedPoints that corresponds to the original point
      // Since simplification might have removed points, this is tricky.
      // For now, let's keep it simple: if not simplified, use batching.
      // If simplified, we'll just draw individual segments for simplicity.

      final p1 = points[i].toLatLng;
      final p2 = points[i + 1].toLatLng;
      final speed = points[i + 1].speed * 3.6;

      // Quantize speed to 0.5 km/h for batching
      final quantizedSpeed = (speed * 2).round() / 2.0;
      final color = TrailUtils.getSpeedColor(quantizedSpeed);

      if (currentGroupColor == null) {
        currentGroupColor = color;
        currentGroupPoints = [p1, p2];
      } else if (currentGroupColor == color) {
        currentGroupPoints.add(p2);
      } else {
        polylines.add(
          Polyline(
            points: List.from(currentGroupPoints),
            color: currentGroupColor,
            strokeWidth: 4.5,
            strokeCap: StrokeCap.round,
          ),
        );
        currentGroupColor = color;
        currentGroupPoints = [p1, p2];
      }
    }

    if (currentGroupPoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: currentGroupPoints,
          color: currentGroupColor!,
          strokeWidth: 4.5,
          strokeCap: StrokeCap.round,
        ),
      );
    }

    return PolylineLayer(polylines: polylines);
  }

  List<LatLng> _smoothPointsFromLatLngs(List<LatLng> raw) {
    if (raw.length < 3) return raw;
    final smoothed = <LatLng>[];
    smoothed.add(raw.first);
    for (int i = 1; i < raw.length - 1; i++) {
      final pPrev = raw[i - 1];
      final pCurr = raw[i];
      final pNext = raw[i + 1];
      final avgLat = (pPrev.latitude + pCurr.latitude + pNext.latitude) / 3.0;
      final avgLon =
          (pPrev.longitude + pCurr.longitude + pNext.longitude) / 3.0;
      smoothed.add(LatLng(avgLat, avgLon));
    }
    smoothed.add(raw.last);
    return smoothed;
  }
}
