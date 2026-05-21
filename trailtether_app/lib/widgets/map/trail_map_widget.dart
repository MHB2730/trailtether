import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/cave_waypoint.dart';
import '../../models/incident.dart';
import '../../models/trail.dart';
import '../../models/gpx_track.dart';
import '../../providers/static_data_provider.dart';
import '../../providers/gpx_provider.dart';
import '../../providers/recording_provider.dart';
import '../../services/offline_map_service.dart';
import 'cave_marker_layer.dart';
import 'gps_location_layer.dart';
import 'incident_marker_layer.dart';
import 'accommodation_marker_layer.dart';
import '../../providers/routing_provider.dart';
import 'trail_marker_layer.dart';
import 'speed_path_layer.dart';

class TrailMapWidget extends StatefulWidget {
  final MapController controller;
  final void Function(Trail trail) onTrailTap;
  final bool gpsActive;
  final int tileStyleIndex;
  final bool incidentMode;
  final void Function(LatLng)? onMapTapForIncident;
  final void Function(Incident)? onIncidentTap;
  final void Function(LatLng)? onPositionUpdate;
  final bool showCaves;
  final bool measureMode;
  final void Function(LatLng)? onMeasureTap;
  final List<LatLng> measurePoints;
  final bool showIncidents;
  final bool routingMode;
  final void Function(LatLng)? onRoutingTap;
  final List<Marker>? extraMarkers;
  final void Function(UserGpxTrack track)? onGpxTap;
  final void Function(LatLng)? onMapTap;
  final String? selectedTrailId;
  final void Function(CaveWaypoint)? onCaveTap;
  final List<Widget>? children;

  const TrailMapWidget({
    super.key,
    required this.controller,
    required this.onTrailTap,
    this.onGpxTap,
    this.gpsActive = false,
    this.tileStyleIndex = 0,
    this.incidentMode = false,
    this.onMapTapForIncident,
    this.onIncidentTap,
    this.onPositionUpdate,
    this.showCaves = true,
    this.measureMode = false,
    this.onMeasureTap,
    this.measurePoints = const [],
    this.showIncidents = true,
    this.routingMode = false,
    this.onRoutingTap,
    this.extraMarkers,
    this.onMapTap,
    this.selectedTrailId,
    this.onCaveTap,
    this.children,
  });

  @override
  State<TrailMapWidget> createState() => _TrailMapWidgetState();
}

class _TrailMapWidgetState extends State<TrailMapWidget> {
  CameraFit? _cachedInitialFit;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StaticDataProvider>();
    final gpxProv = context.watch<GpxProvider>();
    final routingProv = context.watch<RoutingProvider>();
    final trailProv = data;
    // No longer using nightMap state
    final profileCursor = trailProv.profileCursor;
    // Initial camera fit is only consumed by MapOptions on the first build,
    // so memoize: a 100k-point sweep on every rebuild is wasted work.
    _cachedInitialFit ??= _initialCameraFit(trailProv, gpxProv);
    final initialFit = _cachedInitialFit;

    final trailPolylines = <Polyline>[];
    for (final trail in trailProv.allTrails) {
      final isSelected = trailProv.selectedTrail?.id == trail.id;
      final baseColor = (trail.isCave ? const Color(0xFF8D6E63) : kColorOrange);
      final glowColor = baseColor.withOpacity(isSelected ? 0.3 : 0.15);
      final points = trail.coords.map((c) => LatLng(c.lat, c.lon)).toList();

      // Glow Layer
      trailPolylines.add(Polyline(
        points: points,
        color: glowColor,
        strokeWidth: isSelected ? 12.0 : 8.0,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));

      // Core Layer
      trailPolylines.add(Polyline(
        points: points,
        color: isSelected ? baseColor : baseColor.withOpacity(0.7),
        strokeWidth: isSelected ? 3.5 : (trail.isCave ? 2.0 : 1.8),
        pattern: (trail.isCave && !isSelected)
            ? const StrokePattern.dotted()
            : const StrokePattern.solid(),
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));
    }

    final gpxPolylines = <Polyline>[];
    for (final t in gpxProv.tracks) {
      final isSelected = widget.selectedTrailId == t.id;
      final color = t.color;

      // Glow Layer
      gpxPolylines.add(Polyline(
        points: t.points,
        color: color.withOpacity(isSelected ? 0.4 : 0.2),
        strokeWidth: isSelected ? 14.0 : 10.0,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));

      // Core Layer
      gpxPolylines.add(Polyline(
        points: t.points,
        color: isSelected ? color : color.withOpacity(0.8),
        strokeWidth: isSelected ? 4.0 : 2.5,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));
    }

