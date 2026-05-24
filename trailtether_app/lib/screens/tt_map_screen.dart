// Trailtether 2.0 — Map / Peak Tracker screen.
//
// Real flutter_map backed implementation that keeps the v3.0 visual treatment
// (floating glass stat cards, ember route polyline, bottom RecordingPanel)
// but drives all data through the live providers: RecordingProvider (active
// trail / stats / points), StaticDataProvider (route overlays), and the
// OfflineMapService tile provider for cached tiles.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/accommodation.dart';
import '../models/cave_waypoint.dart';
import '../models/recording_point.dart';
import '../models/trail.dart';
import '../providers/recording_provider.dart';
import '../providers/static_data_provider.dart';
import '../providers/units_provider.dart';
import '../services/location_service.dart';
import '../services/offline_map_service.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/start_hike_ramp.dart';
import '../models/incident.dart';
import '../providers/safety_provider.dart';
import '../widgets/map/accommodation_marker_layer.dart';
import '../widgets/map/cave_marker_layer.dart';
import '../widgets/map/incident_marker_layer.dart';
import '../widgets/map/trail_map_3d_selector.dart';
import 'accommodation_detail_sheet.dart';
import 'cave_detail_sheet.dart';
import 'field_intel_sheet.dart';
import 'incident_detail_sheet.dart';
import 'recorded_trails_screen.dart';
import 'trail_detail_screen.dart';

class TTMapScreen extends StatefulWidget {
  final bool embedded;
  const TTMapScreen({super.key, this.embedded = false});

  @override
  State<TTMapScreen> createState() => _TTMapScreenState();
}

