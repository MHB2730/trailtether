import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart' hide Container;
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/cave_waypoint.dart';
import '../models/incident.dart';
import '../models/trail.dart';
import '../providers/app_state_provider.dart';
import '../providers/static_data_provider.dart';
import '../providers/safety_provider.dart';
import '../providers/gpx_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/review_provider.dart';
import '../providers/units_provider.dart';
import '../services/location_service.dart';
import '../services/hazard_service.dart';
import '../providers/weather_provider.dart';
import '../providers/team_tracking_provider.dart';
import '../widgets/common/glass_panel.dart';
import '../widgets/map/trail_map_3d_selector.dart';
import '../widgets/map/trail_map_widget.dart';
import '../widgets/trail/difficulty_badge.dart';
import 'cave_detail_sheet.dart';
import 'incident_detail_sheet.dart';
import 'live_tracking_screen.dart';
import 'offline_download_screen.dart';
import 'field_intel_sheet.dart';
import 'trail_detail_screen.dart';
import 'trails_tab.dart';

class MapScreen extends StatefulWidget {
  final void Function(int tab)? onSwitchTab;
  const MapScreen({super.key, this.onSwitchTab});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ── Map mode ────────────────────────────────────────────────────────
  bool _show3D =
      false; // false = 2D (flutter_map), true = 3D (MapLibre WebView)

  // ── 2D map ─────────────────────────────────────────────────────────
  final _mapCtrl = MapController();

  // ── Tile style — cycles through kMapTileStyles ──────────────────────
  int _tileStyleIndex = 0; // default: Outdoor (OpenTopoMap)