    final style = kMapTileStyles[widget.tileStyleIndex];
    final tileLayer = TileLayer(
      key: ValueKey('${widget.tileStyleIndex}'),
      urlTemplate: style.url,
      tileProvider: OfflineMapService.tileProvider(),
      userAgentPackageName: 'com.trailtether.app',
      maxZoom: style.maxZoom,
    );

    final recordingProv = context.watch<RecordingProvider>();

    final routingPolylines = routingProv.calculatedPath.map((edge) {
      return Polyline(
        points: edge.coordinates.map((c) => LatLng(c[1], c[0])).toList(),
        color: kColorOrange,
        strokeWidth: 5.0,
        strokeCap: StrokeCap.round,
      );
    }).toList();

    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: LatLng(kWorldMapCenter.lat, kWorldMapCenter.lon),
        initialZoom: kWorldMapZoomInit,
        initialCameraFit: initialFit,
        minZoom: 2,
        maxZoom: 20, // Increased max zoom

        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
          enableMultiFingerGestureRace: true,
          rotationThreshold: 5.0,
          pinchZoomThreshold: 0.3,
          scrollWheelVelocity: 0.01,
        ),
        onTap: _onMapTap,
      ),
      children: [
        tileLayer,
        PolylineLayer(
          polylines: [
            ...trailPolylines,
            ...gpxPolylines,
            ...routingPolylines,
          ],
        ),
        // Active recording with speed-based colors
        SpeedPathLayer(points: recordingProv.points),

        // Stable fallback dot-based rendering
        TrailMarkerLayer(
          trails: trailProv.allTrails,
          selectedTrailId: trailProv.selectedTrail?.id,
        ),
        if (widget.showCaves)
          CaveMarkerLayer(
            // Pass through nullable so CaveMarkerLayer's built-in fallback
            // (open CaveDetailSheet) fires when the screen doesn't supply
            // its own handler. The previous `?? (_) {}` no-op swallowed all
            // cave taps on the 2D map, since map_screen doesn't forward one.
            onCaveTap: widget.onCaveTap,
          ),

        const AccommodationMarkerLayer(),
        if (widget.gpsActive)
          GpsLocationLayer(
            mapCtrl: widget.controller,
            onPositionUpdate: widget.onPositionUpdate,
          ),
        if (widget.showIncidents)
          IncidentMarkerLayer(
            onIncidentTap: widget.onIncidentTap ?? (_) {},
          ),
        if (widget.measurePoints.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points: widget.measurePoints,
              color: const Color(0xFF00E5FF),
              strokeWidth: 2.5,
              pattern: StrokePattern.dashed(segments: const [12, 6]),
            ),
          ]),
        if (widget.measurePoints.isNotEmpty)
          MarkerLayer(
            rotate: true,
            markers: widget.measurePoints.asMap().entries.map((e) {
              final isFirst = e.key == 0;
              final isLast = e.key == widget.measurePoints.length - 1;
              return Marker(
                point: e.value,
                width: isFirst || isLast ? 16 : 10,
                height: isFirst || isLast ? 16 : 10,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst
                        ? const Color(0xFF4CAF50)
                        : isLast
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFF00E5FF).withOpacity(0.7),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              );
            }).toList(),
          ),
        if (routingProv.waypoints.isNotEmpty)
          MarkerLayer(
            markers: routingProv.waypoints.map((node) {
              return Marker(
                point: LatLng(node.lat, node.lng),
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: kColorOrange, width: 3),
                  ),
                ),
              );
            }).toList(),
          ),
        if (profileCursor != null)
          MarkerLayer(
            rotate: true,
            markers: [
              Marker(
                point: LatLng(profileCursor.lat, profileCursor.lon),
                width: 44,
                height: 44,
                child: const _ProfileCursorMarker(),
              ),
            ],
          ),
        if (widget.extraMarkers != null && widget.extraMarkers!.isNotEmpty)
          MarkerLayer(markers: widget.extraMarkers!),
        if (widget.children != null) ...widget.children!,
      ],
    );
  }

  /// Compute the bounding box once from cached per-track bounds — never
  /// re-iterate every coordinate on a map rebuild.
  CameraFit? _initialCameraFit(
      StaticDataProvider trailProv, GpxProvider gpxProv) {
    double? minLat, maxLat, minLon, maxLon;

    void widen(double lat, double lon) {
      if (lat.isNaN || lon.isNaN) return;
      minLat = (minLat == null) ? lat : math.min(minLat!, lat);
      maxLat = (maxLat == null) ? lat : math.max(maxLat!, lat);
      minLon = (minLon == null) ? lon : math.min(minLon!, lon);
      maxLon = (maxLon == null) ? lon : math.max(maxLon!, lon);
    }

    for (final t in trailProv.allTrails) {
      if (t.coords.isEmpty) continue;
      widen(t.minLat, t.minLon);
      widen(t.maxLat, t.maxLon);
    }
    for (final t in gpxProv.tracks) {
      if (t.points.isEmpty) continue;
      widen(t.minLat, t.minLon);
      widen(t.maxLat, t.maxLon);
    }

    if (minLat == null) return null;
    return CameraFit.bounds(
      bounds: LatLngBounds(
        LatLng(minLat!, minLon!),
        LatLng(maxLat!, maxLon!),
      ),
      padding: const EdgeInsets.all(36),
    );
  }

  void _onMapTap(TapPosition tapPos, LatLng latLng) {
    if (widget.measureMode) {
      widget.onMeasureTap?.call(latLng);
      return;
    }
    if (widget.routingMode) {
      widget.onRoutingTap?.call(latLng);
      return;
    }
    if (widget.incidentMode) {
      widget.onMapTapForIncident?.call(latLng);
      return;
    }

    widget.onMapTap?.call(latLng);

    final trailProv = context.read<StaticDataProvider>();
    Trail? nearest;
    double minDist = double.infinity;

    // Use a small buffer around the tap for bounding box checks
    const buffer = 0.01; // Roughly 1km

    for (final trail in trailProv.allTrails) {
      // 1. Quick bounding box check
      final tMinLat = trail.minLat;
      final tMaxLat = trail.maxLat;
      final tMinLon = trail.minLon;
      final tMaxLon = trail.maxLon;

      if (latLng.latitude < tMinLat - buffer ||
          latLng.latitude > tMaxLat + buffer ||
          latLng.longitude < tMinLon - buffer ||
          latLng.longitude > tMaxLon + buffer) {
        continue;
      }

      // 2. Only check coordinates if the tap is near the trail's bounding box
      for (final coord in trail.coords) {
        final d = _distM(latLng, LatLng(coord.lat, coord.lon));
        if (d < minDist) {
          minDist = d;
          nearest = trail;
        }
      }
    }

    // 3. Check GPX tracks from provider
    final gpxProv = context.read<GpxProvider>();
    UserGpxTrack? nearestGpx;
    double minGpxDist = double.infinity;

    for (final track in gpxProv.tracks) {
      if (track.points.isEmpty) continue;

      // 1. Cached bounding box check for performance
      if (latLng.latitude < track.minLat - buffer ||
          latLng.latitude > track.maxLat + buffer ||
          latLng.longitude < track.minLon - buffer ||
          latLng.longitude > track.maxLon + buffer) {
        continue;
      }

      // 2. Precise coordinate check
      for (final p in track.points) {
        final d = _distM(latLng, p);
        if (d < minGpxDist) {
          minGpxDist = d;
          nearestGpx = track;
        }
      }
    }

    if (nearestGpx != null &&
        minGpxDist < 150 &&
        (nearest == null || minGpxDist < minDist)) {
      widget.onGpxTap?.call(nearestGpx);
    } else if (nearest != null && minDist < 150) {
      widget.onTrailTap(nearest);
    }
  }

  double _distM(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final sinA = math.sin(dLat / 2);
    final sinO = math.sin(dLon / 2);
    final h = sinA * sinA +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * sinO * sinO;
    return 2 * r * math.asin(math.sqrt(h));
  }

  double _rad(double d) => d * math.pi / 180;
}

class _ProfileCursorMarker extends StatefulWidget {
  const _ProfileCursorMarker();

  @override
  State<_ProfileCursorMarker> createState() => _ProfileCursorMarkerState();
}

class _ProfileCursorMarkerState extends State<_ProfileCursorMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final scale = 0.75 + (_pulse.value * 0.45);
        final opacity = 0.32 - (_pulse.value * 0.16);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kColorOrange.withOpacity(opacity),
                ),
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kColorOrange,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
