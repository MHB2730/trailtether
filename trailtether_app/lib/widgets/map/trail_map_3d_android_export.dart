// This file is the dart:io (non-web) implementation selected by
// trail_map_3d_selector.dart.  It covers both Android and Windows by doing
// a runtime Platform check.
//
// Android → TrailMap3DAndroidWidget  (webview_flutter / WebKit)
// Windows → TrailMap3DWindowsWidget  (webview_windows / WebView2)

import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/cave_waypoint.dart';
import '../../models/incident.dart';
import '../../models/trail.dart';
import 'trail_map_3d_android.dart';
import 'trail_map_3d_widget.dart' deferred as win;
import '../../services/hazard_service.dart';
import '../../models/recording_point.dart';

/// Single widget that delegates to the right WebView implementation.
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
    if (Platform.isWindows) {
      return FutureBuilder(
        future: win.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return win.TrailMap3DWindowsWidget(
              trails: trails,
              selectedTrail: selectedTrail,
              onTrailTap: onTrailTap,
              caves: caves,
              onCaveTap: onCaveTap,
              incidents: incidents,
              onIncidentTap: onIncidentTap,
              gpsLat: gpsLat,
              gpsLon: gpsLon,
              bearing: bearing,
              weatherCode: weatherCode,
              cloudCover: cloudCover,
              hazards: hazards,
              useTopoStyle: useTopoStyle,
              recordingPoints: recordingPoints,
              initialLat: initialLat,
              initialLon: initialLon,
              initialZoom: initialZoom,
            );
          }
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        },
      );
    }
    // Android, iOS, Linux, macOS — all use webview_flutter.
    return TrailMap3DAndroidWidget(
      trails: trails,
      selectedTrail: selectedTrail,
      onTrailTap: onTrailTap,
      caves: caves,
      onCaveTap: onCaveTap,
      incidents: incidents,
      onIncidentTap: onIncidentTap,
      gpsLat: gpsLat,
      gpsLon: gpsLon,
      bearing: bearing,
      weatherCode: weatherCode,
      cloudCover: cloudCover,
      hazards: hazards,
      useTopoStyle: useTopoStyle,
      recordingPoints: recordingPoints,
      initialLat: initialLat,
      initialLon: initialLon,
      initialZoom: initialZoom,
    );
  }
}