  // ── GPS / connectivity ──────────────────────────────────────────────
  bool _gpsActive = false;
  bool _isOffline = false;
  bool _incidentMode = false; // when true, map tap opens incident reporter
  bool _showCaves = true; // toggle cave marker layer on 2D map
  bool _showIncidents = true; // toggle incident reports visibility
  bool _measureMode = false; // distance measurement mode
  final List<LatLng> _measurePoints = []; // measurement waypoints
  bool _didAutoFit = false;
  String? _gpsHint;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() {
        _isOffline = results.every((r) => r == ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _cycleMapMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (!_show3D) {
        if (_tileStyleIndex == 0) {
          // Outdoor -> Satellite
          _tileStyleIndex = 1;
        } else {
          // Satellite -> 3D
          _show3D = true;
        }
      } else {
        // 3D -> Outdoor
        _show3D = false;
        _tileStyleIndex = 0;
      }
    });
  }

  // ── Handlers ────────────────────────────────────────────────────────
  Future<void> _toggleGps() async {
    if (!_gpsActive) {
      final ok = await LocationService.requestPermission();
      if (!ok && mounted) {
        final status = await LocationService.permissionStatus();
        setState(() {
          _gpsHint = status == LocationPermission.deniedForever
              ? 'Location access is blocked in system settings.'
              : 'Location permission is required for live tracking.';
        });
        return;
      }
    }
    setState(() {
      HapticFeedback.mediumImpact();
      _gpsActive = !_gpsActive;
      _gpsHint = null;
    });
  }

  void _onTrailTap(Trail trail) {
    context.read<StaticDataProvider>().selectTrail(trail);
    context.read<ReviewProvider>().listenTo(trail.id);

    // Show details directly instead of switching to 3D
    _openDetail(trail);

    // In 2D mode, fly the camera to the trail bounds.
    // In 3D mode, flyToFeature is called inside TrailMap3DWidget.
    // FLY-TO LOGIC REMOVED as requested.
    // We just show details now.
  }

  void _fitAll() {
    if (_show3D) return; // 3D map has its own navigation controls
    final points = <LatLng>[
      for (final trail in context.read<StaticDataProvider>().allTrails)
        for (final coord in trail.coords) LatLng(coord.lat, coord.lon),
      for (final track in context.read<GpxProvider>().tracks) ...track.points,
    ];

    if (points.isEmpty) {
      _mapCtrl.move(
        LatLng(kWorldMapCenter.lat, kWorldMapCenter.lon),
        kWorldMapZoomInit,
      );
      return;
    }

    final bounds = _boundsFor(points);
    if ((bounds.north - bounds.south).abs() < 0.0001 &&
        (bounds.east - bounds.west).abs() < 0.0001) {
      _mapCtrl.move(bounds.center, 14);
      return;
    }

    _mapCtrl.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(32),
      ),
    );
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }
    return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
  }

  void _openDetail(Trail trail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrailDetailScreen(
        trail: trail,
        onNavigateToMap: () {},
      ),
    ).then((_) {
      if (mounted) context.read<StaticDataProvider>().selectTrail(null);
    });
  }

  // ── Incident mode ────────────────────────────────────────────────────
  void _toggleIncidentMode() => setState(() => _incidentMode = !_incidentMode);

  /// On the 3D map, we can't intercept WebView taps, so we open the incident
  /// sheet immediately using the GPS position if tracking, or map centre.
  void _reportFieldIntel3D() {
    final lat = _lastGpsPos?.latitude ?? kWorldMapCenter.lat;
    final lon = _lastGpsPos?.longitude ?? kWorldMapCenter.lon;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FieldIntelSheet(
        position: LatLng(lat, lon),
        nearestTrail: _findNearestTrail(LatLng(lat, lon)),
      ),
    ).then((ok) {
      if (!mounted) return;
      if (ok == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Field intel reported — thank you!'),
            backgroundColor: const Color(0xFF4CAF50).withOpacity(0.9),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  LatLng? _lastGpsPos; // updated by GPS layer via callback

  void _onMapTap(TapPosition tapPos, LatLng latLng) {
    if (_incidentMode) {
      setState(() => _incidentMode = false);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FieldIntelSheet(
          position: latLng,
          nearestTrail: _findNearestTrail(latLng),
        ),
      ).then((ok) {
        if (!mounted) return;
        if (ok == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Field intel reported — thank you!'),
              backgroundColor: const Color(0xFF4CAF50).withOpacity(0.9),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
      return;
    }

    if (_measureMode) {
      setState(() {
        _measurePoints.add(latLng);
      });
      return;
    }
  }

  Trail? _findNearestTrail(LatLng pos) {
    final trails = context.read<StaticDataProvider>().allTrails;
    Trail? nearest;
    double minDist = double.infinity;
    for (final t in trails) {
      for (final c in t.coords) {
        final d = _haversineM(pos.latitude, pos.longitude, c.lat, c.lon);
        if (d < minDist) {
          minDist = d;
          nearest = t;
        }
      }
    }
    return (minDist < 1200) ? nearest : null;
  }

  void _onIncidentMarkerTap(Incident incident) {
    IncidentDetailSheet.show(context, incident);
  }

  void _onCaveTap(CaveWaypoint cave) {
    CaveDetailSheet.show(context, cave);
  }

  double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * R * math.asin(math.sqrt(a));
  }

  double _toRad(double d) => d * math.pi / 180;

  // ── Measurement helpers ──────────────────────────────────────────────
  void _toggleMeasureMode() {
    setState(() {
      _measureMode = !_measureMode;
      if (_measureMode) {
        _incidentMode = false;
      }
      if (!_measureMode) _measurePoints.clear();
    });
  }

  void _onMeasureTap(LatLng pos) {
    setState(() => _measurePoints.add(pos));
  }

  /// Total length of the measurement path in metres.
  double get _measureDistanceM {
    if (_measurePoints.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < _measurePoints.length; i++) {
      final a = _measurePoints[i - 1];
      final b = _measurePoints[i];
      total += _haversineM(a.latitude, a.longitude, b.latitude, b.longitude);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();
    final data = context.watch<StaticDataProvider>();
    final safety = context.watch<SafetyProvider>();
    final appState = context.watch<AppStateProvider>();
    final topPad = MediaQuery.of(context).padding.top;

    final selected = data.selectedTrail;
    final trails = data.allTrails;
    final caves = data.caves;
    final incidents = safety.incidents;

    // Calculate Hazards
    final hazards = HazardService.calculateWeatherHazards(
        weather.currentWeather,
        _lastGpsPos?.latitude ?? kWorldMapCenter.lat,
        _lastGpsPos?.longitude ?? kWorldMapCenter.lon);

    if (!_didAutoFit && !_show3D && trails.isNotEmpty) {
      // Only mark as auto-fitted if we actually have trails to fit to.
      // This ensures that if trails load late, the camera will still move.
      _didAutoFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitAll();
      });
    }

    // ── 3D mode ─────────────────────────────────────────────────────────────
    if (_show3D) {
      return Scaffold(
        backgroundColor: kColorBg,
        body: Column(
          children: [
            // ── Top bar — pure Flutter, above the WebView ──────────────
            widgets.Container(
              color: kColorBg,
              padding: EdgeInsets.fromLTRB(14, topPad + 8, 14, 8),
              child: Row(
                children: [
                  const _MapLabel(is3D: true),
                  const SizedBox(width: 12),
                  if (weather.currentWeather != null)
                    _WeatherSummaryPill(weather: weather),
                  const Spacer(),
                  _MapFab(
                    icon: _gpsActive ? Icons.gps_fixed : Icons.gps_not_fixed,
                    active: _gpsActive,
                    tooltip: _gpsActive ? 'GPS on' : 'GPS off',
                    onTap: _toggleGps,
                  ),
                  const SizedBox(width: 8),
                  _MapFab(
                    icon: Icons.warning_amber_rounded,
                    active: false,
                    tooltip: 'Report field intel',
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      _reportFieldIntel3D();
                    },
                  ),
                  const SizedBox(width: 8),
                  _MapFab(
                    icon: Icons.download_for_offline,
                    tooltip: 'Offline maps',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OfflineDownloadScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Offline / GPS hint banner ────────────────────────────────
            if (_isOffline || _gpsHint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: _MapBanner(
                  text: _gpsHint ??
                      (appState.offlineRegionReady
                          ? 'Offline mode: cached tiles available.'
                          : 'Offline mode: download maps before heading out.'),
                  actionLabel: _gpsHint != null
                      ? 'Settings'
                      : appState.offlineRegionReady
                          ? null
                          : 'Download',
                  onAction: _gpsHint != null
                      ? LocationService.openSettings
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OfflineDownloadScreen(),
                            ),
                          ),
                ),
              ),

            // ── 3D WebView fills remaining space ─────────────────────────
            Expanded(
              child: TrailMap3DWidget(
                trails: trails,
                selectedTrail: selected,
                caves: caves,
                onCaveTap: _onCaveTap,
                incidents: _showIncidents ? incidents : const [],
                onIncidentTap: _onIncidentMarkerTap,
                hazards: hazards,
                weatherCode: weather.currentWeather?.current.weatherCode,
                cloudCover: weather.currentWeather?.current.cloudCover,
                gpsLat: _gpsActive ? _lastGpsPos?.latitude : null,
                gpsLon: _gpsActive ? _lastGpsPos?.longitude : null,
                onTrailTap: (id) {
                  if (trails.isEmpty) return;
                  final t = trails.firstWhere(
                    (e) => e.id == id,
                    orElse: () => trails.first,
                  );
                  _onTrailTap(t);
                },
                initialLat: _mapCtrl.camera.center.latitude,
                initialLon: _mapCtrl.camera.center.longitude,
                initialZoom: _mapCtrl.camera.zoom,
                useTopoStyle: _tileStyleIndex == 0,
              ),
            ),

            // ── Selected trail card — below WebView, fully interactive ───
            if (selected != null)
              _TrailInfoCard(
                trail: selected,
                onDetail: () => _openDetail(selected),
                onClose: () {
                  HapticFeedback.lightImpact();
                  context.read<StaticDataProvider>().selectTrail(null);
                },
              ),
            // ── Mode Toggle Pill (Bottom) ──────────────
            // ── Mode Cycle Pill (Bottom) ──────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              child: _MapModeCycle(
                is3D: _show3D,
                tileStyleIndex: _tileStyleIndex,
                onCycle: _cycleMapMode,
              ),
            ),
          ],
        ),
      );
    }

    // ── 2D mode — original Stack layout ─────────────────────────────────────
    return Scaffold(
      backgroundColor: kColorBg,
      body: Stack(
        children: [
          // 2D flutter_map (always in tree so controller stays alive)
          TrailMapWidget(
            controller: _mapCtrl,
            onTrailTap: _onTrailTap,
            gpsActive: _gpsActive,
            tileStyleIndex: _tileStyleIndex,
            incidentMode: _incidentMode,
            onMapTapForIncident: (pos) =>
                _onMapTap(const TapPosition(Offset.zero, Offset.zero), pos),
            onIncidentTap: _onIncidentMarkerTap,
            onPositionUpdate: (pos) => setState(() => _lastGpsPos = pos),
            showCaves: _showCaves,
            showIncidents: _showIncidents,
            measureMode: _measureMode,
            onMeasureTap: _onMeasureTap,
            measurePoints: _measurePoints,
          ),

          // ── Incident mode banner ───────────────────────────────────────
          if (_incidentMode)
            Positioned(
              bottom: 90,
              left: 14,
              right: 14,
              child: _IncidentModeBanner(),
            ),

          // ── Recording Dashboard ────────────────────────────────────────────────────
          if (context.watch<RecordingProvider>().isRecording)
            Positioned(
              bottom: 90,
              left: 14,
              right: 14,
              child:
                  _RecordingDashboard(rec: context.watch<RecordingProvider>()),
            ),

          // ── Measure mode banner ────────────────────────────────────────
          if (_measureMode)
            Positioned(
              bottom: _incidentMode ? 142 : 90,
              left: 14,
              right: 14,
              child: _MeasureBanner(
                pointCount: _measurePoints.length,
                distanceM: _measureDistanceM,
                onClear: () => setState(() => _measurePoints.clear()),
                onUndo: _measurePoints.isNotEmpty
                    ? () => setState(() => _measurePoints.removeLast())
                    : null,
              ),
            ),

          // ── Top-left label ─────────────────────────────────────────────
          Positioned(
            top: topPad + 10,
            left: 14,
            child: Row(
              children: [
                const _MapLabel(is3D: false),
                const SizedBox(width: 12),
                if (weather.currentWeather != null)
                  _WeatherSummaryPill(weather: weather),
              ],
            ),
          ),

          // ── Offline / GPS hint banner ──────────────────────────────────
          if (_isOffline || _gpsHint != null)
            Positioned(
              top: topPad + 62,
              left: 14,
              right: 14,
              child: _MapBanner(
                text: _gpsHint ??
                    (appState.offlineRegionReady
                        ? 'Offline mode: cached tiles available.'
                        : 'Offline mode: download maps before heading out.'),
                actionLabel: _gpsHint != null
                    ? 'Settings'
                    : appState.offlineRegionReady
                        ? null
                        : 'Download',
                onAction: _gpsHint != null
                    ? LocationService.openSettings
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OfflineDownloadScreen(),
                          ),
                        ),
              ),
            ),

          // ── FAB column (top-right) ─────────────────────────────────────
          Positioned(
            right: 14, top: topPad + 10, bottom: 120,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _MapFab(
                    icon: _gpsActive ? Icons.gps_fixed : Icons.gps_not_fixed,
                    active: _gpsActive,
                    tooltip: _gpsActive ? 'GPS on' : 'GPS off',
                    onTap: _toggleGps,
                  ),
                  const SizedBox(height: 8),
                  _MapFab(
                    icon: Icons.fit_screen_outlined,
                    tooltip: 'Fit all trails',
                    onTap: _fitAll,
                  ),
                  const SizedBox(height: 8),
                  _MapFab(
                    icon: _showCaves ? Icons.visibility : Icons.visibility_off,
                    active: _showCaves,
                    tooltip: _showCaves ? 'Hide caves' : 'Show caves',
                    onTap: () => setState(() => _showCaves = !_showCaves),
                  ),
                  const SizedBox(height: 8),
                  _MapFab(
                    icon: _showIncidents
                        ? Icons.report_problem
                        : Icons.report_problem_outlined,
                    active: _showIncidents,
                    tooltip:
                        _showIncidents ? 'Hide incidents' : 'Show incidents',
                    onTap: () =>
                        setState(() => _showIncidents = !_showIncidents),
                  ),
                  const SizedBox(height: 8),
                  _MapFab(
                    icon: context.watch<AppStateProvider>().showAccommodation
                        ? Icons.hotel
                        : Icons.hotel_outlined,
                    active: context.watch<AppStateProvider>().showAccommodation,
                    tooltip: context.watch<AppStateProvider>().showAccommodation
                        ? 'Hide lodging'
                        : 'Show lodging',
                    onTap: () {
                      final prov = context.read<AppStateProvider>();
                      prov.setShowAccommodation(!prov.showAccommodation);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Style FAB removed as it's now part of the Cycle Pill
                  const SizedBox(height: 8),
                  _MapFab(
                    icon: Icons.straighten,
                    active: _measureMode,
                    tooltip:
                        _measureMode ? 'Exit measure mode' : 'Measure distance',
                    onTap: _toggleMeasureMode,
                  ),
                  const SizedBox(height: 8),
                  _MapFab(
                    icon: Icons.warning_amber_rounded,
                    active: _incidentMode,
                    tooltip: _incidentMode
                        ? 'Cancel intel report'
                        : 'Report field intel',
                    onTap: _toggleIncidentMode,
                  ),
                  const SizedBox(height: 8),
                  _MapFab(
                    icon: Icons.download_for_offline,
                    tooltip: 'Offline maps',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OfflineDownloadScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Selected trail info card ───────────────────────────────────
          ),

          if (selected != null)
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: _TrailInfoCard(
                trail: selected,
                onDetail: () => _openDetail(selected),
                onClose: () {
                  HapticFeedback.lightImpact();
                  context.read<StaticDataProvider>().selectTrail(null);
                },
              ),
            ),

          // ── Mode Toggle Pill (Bottom Center) ──────────────
          if (!_show3D && selected == null)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapModeCycle(
                      is3D: _show3D,
                      tileStyleIndex: _tileStyleIndex,
                      onCycle: _cycleMapMode,
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showTrailPicker(context),
                      child: widgets.Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: kColorBg.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: kColorOrange.withOpacity(0.5)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 10)
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.terrain,
                                color: kColorOrange, size: 16),
                            const SizedBox(width: 8),
                            Text('TRAILS',
                                style: GoogleFonts.outfit(
                                    color: kColorCream,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showTrailPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kColorBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => TrailsTab(
        embedded: true,
        onNavigateToMap: () {},
      ),
    );
  }
}

// ── Supporting widgets ──────────────────────────────────────────────────────

class _MapLabel extends StatelessWidget {
  final bool is3D;
  const _MapLabel({this.is3D = false});

  @override
  Widget build(BuildContext context) => widgets.Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kColorBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              is3D ? Icons.public : Icons.terrain,
              color: kColorOrange,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              is3D ? '3D Trail Map' : 'Trail Map',
              style: GoogleFonts.outfit(
                  color: kColorCream,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

class _TrailInfoCard extends StatelessWidget {
  final Trail trail;
  final VoidCallback onDetail;
  final VoidCallback onClose;
  const _TrailInfoCard({
    required this.trail,
    required this.onDetail,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        ),
        child: GlassPanel(
          padding: const EdgeInsets.all(14),
          opacity: 0.9,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: Text(trail.name,
                      style: GoogleFonts.outfit(
                          color: kColorCream,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                DifficultyBadge(trail.difficulty),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close,
                      color: kColorCream.withOpacity(0.4), size: 18),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _Stat(Icons.straighten,
                    units.formatDistance(trail.distanceKm)),
                const SizedBox(width: 12),
                _Stat(Icons.trending_up, units.formatElevation(trail.elevationGainM.toDouble())),
                const SizedBox(width: 12),
                _Stat(Icons.schedule, trail.formattedTime(1.0)),
                const Spacer(),
                GestureDetector(
                  onTap: onDetail,
                  child: widgets.Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: kColorOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('View Details',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Stat(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kColorCream.withOpacity(0.35), size: 12),
          const SizedBox(width: 3),
          Text(text,
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.55), fontSize: 11)),
        ],
      );
}

// ── Tile style cycle button ─────────────────────────────────────────────────
// _TileStyleFab removed as it's now part of the Cycle Pill

class _MapFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active ? kColorOrange.withOpacity(0.2) : kColorPanel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? kColorOrange : kColorBorder),
            ),
            child: Icon(icon,
                color: active ? kColorOrange : kColorCream.withOpacity(0.7),
                size: 20),
          ),
        ),
      );
}

// ── Incident mode banner ───────────────────────────────────────────────────
class _IncidentModeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => widgets.Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935).withOpacity(0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap anywhere on the map to place an incident report',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _MapBanner extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _MapBanner({
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => widgets.Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kColorBorder),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, color: kColorOrange, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.7), fontSize: 12)),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () => onAction!.call(),
              child: Text(actionLabel!),
            ),
        ]),
      );
}

