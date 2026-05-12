import 'package:flutter/material.dart';
import '../../models/cave_waypoint.dart';
import '../../models/incident.dart';
import '../../models/trail.dart';
import '../../services/hazard_service.dart';
import '../../models/recording_point.dart';

class TrailMap3DWidget extends StatelessWidget {
  final List<Trail> trails;
  final Trail? selectedTrail;
  final ValueChanged<String>? onTrailTap;
  final List<CaveWaypoint> caves;
  final void Function(CaveWaypoint cave)? onCaveTap;
  final List<Incident> incidents;
  final void Function(Incident)? onIncidentTap;
  final double? gpsLat;
  final double? gpsLon;
  final double? bearing;
  final int? weatherCode;
  final int? cloudCover;
  final List<HazardZone> hazards;
  final bool useTopoStyle;
  final List<RecordingPoint> recordingPoints;
  final double? initialLat;
  final double? initialLon;
  final double? initialZoom;

  const TrailMap3DWidget({
    super.key,
    required this.trails,
    this.selectedTrail,
    this.onTrailTap,
    this.caves = const [],
    this.onCaveTap,
    this.incidents = const [],
    this.onIncidentTap,
    this.gpsLat,
    this.gpsLon,
    this.bearing,
    this.weatherCode,
    this.cloudCover,
    this.hazards = const [],
    this.useTopoStyle = false,
    this.recordingPoints = const [],
    this.initialLat,
    this.initialLon,
    this.initialZoom,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('3D Map not supported on this platform'));
  }
}
