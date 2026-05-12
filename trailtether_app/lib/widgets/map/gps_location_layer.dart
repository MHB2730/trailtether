import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';

class GpsLocationLayer extends StatefulWidget {
  /// Pass the parent [MapController] to auto-pan the map when a new
  /// GPS position arrives (only pans once per session until user moves map).
  final MapController? mapCtrl;

  /// Called every time a new GPS fix is received.
  /// Used by [MapScreen] to keep [_lastGpsPos] up to date for the
  /// incident-reporter fallback position.
  final void Function(LatLng)? onPositionUpdate;

  const GpsLocationLayer({super.key, this.mapCtrl, this.onPositionUpdate});

  @override
  State<GpsLocationLayer> createState() => _GpsLocationLayerState();
}

class _GpsLocationLayerState extends State<GpsLocationLayer> {
  final List<LatLng> _breadcrumbs = [];
  LatLng? _current;
  bool _hasCentred = false;
  StreamSubscription<Position>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = LocationService.smoothedPositionStream.listen(
      _onPosition,
      onError: (e) => debugPrint('GPS error: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onPosition(Position pos) {
    final pt = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _current = pt;
      _breadcrumbs.add(pt);
    });
    // Notify parent of new position (used by MapScreen for incident reporting)
    widget.onPositionUpdate?.call(pt);
    // Pan map to first fix only
    if (!_hasCentred && widget.mapCtrl != null) {
      _hasCentred = true;
      widget.mapCtrl!.move(pt, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Breadcrumb trail
        if (_breadcrumbs.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points: _breadcrumbs,
              color: const Color(0xFF64B5F6),
              strokeWidth: 3.0,
            ),
          ]),
        // Current position dot
        if (_current != null)
          CircleLayer(circles: [
            CircleMarker(
              point: _current!,
              radius: 10,
              color: const Color(0x664FC3F7),
              borderColor: Colors.white,
              borderStrokeWidth: 2,
            ),
            CircleMarker(
              point: _current!,
              radius: 5,
              color: const Color(0xFF2196F3),
            ),
          ]),
      ],
    );
  }
}
