import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../models/cave_waypoint.dart';
import '../../models/incident.dart';
import '../../models/team.dart';
import '../../models/trail.dart';
import '../../services/local_map_server.dart';
import '../../services/hazard_service.dart';
import '../../models/recording_point.dart';
import '../../core/utils.dart';

/// Windows 3D map widget — WebView2 (Edge) via webview_windows.
class TrailMap3DWindowsWidget extends StatefulWidget {
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
  final List<TeamMemberLocation> teamLocations;

  const TrailMap3DWindowsWidget({
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
    this.teamLocations = const [],
  });

  @override
  State<TrailMap3DWindowsWidget> createState() =>
      _TrailMap3DWindowsWidgetState();
}

class _TrailMap3DWindowsWidgetState extends State<TrailMap3DWindowsWidget> {
  final _ctrl = WebviewController();

  bool _webviewReady = false;
  bool _mapReady = false;
  String? _error; // non-null → show error UI

  StreamSubscription<dynamic>? _msgSub;
  Timer? _timeoutTimer;
  DateTime? _lastGpsPush;
  int _lastRecordingCount = 0;
  DateTime? _lastRecordingPush;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _ctrl.initialize();

      _msgSub = _ctrl.webMessage.listen(_onMessage);

      // 30-second timeout — if mapReady never arrives something went wrong
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!_mapReady && mounted) {
          setState(() => _error =
              'Map timed out loading.\nCheck internet access and try again.');
        }
      });

      await LocalMapServer.start();

      await _ctrl.loadUrl(
        'http://127.0.0.1:${LocalMapServer.port}/map3d.html',
      );

      if (mounted) setState(() => _webviewReady = true);
    } catch (e) {
      debugPrint('TrailMap3DWindowsWidget init error: $e');
      if (mounted) {
        setState(() => _error = 'WebView2 failed to start.\n$e');
      }
    }
  }

  // ── JS → Flutter ──────────────────────────────────────────────────────────
  void _onMessage(dynamic raw) {
    final text = raw is String ? raw : (raw['message'] as String? ?? '');

    if (text == 'mapReady') {
      _timeoutTimer?.cancel();
      setState(() {
        _mapReady = true;
        _error = null;
      });
      _injectTrails();
      _injectCaves();
      _injectIncidents();
      _updateWeather();
      _updateStyle();
      _updateGps();
      _injectHazards();
      _injectRecording();
      _injectTeam();

      if (widget.initialLat != null && widget.initialLon != null) {
        _ctrl.executeScript(
            'if(window.setViewState) setViewState(${widget.initialLat}, ${widget.initialLon}, ${widget.initialZoom ?? 13});');
      }
      return;
    }

    if (text.startsWith('mapError:')) {
      final msg = text.substring('mapError:'.length);
      if (mounted) setState(() => _error = 'Map error: $msg');
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
      if (id.isNotEmpty &&
          widget.onIncidentTap != null &&
          widget.incidents.isNotEmpty) {
        final incident = widget.incidents.firstWhere(
          (i) => i.id == id,
          orElse: () => widget.incidents.first,
        );
        widget.onIncidentTap!(incident);
      }
    }
  }

  // ── GeoJSON → map ─────────────────────────────────────────────────────────
  void _injectTrails() {
    if (!_mapReady) return;
    final features = widget.trails
        .map((t) => {
              'type': 'Feature',
              'properties': {
                'id': t.id,
                'name': t.name,
                'difficulty': t.difficulty
              },
              'geometry': {
                'type': 'LineString',
                'coordinates':
                    t.coords.map((c) => <double>[c.lon, c.lat]).toList(),
              },
            })
        .toList();
    final escaped = jsonEncode(
        jsonEncode({'type': 'FeatureCollection', 'features': features}));
    _ctrl.executeScript('setTrails($escaped)');
  }

  // ── Build incident GeoJSON and push to the map ────────────────────────────
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
                'trailName': inc.trailName ?? '',
              },
              'geometry': {
                'type': 'Point',
                'coordinates': <double>[inc.lon, inc.lat],
              },
            })
        .toList();
    final escaped = jsonEncode(
        jsonEncode({'type': 'FeatureCollection', 'features': features}));
    _ctrl.executeScript('setIncidents($escaped)');
  }

  // ── Build cave GeoJSON and push to the map ────────────────────────────────
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
                'coordinates': <double>[c.lon, c.lat, c.elevationM],
              },
            })
        .toList();
    final escaped = jsonEncode(
        jsonEncode({'type': 'FeatureCollection', 'features': features}));
    _ctrl.executeScript('setCaves($escaped)');
  }

  void _injectHazards() {
    if (!_mapReady) return;
    final features = widget.hazards.map((h) => h.toGeoJson()).toList();
    final escaped = jsonEncode(
        jsonEncode({'type': 'FeatureCollection', 'features': features}));
    _ctrl.executeScript('setHazards($escaped)');
  }

  void _injectRecording() {
    if (!_mapReady || widget.recordingPoints.isEmpty) return;

    // We create a MultiLineString where each segment has a 'color' property
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
    _ctrl.executeScript('setRecording($escaped)');
  }

  void _injectTeam() {
    if (!_mapReady || widget.teamLocations.isEmpty) return;
    final features = widget.teamLocations
        .map((loc) => {
              'type': 'Feature',
              'properties': {
                'displayName': loc.displayName,
                'status': loc.status,
              },
              'geometry': {
                'type': 'Point',
                'coordinates': <double>[loc.lon, loc.lat],
              },
            })
        .toList();
    final escaped = jsonEncode(
        jsonEncode({'type': 'FeatureCollection', 'features': features}));
    _ctrl.executeScript('setTeamLocations($escaped)');
  }

  String _shortName(String name) => name
      .replaceAll(RegExp(r'\s+Cave\s*\d*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+Caves$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+Shelter$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+Chalet$', caseSensitive: false), '')
      .trim();

  // ── Camera & Updates ───────────────────────────────────────────────────────
  void _flyToSelected() {
    if (!_mapReady) return;
    final trail = widget.selectedTrail;
    if (trail == null || trail.coords.isEmpty) return;
    final lats = trail.coords.map((c) => c.lat).toList()..sort();
    final lons = trail.coords.map((c) => c.lon).toList()..sort();
    final lat = (lats.first + lats.last) / 2;
    final lon = (lons.first + lons.last) / 2;
    final id = jsonEncode(trail.id);
    _ctrl.executeScript("if(window.flyToFeature) flyToFeature($id,$lon,$lat);");
  }

  void _updateGps() {
    if (!_mapReady || widget.gpsLat == null || widget.gpsLon == null) return;
    final bearing = widget.bearing != null ? '${widget.bearing}' : 'null';
    _ctrl.executeScript(
        'if(window.updateGpsPosition) updateGpsPosition(${widget.gpsLat}, ${widget.gpsLon}, $bearing);');
  }

  void _updateWeather() {
    if (!_mapReady) return;
    final code = widget.weatherCode ?? 0;
    final cloud = widget.cloudCover ?? 0;
    _ctrl.executeScript('if(window.setWeather) setWeather($code, $cloud);');
  }

  void _updateStyle() {
    if (!_mapReady) return;
    final style = widget.useTopoStyle ? "'topo'" : "'satellite'";
    _ctrl.executeScript('if(window.setStyle) setStyle($style);');
  }

  @override
  void didUpdateWidget(TrailMap3DWindowsWidget old) {
    super.didUpdateWidget(old);
    if (!_mapReady) return;

    if (widget.selectedTrail?.id != old.selectedTrail?.id) _flyToSelected();
    if (widget.trails.length != old.trails.length) _injectTrails();
    if (widget.caves.length != old.caves.length) _injectCaves();
    if (widget.incidents.length != old.incidents.length) _injectIncidents();
    if (widget.hazards.length != old.hazards.length) _injectHazards();
    if (widget.teamLocations.length != old.teamLocations.length) _injectTeam();

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
  void dispose() {
    _timeoutTimer?.cancel();
    _msgSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Error state — show a readable message with retry button
    if (_error != null) {
      return ColoredBox(
        color: const Color(0xFF0D0D0D),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined,
                    color: Color(0xFFE8541A), size: 48),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: GoogleFonts.outfit(
                      color: Colors.white60, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8541A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: Text('Retry',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _webviewReady = false;
                      _mapReady = false;
                    });
                    _init();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading state
    if (!_webviewReady) {
      return ColoredBox(
        color: const Color(0xFF0D0D0D),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: Color(0xFFE8541A), strokeWidth: 2.5),
              const SizedBox(height: 16),
              Text('Starting 3D map…',
                  style:
                      GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Webview(
      _ctrl,
      permissionRequested: (_, __, ___) async => WebviewPermissionDecision.deny,
    );
  }
}
