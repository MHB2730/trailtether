import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/cave_waypoint.dart';
import '../../models/incident.dart';
import '../../models/trail.dart';
import '../../services/hazard_service.dart';
import '../../models/recording_point.dart';
import '../../core/utils.dart';

class TrailMap3DAndroidWidget extends StatefulWidget {
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

  const TrailMap3DAndroidWidget({
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
  State<TrailMap3DAndroidWidget> createState() =>
      _TrailMap3DAndroidWidgetState();
}

class _TrailMap3DAndroidWidgetState extends State<TrailMap3DAndroidWidget> {
  late final WebViewController _ctrl;
  bool _mapReady = false; // true once JS signals 'mapReady'
  bool _htmlLoaded = false; // true once the page HTML has finished loading

  DateTime? _lastGpsPush;
  int _lastRecordingCount = 0;
  DateTime? _lastRecordingPush;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D0D0D))
      // ── JS → Flutter channel ─────────────────────────────────────────────
      ..addJavaScriptChannel(
        'MapLibreChannel',
        onMessageReceived: _onMessage,
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          setState(() => _htmlLoaded = true);
        },
        onWebResourceError: (WebResourceError e) {
          debugPrint('3D map resource error: ${e.description}');
        },
      ))
      ..loadFlutterAsset('assets/map/map3d.html');
  }

  // ── JS → Flutter ──────────────────────────────────────────────────────────
  void _onMessage(JavaScriptMessage msg) {
    final text = msg.message;

    if (text == 'mapReady') {
      _mapReady = true;
      _injectTrails();
      _injectCaves();
      _injectIncidents();
      _updateWeather();
      _updateStyle();
      _updateGps();
      _injectHazards();
      _injectRecording();

      if (widget.initialLat != null && widget.initialLon != null) {
        _ctrl.runJavaScript(
            'if(window.setViewState) setViewState(${widget.initialLat}, ${widget.initialLon}, ${widget.initialZoom ?? 13});');
      }
      return;
    }

    if (text.startsWith('onTrailTap:')) {
      final id = text.substring('onTrailTap:'.length);
      if (id.isNotEmpty) widget.onTrailTap?.call(id);
      return;
    }

    if (text.startsWith('onCaveTap:')) {
      final payload = text.substring('onCaveTap:'.length);
      final parts = payload.split('|');
      if (parts.length >= 4 && widget.onCaveTap != null) {
        widget.onCaveTap!(CaveWaypoint(
          name: parts[0],
          lat: double.tryParse(parts[1]) ?? 0,
          lon: double.tryParse(parts[2]) ?? 0,
          elevationM: double.tryParse(parts[3]) ?? 0,
        ));
      }
      return;
    }

    if (text.startsWith('onIncidentTap:')) {
      final id = text.substring('onIncidentTap:'.length);
      if (id.isNotEmpty && widget.onIncidentTap != null) {
        final incident = widget.incidents.firstWhere(
          (i) => i.id == id,
          orElse: () => widget.incidents.first,
        );
        widget.onIncidentTap!(incident);
      }
    }
  }

  // ── GeoJSON Injections ───────────────────────────────────────────────────
  void _injectTrails() {
    if (!_mapReady) return;

    final features = widget.trails.map((t) {
      final coords = t.coords.map((c) => <double>[c.lon, c.lat]).toList();
      return {
        'type': 'Feature',
        'properties': {'id': t.id, 'name': t.name, 'difficulty': t.difficulty},
        'geometry': {'type': 'LineString', 'coordinates': coords},
      };
    }).toList();

    final escaped = jsonEncode(
        jsonEncode({'type': 'FeatureCollection', 'features': features}));
    _ctrl
        .runJavaScript('setTrails($escaped)')
        .catchError((e) => debugPrint('setTrails error: $e'));
  }

  void _injectCaves() {
    if (!_mapReady || widget.caves.isEmpty) return;

    final features = widget.caves
        .map((c) => {
              'type': 'Feature',
              'properties': {
                'name': c.name,
                'shortName': _shortName(c.name),
                'lat': c.lat,
                'lon': c.lon,
                'ele': c.elevationM,
                'isShelter': c.isShelter,
              },
              'geometry': {
                'type': 'Point',
                'coordinates': <double>[c.lon, c.lat, c.elevationM]
              },
            })
        .toList();

    final escaped = jsonEncode(
        jsonEncode({'type': 'FeatureCollection', 'features': features}));
    _ctrl
        .runJavaScript('setCaves($escaped)')
        .catchError((e) => debugPrint('setCaves error: $e'));
  }

  String _shortName(String name) => name
      .replaceAll(RegExp(r'\s+Cave\s*\d*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+Caves$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+Shelter$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+Chalet$', caseSensitive: false), '')
      .trim();

  void _injectIncidents() {
    if (!_mapReady || widget.incidents.isEmpty) return;
    final features = widget.incidents
        .map((inc) => {
              'type': 'Feature',
              'properties': {
                'id': inc.id,
                'severity': inc.severity.key,
                'typeEmoji': inc.type.emoji,
                'typeLabel': inc.type.label,
              },
              'geometry': {
                'type': 'Point',
                'coordinates': <double>[inc.lon, inc.lat]
              },
            })
        .toList();
    final escaped = jsonEncode(
        jsonEncode({'type': 'FeatureCollection', 'features': features}));
    _ctrl
        .runJavaScript('setIncidents($escaped)')
        .catchError((e) => debugPrint('setIncidents error: $e'));
  }

  void _injectHazards() {
    if (!_mapReady) return;
    final features = widget.hazards.map((h) => h.toGeoJson()).toList();
    final escaped = jsonEncode(
        jsonEncode({'type': 'FeatureCollection', 'features': features}));
    _ctrl
        .runJavaScript('setHazards($escaped)')
        .catchError((e) => debugPrint('setHazards error: $e'));
  }

  void _injectRecording() {
    if (!_mapReady || widget.recordingPoints.isEmpty) return;

    final features = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.recordingPoints.length - 1; i++) {
      final p1 = widget.recordingPoints[i];
      final p2 = widget.recordingPoints[i + 1];
      final speed = p2.speed * 3.6;

      features.add({
        'type': 'Feature',
        'properties': {
          'color': TrailUtils.getSpeedColorHex(speed),
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [p1.longitude, p1.latitude],
            [p2.longitude, p2.latitude],
          ],
        },
      });
    }

    final escaped = jsonEncode(
        jsonEncode({'type': 'FeatureCollection', 'features': features}));
    _ctrl
        .runJavaScript('setRecording($escaped)')
        .catchError((e) => debugPrint('setRecording error: $e'));
  }

  // ── Updates ──────────────────────────────────────────────────────────────
  void _flyToSelected() {
    if (!_mapReady) return;
    final trail = widget.selectedTrail;
    if (trail == null || trail.coords.isEmpty) return;

    final lats = trail.coords.map((c) => c.lat).toList()..sort();
    final lons = trail.coords.map((c) => c.lon).toList()..sort();
    final lat = (lats.first + lats.last) / 2;
    final lon = (lons.first + lons.last) / 2;

    final id = jsonEncode(trail.id);
    _ctrl.runJavaScript("if(window.flyToFeature) flyToFeature($id,$lon,$lat);");
  }

  void _updateGps() {
    if (!_mapReady || widget.gpsLat == null || widget.gpsLon == null) return;
    final bearing = widget.bearing != null ? '${widget.bearing}' : 'null';
    _ctrl.runJavaScript(
        'if(window.updateGpsPosition) updateGpsPosition(${widget.gpsLat}, ${widget.gpsLon}, $bearing);');
  }

  void _updateWeather() {
    if (!_mapReady) return;
    final code = widget.weatherCode ?? 0;
    final cloud = widget.cloudCover ?? 0;
    _ctrl.runJavaScript('if(window.setWeather) setWeather($code, $cloud);');
  }

  void _updateStyle() {
    if (!_mapReady) return;
    final style = widget.useTopoStyle ? "'topo'" : "'satellite'";
    _ctrl.runJavaScript('if(window.setStyle) setStyle($style);');
  }

  @override
  void didUpdateWidget(TrailMap3DAndroidWidget old) {
    super.didUpdateWidget(old);
    if (!_mapReady) return;

    if (widget.selectedTrail?.id != old.selectedTrail?.id) _flyToSelected();
    if (widget.trails.length != old.trails.length) _injectTrails();
    if (widget.caves.length != old.caves.length) _injectCaves();
    if (widget.incidents.length != old.incidents.length) _injectIncidents();
    if (widget.hazards.length != old.hazards.length) _injectHazards();

    // Throttle recording updates (every 5 points OR 5 seconds)
    final now = DateTime.now();
    final shouldPushRec = widget.recordingPoints.length !=
            _lastRecordingCount &&
        (widget.recordingPoints.length - _lastRecordingCount >= 5 ||
            _lastRecordingPush == null ||
            now.difference(_lastRecordingPush!) > const Duration(seconds: 5));

    if (shouldPushRec) {
      _lastRecordingCount = widget.recordingPoints.length;
      _lastRecordingPush = now;
      _injectRecording();
    }

    // Throttle GPS movement (every 1 second)
    if (widget.gpsLat != old.gpsLat ||
        widget.gpsLon != old.gpsLon ||
        widget.bearing != old.bearing) {
      if (_lastGpsPush == null ||
          now.difference(_lastGpsPush!) > const Duration(milliseconds: 1000)) {
        _lastGpsPush = now;
        _updateGps();
      }
    }

    if (widget.weatherCode != old.weatherCode ||
        widget.cloudCover != old.cloudCover) {
      _updateWeather();
    }
    if (widget.useTopoStyle != old.useTopoStyle) {
      _updateStyle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _ctrl),
        if (!_htmlLoaded)
          const ColoredBox(
            color: Color(0xFF0D0D0D),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE8541A),
                strokeWidth: 2.5,
              ),
            ),
          ),
      ],
    );
  }
}