// ── Recording Dashboard ────────────────────────────────────────────────────
class _RecordingDashboard extends StatelessWidget {
  final RecordingProvider rec;
  const _RecordingDashboard({required this.rec});

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TeamTrackingProvider>();
    final lastReport = tracking.lastReportAt;
    final isStale = lastReport == null ||
        DateTime.now().difference(lastReport).inSeconds > 45;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LiveTrackingScreen())),
      child: widgets.Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kColorOrange.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Column(
              children: [
                const Icon(Icons.fiber_manual_record,
                    color: Colors.red, size: 14),
                const SizedBox(height: 4),
                Icon(
                  lastReport == null ? Icons.cloud_off : Icons.cloud_done,
                  color: isStale ? Colors.grey : Colors.greenAccent,
                  size: 12,
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('RECORDING ACTIVE',
                          style: GoogleFonts.outfit(
                              color: kColorOrange,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                      const Spacer(),
                      if (lastReport != null)
                        Text(
                          'TELEMETRY: ${isStale ? "STALE" : "LIVE"}',
                          style: GoogleFonts.outfit(
                            color: isStale ? Colors.grey : Colors.greenAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  Text(
                      '${rec.distanceKm.toStringAsFixed(2)}km · ${rec.duration.inMinutes}m',
                      style: GoogleFonts.outfit(
                          color: kColorCream,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: kColorCream.withOpacity(0.3), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Measure mode banner ────────────────────────────────────────────────────
class _MeasureBanner extends StatelessWidget {
  final int pointCount;
  final double distanceM;
  final VoidCallback onClear;
  final VoidCallback? onUndo;

  const _MeasureBanner({
    required this.pointCount,
    required this.distanceM,
    required this.onClear,
    this.onUndo,
  });

  String _distLabel(UnitsProvider units) {
    final km = distanceM / 1000.0;
    if (distanceM < 1000) {
      // Use elevation formatter for short distances (m/ft) — same scale.
      return units.formatElevation(distanceM);
    }
    return units.formatDistance(km, decimals: 2);
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    return widgets.Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF00BCD4).withOpacity(0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.straighten, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pointCount < 2
                        ? 'Tap the map to start measuring'
                        : _distLabel(units),
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                  if (pointCount > 0)
                    Text(
                        '$pointCount point${pointCount == 1 ? '' : 's'} · tap to add more',
                        style: GoogleFonts.outfit(
                            color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            if (onUndo != null)
              GestureDetector(
                onTap: onUndo,
                child: widgets.Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.undo, color: Colors.white, size: 16),
                ),
              ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: widgets.Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      );
  }
}

class _MapModeCycle extends StatelessWidget {
  final bool is3D;
  final int tileStyleIndex;
  final VoidCallback onCycle;

  const _MapModeCycle({
    required this.is3D,
    required this.tileStyleIndex,
    required this.onCycle,
  });

  @override
  Widget build(BuildContext context) {
    String label = '2D OUTDOOR';
    IconData icon = Icons.map;
    if (is3D) {
      label = '3D TERRAIN';
      icon = Icons.layers;
    } else if (tileStyleIndex == 1) {
      label = '2D SATELLITE';
      icon = Icons.satellite_alt;
    }

    return GestureDetector(
      onTap: onCycle,
      child: widgets.Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: kColorBg.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kColorOrange.withOpacity(0.5)),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kColorOrange, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.outfit(
                    color: kColorCream,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _WeatherSummaryPill extends StatelessWidget {
  final WeatherProvider weather;
  const _WeatherSummaryPill({required this.weather});

  @override
  Widget build(BuildContext context) {
    final cur = weather.currentWeather?.current;
    if (cur == null) return const SizedBox.shrink();
    final units = context.watch<UnitsProvider>();

    return widgets.Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getWeatherIcon(cur.weatherCode),
            color: kColorOrange,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            units.formatTemperature(cur.temperature),
            style: GoogleFonts.outfit(
              color: kColorCream,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _getWeatherDesc(cur.weatherCode),
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.5),
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code <= 3) return Icons.wb_cloudy_outlined;
    if (code <= 48) return Icons.foggy;
    if (code <= 67) return Icons.umbrella_outlined;
    if (code <= 77) return Icons.ac_unit;
    if (code <= 82) return Icons.water_drop_outlined;
    if (code <= 99) return Icons.thunderstorm_outlined;
    return Icons.wb_sunny_outlined;
  }

  String _getWeatherDesc(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    if (code <= 82) return 'Showers';
    if (code <= 99) return 'Storm';
    return 'Fair';
  }
}
