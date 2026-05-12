import 'package:flutter/material.dart';
import '../../models/cave_waypoint.dart';
import '../../models/incident.dart';
import '../../models/trail.dart';
import 'trail_map_3d_widget.dart' as win;

class TrailMap3DWidget extends StatelessWidget {
  final List<Trail> trails;
  final Trail? selectedTrail;
  final ValueChanged<String>? onTrailTap;
  final List<CaveWaypoint> caves;
  final void Function(CaveWaypoint cave)? onCaveTap;
  final List<Incident> incidents;
  final void Function(Incident)? onIncidentTap;

  const TrailMap3DWidget({
    super.key,
    required this.trails,
    this.selectedTrail,
    this.onTrailTap,
    this.caves = const [],
    this.onCaveTap,
    this.incidents = const [],
    this.onIncidentTap,
  });

  @override
  Widget build(BuildContext context) {
    return win.TrailMap3DWindowsWidget(
      trails: trails,
      selectedTrail: selectedTrail,
      onTrailTap: onTrailTap,
      caves: caves,
      onCaveTap: onCaveTap,
      incidents: incidents,
      onIncidentTap: onIncidentTap,
    );
  }
}