class _TTMapScreenState extends State<TTMapScreen>
    with TickerProviderStateMixin {
  // Live flutter_map controller.
  final MapController _mapCtrl = MapController();

  // Tile style index into kMapTileStyles.
  int _tileStyleIndex = 0; // 0 = Outdoor / OpenTopoMap

  // Night-map overlay toggle (uses Stadia dark tiles under a red filter).
  bool _nightMap = false;

  // Live GPS position (drives the user marker + recenter).
  LatLng? _currentLatLng;
  double? _currentHeading;
  StreamSubscription<Position>? _positionSub;

  // Drives the route draw + panel entry anim.
  late final AnimationController _entryCtl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  // Drives the DraggableScrollableSheet from the grab-handle tap so users on
  // smaller screens can pop the panel open without dragging.
  final DraggableScrollableController _sheetCtl =
      DraggableScrollableController();
  static const double _sheetMin = 0.32;
  static const double _sheetMid = 0.52;
  static const double _sheetMax = 0.92;

  // Unit toggle is owned by UnitsProvider so the choice is global.
  bool get _useMiles => context.read<UnitsProvider>().isImperial;

  // "Drop a pin" mode — when true the next tap on the map opens the field-
  // intel sheet at the tapped coordinate so the user can mark a hazard,
  // shelter, water source, etc. Auto-clears after a single drop.
  bool _dropPinMode = false;

  // 3D mode — switches the FlutterMap view for a WebView-backed 3D scene
  // (MapLibre GL JS rendering Esri satellite tiles over a terrain mesh).
  // The 3D widget receives the same trails / caves / incidents stream so
  // taps still route to the existing detail sheets.
  bool _show3D = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryCtl.forward();
    });
    _startLocationStream();
  }

  Future<void> _startLocationStream() async {
    final ok = await LocationService.requestPermission();
    if (!ok) return;
    _positionSub = LocationService.smoothedPositionStream.listen(
      (pos) {
        if (!mounted) return;
        setState(() {
          _currentLatLng = LatLng(pos.latitude, pos.longitude);
          _currentHeading = pos.heading;
        });
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _entryCtl.dispose();
    _positionSub?.cancel();
    _sheetCtl.dispose();
    super.dispose();
  }

  // ── Map control handlers ───────────────────────────────────────────────────
  void _zoomIn() {
    final z = _mapCtrl.camera.zoom;
    _mapCtrl.move(_mapCtrl.camera.center, (z + 1).clamp(2.0, 20.0));
  }

  void _zoomOut() {
    final z = _mapCtrl.camera.zoom;
    _mapCtrl.move(_mapCtrl.camera.center, (z - 1).clamp(2.0, 20.0));
  }

  void _recenter() {
    final p = _currentLatLng;
    if (p != null) {
      _mapCtrl.move(p, math.max(_mapCtrl.camera.zoom, 14.0));
    } else {
      _mapCtrl.move(LatLng(kWorldMapCenter.lat, kWorldMapCenter.lon),
          kWorldMapZoomInit);
    }
  }

  void _openLayerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TT.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Text('MAP STYLE',
                  style: TT.label(size: 11, color: TT.text2, letterSpacing: 1.6)),
              const SizedBox(height: 10),
              for (var i = 0; i < kMapTileStyles.length; i++)
                _LayerOption(
                  label: kMapTileStyles[i].label,
                  iconLabel: kMapTileStyles[i].iconLabel,
                  selected: i == _tileStyleIndex,
                  onTap: () {
                    setState(() => _tileStyleIndex = i);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top-bar actions ────────────────────────────────────────────────────────

  Future<void> _openSearch() async {
    final trails = context.read<StaticDataProvider>().allTrails;
    final picked = await showSearch<Trail?>(
      context: context,
      delegate: _TrailSearchDelegate(trails),
    );
    if (picked == null || !mounted) return;
    // Push trail detail so users can review the route, elevation, and reviews
    // before committing — the detail screen's "START HIKE" CTA pops back and
    // wires the trail into RecordingProvider. If the user just wants to see
    // where it is on the map, they can dismiss the sheet and the focusTrail()
    // call below still moves the camera to the route's bounds.
    _focusTrail(picked, withSnackbar: false);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TrailDetailScreen(
        trail: picked,
        onNavigateToMap: () {
          // Already on the Map tab — popping back to here is enough; no
          // additional tab switch is needed.
        },
      ),
    ));
  }

  void _focusTrail(Trail trail, {bool withSnackbar = true}) {
    if (trail.coords.isEmpty) return;
    if (trail.coords.length == 1) {
      final c = trail.coords.first;
      _mapCtrl.move(LatLng(c.lat, c.lon), 14);
      return;
    }
    _mapCtrl.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(trail.minLat, trail.minLon),
          LatLng(trail.maxLat, trail.maxLon),
        ),
        padding: const EdgeInsets.fromLTRB(40, 120, 40, 240),
      ),
    );
    if (!withSnackbar) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: TT.surf,
          content: Text(
            'Centered on ${trail.name}',
            style: TT.body(size: 13),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TT.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Text('MAP ACTIONS',
                  style: TT.label(size: 11, color: TT.text2, letterSpacing: 1.6)),
              const SizedBox(height: 10),
              _MenuRow(
                icon: Icons.gps_fixed,
                label: 'Recenter on me',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _recenter();
                },
              ),
              _MenuRow(
                icon: _nightMap ? Icons.nightlight_round : Icons.nightlight_outlined,
                label: _nightMap ? 'Disable night map' : 'Enable night map',
                ember: _nightMap,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  setState(() => _nightMap = !_nightMap);
                },
              ),
              _MenuRow(
                icon: Icons.layers_outlined,
                label: 'Switch tile style',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _openLayerSheet();
                },
              ),
              _MenuRow(
                icon: Icons.straighten,
                label: _useMiles ? 'Show distance in km' : 'Show distance in mi',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  context.read<UnitsProvider>().toggle();
                },
              ),
              _MenuRow(
                icon: Icons.alt_route_outlined,
                label: 'My recorded trails',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RecordedTrailsScreen(),
                  ));
                },
              ),
              _MenuRow(
                icon: _dropPinMode
                    ? Icons.add_location_alt
                    : Icons.add_location_alt_outlined,
                label: _dropPinMode
                    ? 'Cancel drop pin'
                    : 'Drop pin / mark feature',
                ember: _dropPinMode,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _toggleDropPinMode();
                },
              ),
              _MenuRow(
                icon: _show3D
                    ? Icons.map_outlined
                    : Icons.public_outlined,
                label: _show3D ? 'Switch to 2D map' : 'Switch to 3D map',
                ember: _show3D,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _toggle3D();
                },
              ),
              _MenuRow(
                icon: Icons.download_for_offline_outlined,
                label: 'Cached offline maps',
                trailing: 'view',
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await _showOfflineInfo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOfflineInfo() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: TT.bg2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TT.rLg)),
        title: Text('Offline tile cache', style: TT.title(16)),
        content: Text(
          'Trailtether caches map tiles for the regions you have viewed so you '
          'have a working map when you lose signal on the trail. Clearing the '
          'cache frees space but you will need data to reload tiles.',
          style: TT.body(size: 13, color: TT.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: Text('Close',
                style: TT.body(size: 13, color: TT.text2, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () async {
              await OfflineMapService.clearCache();
              if (!dCtx.mounted) return;
              Navigator.of(dCtx).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: TT.surf,
                  content: Text('Offline tile cache cleared.',
                      style: TT.body(size: 13)),
                ),
              );
            },
            child: Text('Clear cache',
                style: TT.body(size: 13, color: TT.ember, w: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _toggleUnits() {
    context.read<UnitsProvider>().toggle();
  }

  // ── Drop a pin / mark a feature ──────────────────────────────────────────
  //
  // Enter drop-pin mode → the next map tap opens the FieldIntelSheet so the
  // user can record an incident, hazard, water source, etc. at that GPS.
  // The mode auto-clears on submission OR cancellation so the user doesn't
  // accidentally drop a second pin afterwards.
  void _toggleDropPinMode() {
    setState(() => _dropPinMode = !_dropPinMode);
    if (_dropPinMode) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: TT.surf,
            content: Text(
              'Tap the map where you want to drop a pin',
              style: TT.body(size: 13),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  Trail? _findNearestTrail(LatLng pos) {
    final trails = context.read<StaticDataProvider>().allTrails;
    Trail? nearest;
    double bestMeters = double.infinity;
    const slack = 0.015;
    for (final t in trails) {
      if (pos.latitude < t.minLat - slack ||
          pos.latitude > t.maxLat + slack ||
          pos.longitude < t.minLon - slack ||
          pos.longitude > t.maxLon + slack) {
        continue;
      }
      for (final c in t.coords) {
        final d = _haversineMeters(pos, LatLng(c.lat, c.lon));
        if (d < bestMeters) {
          bestMeters = d;
          nearest = t;
        }
      }
    }
    return (bestMeters < 1200) ? nearest : null;
  }

  Future<void> _onDropPinAt(LatLng latLng) async {
    if (!_dropPinMode) return;
    setState(() => _dropPinMode = false);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FieldIntelSheet(
        position: latLng,
        nearestTrail: _findNearestTrail(latLng),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xCC4CC38A),
          content: Text(
            'Field intel reported — thanks for keeping the team safe.',
            style: TT.body(size: 13, color: Colors.white),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _openIncident(Incident incident) {
    IncidentDetailSheet.show(context, incident);
  }

  void _toggle3D() {
    setState(() => _show3D = !_show3D);
  }

  void _openCaveOnRoot(CaveWaypoint cave) {
    CaveDetailSheet.show(context, cave);
  }

  // Picks up the trail by id when the 3D widget reports a tap. The 3D
  // WebView only knows trail IDs, so the host has to resolve them.
  void _openTrailById(String id) {
    final trails = context.read<StaticDataProvider>().allTrails;
    Trail? trail;
    for (final t in trails) {
      if (t.id == id) {
        trail = t;
        break;
      }
    }
    if (trail == null || trail.coords.isEmpty) return;
    final picked = trail;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TrailDetailScreen(
        trail: picked,
        onNavigateToMap: () {},
      ),
    ));
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final sLat = math.sin(dLat / 2);
    final sLon = math.sin(dLon / 2);
    final h = sLat * sLat +
        math.cos(a.latitude * math.pi / 180.0) *
            math.cos(b.latitude * math.pi / 180.0) *
            sLon *
            sLon;
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
  }

  void _toggleSheet() {
    if (!_sheetCtl.isAttached) return;
    final size = _sheetCtl.size;
    final target = size > (_sheetMid + 0.04) ? _sheetMin : _sheetMax;
    _sheetCtl.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: TT.easeOut,
    );
  }

  // ── Stat-card popovers ─────────────────────────────────────────────────────
  void _showDistanceBreakdown() {
    final rec = context.read<RecordingProvider>();
    final hike = _safeHikeSnapshot(rec);
    _presentBreakdown(
      title: 'Distance breakdown',
      rows: [
        _BreakRow(label: 'Total distance', value: _formatDist(rec.distanceKm)),
        _BreakRow(
            label: 'Moving distance',
            value: _formatDist(hike?.movingDistanceKm ?? rec.distanceKm)),
        _BreakRow(label: 'Max speed', value: _formatSpeed(hike?.maxSpeedKmh)),
        _BreakRow(
            label: 'Avg speed', value: _formatSpeed(rec.averageSpeedKmh)),
        _BreakRow(
            label: 'Elevation gain', value: '${rec.totalGainM.toString()} m'),
      ],
    );
  }

  void _showTimeBreakdown() {
    final rec = context.read<RecordingProvider>();
    final hike = _safeHikeSnapshot(rec);
    final paceMinPerKm = rec.averageSpeedKmh > 0.1
        ? (60.0 / rec.averageSpeedKmh)
        : null;
    _presentBreakdown(
      title: 'Time breakdown',
      rows: [
        _BreakRow(label: 'Elapsed', value: _formatDurationLong(rec.duration)),
        _BreakRow(
            label: 'Moving time',
            value: _formatDurationLong(
                Duration(seconds: hike?.movingSeconds ?? rec.duration.inSeconds))),
        _BreakRow(
            label: 'Avg pace',
            value: paceMinPerKm == null
                ? '—'
                : '${paceMinPerKm.toStringAsFixed(1)} min/km'),
        _BreakRow(
            label: 'Avg speed', value: _formatSpeed(rec.averageSpeedKmh)),
      ],
    );
  }

  /// Builds a lightweight derived stat snapshot from the recording without
  /// requiring the recording to be saved. Returns `null` when there isn't
  /// enough data to compute anything beyond the live counters.
  _HikeSnapshot? _safeHikeSnapshot(RecordingProvider rec) {
    if (rec.points.length < 2) return null;
    final pts = rec.points;
    var movingMs = 0;
    var movingDistM = 0.0;
    var maxSpeedKmh = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final dt = b.timestamp.difference(a.timestamp);
      if (dt <= Duration.zero) continue;
      final dist = Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      final speedMps = dist / dt.inMilliseconds * 1000.0;
      final speedKmh = speedMps * 3.6;
      if (speedKmh > maxSpeedKmh) maxSpeedKmh = speedKmh;
      if (speedMps >= 0.25) {
        movingMs += dt.inMilliseconds;
        movingDistM += dist;
      }
    }
    return _HikeSnapshot(
      movingSeconds: movingMs ~/ 1000,
      movingDistanceKm: movingDistM / 1000.0,
      maxSpeedKmh: maxSpeedKmh,
    );
  }

  void _presentBreakdown({required String title, required List<_BreakRow> rows}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TT.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Text(title.toUpperCase(),
                  style: TT.label(
                      size: 11, color: TT.text2, letterSpacing: 1.6)),
              const SizedBox(height: 12),
              TTCard(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      _BreakRowView(row: rows[i]),
                      if (i != rows.length - 1)
                        Container(
                          height: 1,
                          color: TT.line,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDist(double km) {
    if (_useMiles) {
      final mi = km * 0.621371;
      if (mi < 10) return '${mi.toStringAsFixed(2)} mi';
      return '${mi.toStringAsFixed(1)} mi';
    }
    if (km < 10) return '${km.toStringAsFixed(2)} km';
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatDistValueOnly(double km) {
    if (_useMiles) {
      final mi = km * 0.621371;
      if (mi < 10) return mi.toStringAsFixed(2);
      return mi.toStringAsFixed(1);
    }
    if (km < 10) return km.toStringAsFixed(2);
    return km.toStringAsFixed(1);
  }

  String _formatSpeed(double? kmh) {
    if (kmh == null || kmh <= 0) return '—';
    if (_useMiles) {
      return '${(kmh * 0.621371).toStringAsFixed(1)} mph';
    }
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  // ── Recording actions ──────────────────────────────────────────────────────
  // Recording always begins via [StartHikeRamp] — a deliberate slide-to-
  // confirm + 3-second countdown so a mistapped Start never silently
  // records a hike. The ramp returns true on confirm; on cancel we no-op.
  Future<void> _startRecording() async {
    final confirmed = await StartHikeRamp.show(context);
    if (!confirmed || !mounted) return;
    final rec = context.read<RecordingProvider>();
    final ok = await rec.start();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location permission required to start recording.')),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Watch UnitsProvider so the whole map screen rebuilds when the user
    // flips units globally (from this screen, the profile, or anywhere else).
    context.watch<UnitsProvider>();
    // The body is a Stack: map fills the whole area, and a
    // DraggableScrollableSheet sits on top so users can pull it up to see the
    // elevation chart at full size.
    final body = SafeArea(
      top: !widget.embedded,
      bottom: false,
      child: Column(
        children: [
          TTPageAppBar(
            title: 'Peak Tracker',
            trailing: [
              TTIconBtn(icon: Icons.search, onTap: _openSearch),
              TTIconBtn(icon: Icons.menu, onTap: _openMenu),
            ],
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_show3D)
                  Consumer3<StaticDataProvider, RecordingProvider, SafetyProvider>(
                    builder: (_, statics, recording, safety, __) {
                      return TrailMap3DWidget(
                        trails: statics.allTrails,
                        selectedTrail: statics.selectedTrail,
                        onTrailTap: _openTrailById,
                        caves: statics.caves,
                        onCaveTap: (c) => _openCaveOnRoot(c),
                        incidents: safety.incidents,
                        onIncidentTap: _openIncident,
                        gpsLat: _currentLatLng?.latitude,
                        gpsLon: _currentLatLng?.longitude,
                        bearing: _currentHeading,
                        useTopoStyle: false,
                        recordingPoints: recording.points,
                        initialLat: _currentLatLng?.latitude ??
                            kWorldMapCenter.lat,
                        initialLon: _currentLatLng?.longitude ??
                            kWorldMapCenter.lon,
                        initialZoom: 13,
                      );
                    },
                  )
                else
                  _MapView(
                    mapCtrl: _mapCtrl,
                    tileStyleIndex: _tileStyleIndex,
                    nightMap: _nightMap,
                    currentLatLng: _currentLatLng,
                    currentHeading: _currentHeading,
                    entryCtl: _entryCtl,
                    useMiles: _useMiles,
                    formatDistValueOnly: _formatDistValueOnly,
                    unitLabel: _useMiles ? 'mi' : 'km',
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                    onRecenter: _recenter,
                    onOpenLayers: _openLayerSheet,
                    onToggleUnits: _toggleUnits,
                    onTapDistance: _showDistanceBreakdown,
                    onTapTime: _showTimeBreakdown,
                    dropPinMode: _dropPinMode,
                    onDropPin: _onDropPinAt,
                    onIncidentTap: _openIncident,
                  ),
                // Floating "3D ON" pill so the user always knows which
                // view they're in and can flip back without diving into
                // the menu sheet.
                if (_show3D)
                  Positioned(
                    top: 12,
                    right: 14,
                    child: _ModePill(
                      label: '3D ON',
                      onTap: _toggle3D,
                    ),
                  ),
                // Persistent overlay banner while drop-pin mode is active
                // so the user knows the next tap will land a pin. Tap the
                // X to cancel without leaving the screen.
                if (_dropPinMode)
                  Positioned(
                    top: 12,
                    left: 14,
                    right: 14,
                    child: _DropPinBanner(onCancel: _toggleDropPinMode),
                  ),
                DraggableScrollableSheet(
                  controller: _sheetCtl,
                  initialChildSize: _sheetMin,
                  minChildSize: _sheetMin,
                  maxChildSize: _sheetMax,
                  snap: true,
                  snapSizes: const [_sheetMin, _sheetMid, _sheetMax],
                  builder: (_, scrollCtl) => _RecordingPanel(
                    entryCtl: _entryCtl,
                    scrollCtl: scrollCtl,
                    useMiles: _useMiles,
                    formatDistValueOnly: _formatDistValueOnly,
                    formatSpeed: _formatSpeed,
                    onStart: _startRecording,
                    onHandleTap: _toggleSheet,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

// ───────────────────────────── MAP VIEW ──────────────────────────────────────

class _MapView extends StatelessWidget {
  final MapController mapCtrl;
  final int tileStyleIndex;
  final bool nightMap;
  final LatLng? currentLatLng;
  final double? currentHeading;
  final AnimationController entryCtl;
  final bool useMiles;
  final String Function(double km) formatDistValueOnly;
  final String unitLabel;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;
  final VoidCallback onOpenLayers;
  final VoidCallback onToggleUnits;
  final VoidCallback onTapDistance;
  final VoidCallback onTapTime;
  final bool dropPinMode;
  final void Function(LatLng) onDropPin;
  final void Function(Incident) onIncidentTap;

  const _MapView({
    required this.mapCtrl,
    required this.tileStyleIndex,
    required this.nightMap,
    required this.currentLatLng,
    required this.currentHeading,
    required this.entryCtl,
    required this.useMiles,
    required this.formatDistValueOnly,
    required this.unitLabel,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    required this.onOpenLayers,
    required this.onToggleUnits,
    required this.onTapDistance,
    required this.onTapTime,
    required this.dropPinMode,
    required this.onDropPin,
    required this.onIncidentTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StaticDataProvider>();
    final recording = context.watch<RecordingProvider>();
    final selectedId = data.selectedTrail?.id;

    final style = kMapTileStyles[tileStyleIndex.clamp(0, kMapTileStyles.length - 1)];
    final tileUrl = nightMap ? kNightTileUrl : style.url;
    final tileMaxZoom = nightMap ? 20.0 : style.maxZoom;

    // ── Polylines ──
    final polylines = <Polyline>[];

    // All known trails — drawn at full ember at normal opacity so they're
    // visible against the satellite tiles. The previously-selected trail
    // (if any) is drawn last and brighter so it stands out from the herd.
    Polyline? selectedPolyline;
    for (final t in data.allTrails) {
      if (t.coords.isEmpty) continue;
      final pts = t.coords.map((c) => LatLng(c.lat, c.lon)).toList();
      final isSelected = t.id == selectedId;
      final line = Polyline(
        points: pts,
        color: isSelected ? TT.ember : const Color(0xCCFF6A2C),
        strokeWidth: isSelected ? 4.5 : 2.6,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      );
      if (isSelected) {
        selectedPolyline = line;
      } else {
        polylines.add(line);
      }
    }
    if (selectedPolyline != null) polylines.add(selectedPolyline);

    // Active recording route — ember glow + sharp stroke.
    if (recording.points.length >= 2) {
      final recPts = recording.points.map((p) => p.toLatLng).toList();
      polylines.add(Polyline(
        points: recPts,
        color: const Color(0x66FF6A2C),
        strokeWidth: 8.0,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));
      polylines.add(Polyline(
        points: recPts,
        color: TT.ember,
        strokeWidth: 3.5,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));
    }

    // ── Markers ──
    final markers = <Marker>[];

    // Recording start dot.
    if (recording.points.isNotEmpty) {
      final start = recording.points.first.toLatLng;
      markers.add(Marker(
        point: start,
        width: 18,
        height: 18,
        child: const _StartDot(),
      ));
    }

    // User position pulse.
    if (currentLatLng != null) {
      markers.add(Marker(
        point: currentLatLng!,
        width: 56,
        height: 56,
        child: _YouMarker(heading: currentHeading),
      ));
    }

    final mapStack = Stack(
      fit: StackFit.expand,
      children: [
        // Real map underlay.
        AnimatedBuilder(
          animation: entryCtl,
          builder: (_, child) {
            final t = TT.easeOut.transform(entryCtl.value);
            return Opacity(opacity: 0.4 + 0.6 * t, child: child);
          },
          child: FlutterMap(
            mapController: mapCtrl,
            options: MapOptions(
              initialCenter: currentLatLng ??
                  LatLng(kWorldMapCenter.lat, kWorldMapCenter.lon),
              initialZoom: kWorldMapZoomInit,
              minZoom: 2,
              maxZoom: 20,
              backgroundColor: const Color(0xFF06080B),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
                enableMultiFingerGestureRace: true,
              ),
              // Tap on the map → find the nearest trail line within a
              // ~150 m proximity radius and open its detail sheet, so users
              // can poke a route on the map to see what it is.
              onTap: (_, latLng) => _handleMapTap(context, latLng),
            ),
            children: [
              TileLayer(
                key: ValueKey('tile_${nightMap ? 'night' : tileStyleIndex}'),
                urlTemplate: tileUrl,
                tileProvider: OfflineMapService.tileProvider(),
                userAgentPackageName: 'com.trailtether.app',
                maxZoom: tileMaxZoom,
                retinaMode: kHighDensity(context),
              ),
              PolylineLayer(polylines: polylines),
              // Accommodation pins (hotels, lodges, camps) — always on.
              AccommodationMarkerLayer(
                onTap: (acc) => _openAccommodation(context, acc),
              ),
              // Cave + shelter pins (125 surveyed waypoints) — always on.
              // Tap a pin to open the cave detail sheet with name, GPS, and
              // any linked trails that pass within 1 km of it.
              CaveMarkerLayer(
                onCaveTap: (cave) => _openCave(context, cave),
              ),
              // User-dropped intel pins (rockfall, weather, water source,
              // SOS). Pins flow in via SafetyProvider's Supabase stream so
              // everyone on the team sees a freshly-dropped pin in seconds.
              IncidentMarkerLayer(onIncidentTap: onIncidentTap),
              MarkerLayer(markers: markers),
            ],
          ),
        ),

        // Floating top stat cards.
        Positioned(
          top: 12,
          left: 14,
          right: 14,
          child: Row(
            children: [
              Expanded(
                child: _AnimUp(
                  delay: const Duration(milliseconds: 120),
                  child: _FloatingStat(
                    icon: Icons.navigation,
                    label: 'Distance',
                    value: formatDistValueOnly(recording.distanceKm),
                    unit: unitLabel,
                    sublabel: recording.isRecording
                        ? 'Recording'
                        : (recording.points.isEmpty ? 'No data' : 'Last hike'),
                    onTap: onTapDistance,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AnimUp(
                  delay: const Duration(milliseconds: 220),
                  child: _FloatingStat(
                    icon: Icons.schedule,
                    label: 'Time',
                    value: _formatDurationShort(recording.duration),
                    sublabel: 'Duration',
                    onTap: onTapTime,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right-side controls.
        Positioned(
          top: 152,
          right: 14,
          child: _MapControls(
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onRecenter: onRecenter,
            onOpenLayers: onOpenLayers,
          ),
        ),

        // Tile attribution / style label.
        Positioned(
          bottom: 14,
          left: 14,
          child: _AnimUp(
            delay: const Duration(milliseconds: 900),
            child: _ScaleBar(
              styleLabel: style.iconLabel,
              unitLabel: unitLabel,
              onTap: onToggleUnits,
            ),
          ),
        ),
      ],
    );

    final clipped = ClipRect(child: mapStack);
    if (!nightMap) return clipped;

    // Night-vision overlay: red ColorFiltered + dimmer underneath, applied to
    // the basemap rendering for a true preserve-night-vision look.
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 0.35, 0, 0, 0,
        0, 0, 0.25, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: clipped,
    );
  }

  // ── Tap-to-locate helpers ────────────────────────────────────────────────
  //
  // Map taps that aren't on a cave or accommodation pin run through here.
  // In drop-pin mode, the tap drops a field-intel pin at the GPS. Otherwise
  // we look at every loaded trail's coordinate list and pick the nearest
  // one within ~150 m of the tap, then push its detail sheet so the user
  // can see what they tapped. Nothing close enough → silent no-op (pan,
  // zoom, recenter still work).
  void _handleMapTap(BuildContext context, LatLng tap) {
    if (dropPinMode) {
      onDropPin(tap);
      return;
    }
    final trails = context.read<StaticDataProvider>().allTrails;
    Trail? nearest;
    double bestMeters = double.infinity;
    for (final t in trails) {
      if (t.coords.isEmpty) continue;
      const slack = 0.015; // ≈1.5 km at this latitude
      if (tap.latitude < t.minLat - slack ||
          tap.latitude > t.maxLat + slack ||
          tap.longitude < t.minLon - slack ||
          tap.longitude > t.maxLon + slack) {
        continue;
      }
      for (final c in t.coords) {
        final d = _haversineMeters(tap, LatLng(c.lat, c.lon));
        if (d < bestMeters) {
          bestMeters = d;
          nearest = t;
        }
      }
    }
    if (nearest == null || bestMeters > 150) return;
    final picked = nearest;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TrailDetailScreen(
        trail: picked,
        onNavigateToMap: () {},
      ),
    ));
  }

  void _openAccommodation(BuildContext context, Accommodation acc) {
    AccommodationDetailSheet.show(context, acc);
  }

  void _openCave(BuildContext context, CaveWaypoint cave) {
    CaveDetailSheet.show(context, cave);
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final sLat = math.sin(dLat / 2);
    final sLon = math.sin(dLon / 2);
    final h = sLat * sLat +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            sLon *
            sLon;
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}

// ──────────────────────────── MODE PILLS ─────────────────────────────────

/// Small ember pill that announces an active map mode (e.g. "3D ON") and
/// flips the mode off when tapped.
class _ModePill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ModePill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: TT.ember,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(color: Color(0xCCFF6A2C), blurRadius: 14, spreadRadius: -4),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TT
                    .mono(size: 11, color: TT.emberInk, w: FontWeight.w900)
                    .copyWith(letterSpacing: 0.14 * 11),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.close, size: 13, color: TT.emberInk),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── DROP-PIN BANNER ──────────────────────────────

class _DropPinBanner extends StatelessWidget {
  final VoidCallback onCancel;
  const _DropPinBanner({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: TT.surf.withOpacity(0.92),
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(color: TT.ember, width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x5CFF6A2C), blurRadius: 18, spreadRadius: -4),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.add_location_alt, color: TT.ember, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap the map to drop a pin',
                style: TT.body(
                    size: 13, w: FontWeight.w800, color: TT.text),
              ),
            ),
            InkResponse(
              radius: 18,
              onTap: onCancel,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, color: TT.text2, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────── MARKERS ──────────────────────────────────────

class _YouMarker extends StatefulWidget {
  final double? heading;
  const _YouMarker({this.heading});
  @override
  State<_YouMarker> createState() => _YouMarkerState();
}

class _YouMarkerState extends State<_YouMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

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
        final t = _pulse.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse.
            Opacity(
              opacity: (1 - t).clamp(0.0, 0.6),
              child: Transform.scale(
                scale: 0.7 + t * 1.4,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x33FF6A2C),
                  ),
                ),
              ),
            ),
            // Inner halo.
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x52FF6A2C),
              ),
            ),
            // Core dot.
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: TT.ember, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            // Heading arrow — only when the device reports a valid heading.
            if (widget.heading != null && widget.heading! >= 0)
              Transform.rotate(
                angle: (widget.heading! * math.pi / 180),
                child: const _HeadingArrow(),
              ),
          ],
        );
      },
    );
  }
}

class _HeadingArrow extends StatelessWidget {
  const _HeadingArrow();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(painter: _HeadingArrowPainter()),
    );
  }
}

class _HeadingArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final paint = Paint()
      ..color = TT.ember
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(cx, 2)
      ..lineTo(cx - 5, 12)
      ..lineTo(cx + 5, 12)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _StartDot extends StatelessWidget {
  const _StartDot();
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        decoration: BoxDecoration(
          color: TT.ember,
          border: Border.all(color: const Color(0xFF1A0D04), width: 2),
        ),
      ),
    );
  }
}

// ───────────────────────── FLOATING STAT CARDS ───────────────────────────────

class _FloatingStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? sublabel;
  final VoidCallback? onTap;

  const _FloatingStat({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.sublabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TTGlass(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x1AFF6A2C),
              border: Border.all(color: const Color(0x40FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(TT.rSm),
            ),
            child: Icon(icon, size: 14, color: TT.ember),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TT.body(size: 10, w: FontWeight.w600, color: TT.text3)
                      .copyWith(letterSpacing: 0.4),
                ),
                const SizedBox(height: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TT.numStyle(size: 17, letterSpacing: -0.02 * 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 3),
                      Text(unit!, style: TT.mono(size: 10, color: TT.text2)),
                    ],
                  ],
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    sublabel!,
                    style: TT.mono(size: 9.5, color: TT.text3, w: FontWeight.w500)
                        .copyWith(letterSpacing: 0.2),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── MAP CONTROLS ───────────────────────────────────

class _MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;
  final VoidCallback onOpenLayers;
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    required this.onOpenLayers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimPop(
          delay: const Duration(milliseconds: 420),
          child: _ZoomGroup(onZoomIn: onZoomIn, onZoomOut: onZoomOut),
        ),
        const SizedBox(height: 8),
        _AnimPop(
          delay: const Duration(milliseconds: 520),
          child: _CircleBtn(
            icon: Icons.gps_fixed,
            ember: true,
            onTap: onRecenter,
          ),
        ),
        const SizedBox(height: 8),
        _AnimPop(
          delay: const Duration(milliseconds: 580),
          child: _CircleBtn(
            icon: Icons.layers_outlined,
            onTap: onOpenLayers,
          ),
        ),
      ],
    );
  }
}

class _ZoomGroup extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  const _ZoomGroup({required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    return TTGlass(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(icon: Icons.add, onTap: onZoomIn),
          Container(width: 38, height: 1, color: TT.line2),
          _ZoomBtn(icon: Icons.remove, onTap: onZoomOut),
        ],
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 16, color: TT.text),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool ember;
  final VoidCallback onTap;
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return TTGlass(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 16, color: ember ? TT.ember : TT.text2),
      ),
    );
  }
}

