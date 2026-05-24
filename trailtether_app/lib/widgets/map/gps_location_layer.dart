import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/recording_provider.dart';

class GpsLocationLayer extends StatefulWidget {
  /// Parent [MapController] to auto-pan the map when the first live position
  /// arrives (only once per session until the user moves the map).
  final MapController? mapCtrl;

  /// Called every time the live position changes. Used by [MapScreen] to keep
  /// `_lastGpsPos` up to date for the incident-reporter fallback position.
  final void Function(LatLng)? onPositionUpdate;

  const GpsLocationLayer({super.key, this.mapCtrl, this.onPositionUpdate});

  @override
  State<GpsLocationLayer> createState() => _GpsLocationLayerState();
}

class _GpsLocationLayerState extends State<GpsLocationLayer> {
  final List<LatLng> _breadcrumbs = [];
  LatLng? _lastReported;
  bool _hasCentred = false;

  void _onLivePosition(LatLng pt) {
    if (_lastReported == pt) return;
    _lastReported = pt;
    _breadcrumbs.add(pt);
    widget.onPositionUpdate?.call(pt);
    if (!_hasCentred && widget.mapCtrl != null) {
      _hasCentred = true;
      widget.mapCtrl!.move(pt, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.select<RecordingProvider, LatLng?>((r) {
      final p = r.currentPosition;
      if (p == null) return null;
      return LatLng(p.latitude, p.longitude);
    });

    if (pos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onLivePosition(pos);
      });
    }

    return Stack(
      children: [
        if (_breadcrumbs.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points: _breadcrumbs,
              color: const Color(0xFF64B5F6),
              strokeWidth: 3.0,
            ),
          ]),
        if (pos != null)
          CircleLayer(circles: [
            CircleMarker(
              point: pos,
              radius: 10,
              color: const Color(0x664FC3F7),
              borderColor: Colors.white,
              borderStrokeWidth: 2,
            ),
            CircleMarker(
              point: pos,
              radius: 5,
              color: const Color(0xFF2196F3),
            ),
          ]),
      ],
    );
  }
}