// ─────────────────────────────── SCALE BAR ──────────────────────────────────

class _ScaleBar extends StatelessWidget {
  final String styleLabel;
  final String unitLabel;
  final VoidCallback onTap;
  const _ScaleBar({
    required this.styleLabel,
    required this.unitLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xC70A0C0F),
          border: Border.all(color: TT.line2, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 22, height: 4, color: TT.text),
            Container(
              width: 22,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0C0F),
                border: Border.all(color: TT.text, width: 1),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              styleLabel,
              style: TT.mono(size: 9.5, color: TT.text, w: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Container(width: 1, height: 10, color: TT.line2),
            const SizedBox(width: 6),
            Text(
              unitLabel.toUpperCase(),
              style: TT.mono(size: 9.5, color: TT.ember, w: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── LAYER SHEET ROW ───────────────────────────────────

class _LayerOption extends StatelessWidget {
  final String label;
  final String iconLabel;
  final bool selected;
  final VoidCallback onTap;
  const _LayerOption({
    required this.label,
    required this.iconLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0x14FF6A2C) : TT.surf,
          border: Border.all(
            color: selected ? const Color(0x66FF6A2C) : TT.line,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(TT.rMd),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TT.bg2,
                borderRadius: BorderRadius.circular(TT.rSm),
                border: Border.all(color: TT.line2),
              ),
              child: Text(
                iconLabel,
                style: TT.mono(size: 10, color: TT.ember, w: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TT.body(size: 14, w: FontWeight.w700)),
            ),
            if (selected) const Icon(Icons.check, size: 18, color: TT.ember),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── MENU SHEET ROW ────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool ember;
  final VoidCallback onTap;
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: TT.surf,
          border: Border.all(color: TT.line, width: 1),
          borderRadius: BorderRadius.circular(TT.rMd),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: ember ? TT.ember : TT.text2),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TT.body(size: 14, w: FontWeight.w700)),
            ),
            if (trailing != null)
              Text(trailing!,
                  style: TT.mono(size: 10, color: TT.text3, w: FontWeight.w700))
            else
              const Icon(Icons.chevron_right, size: 18, color: TT.text3),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── SHEET HANDLE ─────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  final VoidCallback? onTap;
  const _SheetHandle({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14, top: 2),
          decoration: BoxDecoration(
            color: TT.line3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── RECORDING PANEL ───────────────────────────────────

class _RecordingPanel extends StatelessWidget {
  final AnimationController entryCtl;
  final ScrollController scrollCtl;
  final bool useMiles;
  final String Function(double km) formatDistValueOnly;
  final String Function(double? kmh) formatSpeed;
  final Future<void> Function() onStart;
  final VoidCallback onHandleTap;

  const _RecordingPanel({
    required this.entryCtl,
    required this.scrollCtl,
    required this.useMiles,
    required this.formatDistValueOnly,
    required this.formatSpeed,
    required this.onStart,
    required this.onHandleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (_, recording, __) => _AnimUp(
        delay: const Duration(milliseconds: 700),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC0F1318), Color(0xF20B0E12), TT.bg2],
              stops: [0.0, 0.3, 1.0],
            ),
            border: Border(top: BorderSide(color: TT.line, width: 1)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
          ),
          child: ListView(
            controller: scrollCtl,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              _SheetHandle(onTap: onHandleTap),
              // Title row.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleFor(recording),
                          style: TT.title(16, letterSpacing: -0.01 * 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (recording.isRecording ||
                            recording.isPaused) ...[
                          const SizedBox(height: 6),
                          TTPill(
                            label: recording.isPaused
                                ? 'PAUSED'
                                : 'IN PROGRESS',
                            variant: recording.isPaused
                                ? TTPillVariant.neutral
                                : TTPillVariant.live,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (recording.isRecording)
                    _PauseButton(onTap: recording.pause)
                  else if (recording.isPaused)
                    _ResumeButton(onTap: () => recording.start())
                  else
                    _StartButton(onTap: onStart),
                  if (recording.isRecording || recording.isPaused) ...[
                    const SizedBox(width: 8),
                    _StopButton(onTap: recording.stop),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              // 3-stat row.
              _StatRow(
                recording: recording,
                useMiles: useMiles,
                formatDistValueOnly: formatDistValueOnly,
              ),
              const SizedBox(height: 12),
              // Mini elevation chart card (only when we have data).
              if (recording.points.length >= 2)
                _MiniElevCard(
                  points: recording.points,
                  useMiles: useMiles,
                )
              else
                _EmptyChartCard(isRecording: recording.isRecording),
              const SizedBox(height: 14),
              // Expanded section — only shown when the user drags the sheet up,
              // but always present in the scrollable so the DraggableScrollable
              // can reveal it without rebuilding.
              _ExpandedDetails(
                recording: recording,
                formatSpeed: formatSpeed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(RecordingProvider rec) {
    if (rec.isRecording || rec.isPaused) {
      return rec.targetTrail?.name ??
          rec.customName ??
          'Free-form recording';
    }
    return 'Tap PLAY to start recording';
  }
}

class _ExpandedDetails extends StatelessWidget {
  final RecordingProvider recording;
  final String Function(double? kmh) formatSpeed;
  const _ExpandedDetails({
    required this.recording,
    required this.formatSpeed,
  });

  @override
  Widget build(BuildContext context) {
    final pts = recording.points;
    final gpsLabel = recording.gpsHealthLabel;
    final accuracy = recording.lastAccuracy;
    final activity = recording.activityType.toUpperCase();

    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SESSION DETAILS',
                  style: TT.label(
                      size: 10.5, color: TT.text2, letterSpacing: 0.14 * 10.5)),
              TTPill(
                label: 'GPS $gpsLabel',
                variant: gpsLabel == 'EXCELLENT' || gpsLabel == 'GOOD'
                    ? TTPillVariant.live
                    : TTPillVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DetailRow(
              label: 'Activity',
              value: activity,
              icon: Icons.directions_walk),
          _DetailRow(
              label: 'Points captured',
              value: pts.length.toString(),
              icon: Icons.timeline),
          _DetailRow(
              label: 'Accepted fixes',
              value: recording.acceptedFixes.toString(),
              icon: Icons.check_circle_outline),
          _DetailRow(
              label: 'Rejected fixes',
              value: recording.rejectedFixes.toString(),
              icon: Icons.do_disturb_alt_outlined),
          _DetailRow(
              label: 'Last accuracy',
              value: accuracy == null
                  ? '—'
                  : '${accuracy.toStringAsFixed(1)} m',
              icon: Icons.center_focus_strong),
          _DetailRow(
              label: 'Avg speed',
              value: formatSpeed(recording.averageSpeedKmh),
              icon: Icons.speed),
          if (recording.targetTrail != null)
            _DetailRow(
                label: 'Target trail',
                value: recording.targetTrail!.name,
                icon: Icons.flag_outlined),
          if (recording.isOffTrail)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TTPill(
                label: 'OFF-TRAIL ${recording.offTrailDist.round()}M',
                variant: TTPillVariant.danger,
                leadingIcon: Icons.warning_amber_outlined,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: TT.text3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TT.body(size: 12, color: TT.text2, w: FontWeight.w600)),
          ),
          Text(value,
              style: TT.mono(size: 11, color: TT.text, w: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PauseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: TT.ember,
          borderRadius: BorderRadius.circular(11),
          boxShadow: TT.shadowEmber,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause, size: 12, color: TT.emberInk),
            const SizedBox(width: 6),
            Text(
              'PAUSE',
              style: TT.body(size: 12, w: FontWeight.w800, color: TT.emberInk)
                  .copyWith(letterSpacing: 0.12 * 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ResumeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: TT.ember,
          borderRadius: BorderRadius.circular(11),
          boxShadow: TT.shadowEmber,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow, size: 14, color: TT.emberInk),
            const SizedBox(width: 6),
            Text(
              'RESUME',
              style: TT.body(size: 12, w: FontWeight.w800, color: TT.emberInk)
                  .copyWith(letterSpacing: 0.12 * 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final Future<void> Function() onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: TT.ember,
          borderRadius: BorderRadius.circular(11),
          boxShadow: TT.shadowEmber,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow, size: 14, color: TT.emberInk),
            const SizedBox(width: 6),
            Text(
              'START RECORDING',
              style: TT.body(size: 12, w: FontWeight.w800, color: TT.emberInk)
                  .copyWith(letterSpacing: 0.12 * 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: TT.line3, width: 1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          'STOP',
          style: TT.body(size: 12, w: FontWeight.w800, color: TT.text2)
              .copyWith(letterSpacing: 0.12 * 12),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final RecordingProvider recording;
  final bool useMiles;
  final String Function(double km) formatDistValueOnly;
  const _StatRow({
    required this.recording,
    required this.useMiles,
    required this.formatDistValueOnly,
  });

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final speedKmh = recording.averageSpeedKmh;
    final speedValue = units.speedFromKmh(speedKmh).toStringAsFixed(1);
    final speedUnit = units.speedUnit;
    final elev = units.elevationFromM(recording.totalGainM.toDouble()).round();
    final elevUnit = units.elevationUnit;
    final time = recording.duration;

    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        border: Border.all(color: TT.line, width: 1),
        borderRadius: BorderRadius.circular(TT.rMd),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TT.rMd),
        child: Row(
          children: [
            Expanded(
              child: _MiniStat(
                label: 'Elev',
                value: elev.toString(),
                unit: elevUnit,
                ember: true,
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _MiniStat(
                label: 'Pace',
                value: speedValue,
                unit: speedUnit,
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _MiniStat(
                label: 'Time',
                value: _formatDurationLong(time),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 48, color: TT.line);
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool ember;
  const _MiniStat({
    required this.label,
    required this.value,
    this.unit,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TT.surf,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TT.label(size: 9.5, color: TT.text3, letterSpacing: 0.14 * 9.5),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TT.numStyle(
                    size: 19,
                    color: ember ? TT.ember : TT.text,
                    letterSpacing: -0.02 * 19,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(unit!, style: TT.mono(size: 10, color: TT.text2)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniElevCard extends StatelessWidget {
  final List<RecordingPoint> points;
  final bool useMiles;
  const _MiniElevCard({required this.points, required this.useMiles});

  @override
  Widget build(BuildContext context) {
    // Sample the elevations from the recording points. Cap the number of
    // samples used for the chart so dense recordings don't bog down paint.
    const maxSamples = 96;
    final n = points.length;
    final stride = math.max(1, (n / maxSamples).ceil());
    final samples = <double>[];
    var totalDistKm = 0.0;
    final distSamples = <double>[]; // cumulative km
    for (var i = 0; i < n; i += stride) {
      final p = points[i];
      samples.add(p.altitude);
      if (i > 0) {
        final prev = points[i - stride < 0 ? 0 : i - stride];
        totalDistKm += Geolocator.distanceBetween(
              prev.latitude,
              prev.longitude,
              p.latitude,
              p.longitude,
            ) /
            1000.0;
      }
      distSamples.add(totalDistKm);
    }
    final lastKm = distSamples.isEmpty ? 0.0 : distSamples.last;
    final units = context.watch<UnitsProvider>();
    final distLabel =
        '0 → ${units.distanceFromKm(lastKm).toStringAsFixed(1)} ${units.distanceUnit}';

    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ELEVATION PROFILE',
                style: TT.label(size: 10.5, color: TT.text2, letterSpacing: 0.14 * 10.5),
              ),
              Text(
                distLabel,
                style: TT.mono(size: 10, color: TT.text3, w: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: CustomPaint(
              painter: _MiniElevPainter(samples: samples),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartCard extends StatelessWidget {
  final bool isRecording;
  const _EmptyChartCard({required this.isRecording});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Icon(
            isRecording ? Icons.timeline : Icons.show_chart,
            size: 18,
            color: TT.text3,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRecording
                  ? 'Waiting for GPS fixes — elevation profile will appear shortly.'
                  : 'Start a recording to see live elevation and pace.',
              style: TT.body(size: 12, w: FontWeight.w500, color: TT.text3),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniElevPainter extends CustomPainter {
  final List<double> samples;
  _MiniElevPainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    const pad = 4.0;
    final n = samples.length;
    final stepX = (size.width - pad * 2) / (n - 1);

    var minV = samples.first;
    var maxV = samples.first;
    for (final v in samples) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    if (maxV - minV < 1) maxV = minV + 1;

    Offset xy(double v, int i) {
      final x = pad + i * stepX;
      final y = size.height -
          pad -
          ((v - minV) / (maxV - minV)) * (size.height - pad * 2);
      return Offset(x, y);
    }

    final stroke = Path();
    for (var i = 0; i < n; i++) {
      final p = xy(samples[i], i);
      if (i == 0) {
        stroke.moveTo(p.dx, p.dy);
      } else {
        stroke.lineTo(p.dx, p.dy);
      }
    }

    // Fill under the curve.
    final fillPath = Path.from(stroke)
      ..lineTo(size.width - pad, size.height - pad)
      ..lineTo(pad, size.height - pad)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x8CFF6A2C), Color(0x00FF6A2C)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      stroke,
      Paint()
        ..color = TT.ember
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Peak marker.
    var peakIdx = 0;
    for (var i = 1; i < n; i++) {
      if (samples[i] > samples[peakIdx]) peakIdx = i;
    }
    final peak = xy(samples[peakIdx], peakIdx);
    canvas.drawLine(
      peak,
      Offset(peak.dx, size.height - pad),
      Paint()
        ..color = const Color(0x4DFFFFFF)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(peak, 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      peak,
      3.5,
      Paint()
        ..color = TT.ember
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_MiniElevPainter old) => old.samples != samples;
}

// ──────────────────────── SEARCH DELEGATE ────────────────────────────────────

class _TrailSearchDelegate extends SearchDelegate<Trail?> {
  final List<Trail> trails;
  _TrailSearchDelegate(this.trails) : super(searchFieldLabel: 'Search trails');

  // Override the keyboard type to one that disables Android's spell-check and
  // autocomplete bubbles — those underline trail names like "Mnweni" or
  // "Drakensberg" in yellow because the dictionary doesn't know them, and
  // they also actively auto-correct partial queries into the wrong word.
  // visiblePassword is the standard Flutter workaround for this; it keeps a
  // normal QWERTY layout but tells the IME this is identifier text.
  @override
  TextInputType? get keyboardType => TextInputType.visiblePassword;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: TT.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: TT.bg2,
        elevation: 0,
        iconTheme: const IconThemeData(color: TT.text),
        titleTextStyle: TT.title(18),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TT.body(size: 14, color: TT.text3),
        border: InputBorder.none,
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: TT.body(size: 14, color: TT.text),
      ),
    );
  }

  List<Trail> _matches(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      // Show every loaded trail in alphabetical order — the ListView is
      // virtualised so a 239-item list scrolls just as smoothly as a 40-item
      // one, and "where's the rest of my trails?" beats a tidy short list.
      final sorted = List<Trail>.of(trails)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted;
    }
    final filtered = trails
        .where((t) => t.name.toLowerCase().contains(query))
        .toList();
    filtered.sort((a, b) {
      final ai = a.name.toLowerCase().indexOf(query);
      final bi = b.name.toLowerCase().indexOf(query);
      if (ai != bi) return ai.compareTo(bi);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  Widget _resultList(BuildContext context) {
    final results = _matches(query);
    if (results.isEmpty) {
      return Container(
        color: TT.bg,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Text(
          'No trails match "${query.trim()}".',
          style: TT.body(size: 14, color: TT.text2),
        ),
      );
    }
    return Container(
      color: TT.bg,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final t = results[i];
          return TTCard(
            tight: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => close(context, t),
            child: Row(
              children: [
                Icon(t.isCave ? Icons.terrain : Icons.landscape,
                    size: 18, color: TT.ember),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.name,
                        style: TT.body(size: 14, w: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${t.difficulty} · ${t.distanceKm.toStringAsFixed(1)} km · '
                        '${t.elevationGainM}m gain',
                        style: TT.mono(
                            size: 10.5, color: TT.text3, w: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: TT.text3),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.close, color: TT.text2),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: TT.text),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _resultList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _resultList(context);
}

// ──────────────────────── FORMATTING HELPERS ─────────────────────────────────

String _formatDurationShort(Duration d) {
  if (d == Duration.zero) return '0m';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}

String _formatDurationLong(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ──────────────────────── BREAKDOWN MODELS ───────────────────────────────────

class _HikeSnapshot {
  final int movingSeconds;
  final double movingDistanceKm;
  final double maxSpeedKmh;
  const _HikeSnapshot({
    required this.movingSeconds,
    required this.movingDistanceKm,
    required this.maxSpeedKmh,
  });
}

class _BreakRow {
  final String label;
  final String value;
  const _BreakRow({required this.label, required this.value});
}

class _BreakRowView extends StatelessWidget {
  final _BreakRow row;
  const _BreakRowView({required this.row});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(row.label,
                style: TT.body(size: 13, color: TT.text2, w: FontWeight.w600)),
          ),
          Text(row.value,
              style: TT.numStyle(size: 14, color: TT.text)),
        ],
      ),
    );
  }
}

// ──────────────────────── ANIMATION PRIMITIVES ───────────────────────────────

/// `anim-up` — fade + rise from 14px.
class _AnimUp extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _AnimUp({required this.delay, required this.child});
  @override
  State<_AnimUp> createState() => _AnimUpState();
}

class _AnimUpState extends State<_AnimUp> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _ctl.forward(); });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = TT.easeOut.transform(_ctl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, (1 - t) * 14), child: widget.child),
        );
      },
    );
  }
}

/// `anim-pop` — fade + scale from 0.7.
class _AnimPop extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _AnimPop({required this.delay, required this.child});
  @override
  State<_AnimPop> createState() => _AnimPopState();
}

class _AnimPopState extends State<_AnimPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 480));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _ctl.forward(); });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = TT.easeOut.transform(_ctl.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.7 + 0.3 * t, child: widget.child),
        );
      },
    );
  }
}
