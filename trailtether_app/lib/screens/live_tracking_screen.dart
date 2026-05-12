import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/sun_utils.dart';
import '../models/weather.dart';
import '../models/incident.dart';
import '../models/saved_hike.dart';
import '../providers/hike_history_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/team_provider.dart';
import '../providers/auth_provider.dart' as ap;
import '../services/weather_service.dart';
import '../services/offline_map_service.dart';
import '../widgets/common/glass_panel.dart';
import '../widgets/map/trail_map_3d_selector.dart';
import '../providers/static_data_provider.dart';
import '../providers/safety_provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/map/speed_path_layer.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  double? _heading;
  WeatherData? _weather;
  bool _loadingWeather = false;
  Timer? _weatherTimer;
  StreamSubscription? _compassSub;
  final MapController _mapCtrl = MapController();
  bool _following = true;
  RecordingProvider? _recordingProvider;
  SafetyProvider? _safetyProvider;

  // 0 = Outdoor (2D), 1 = Satellite (2D), 2 = 3D
  // 0 = Outdoor (2D), 1 = Satellite (2D), 2 = 3D
  int _mapMode = 1;

  @override
  void initState() {
    super.initState();
    _initCompass();
    _fetchWeather();
    _initSafetyListener();
    // Refresh weather every 30 mins
    _weatherTimer =
        Timer.periodic(const Duration(minutes: 30), (_) => _fetchWeather());

    // Start passive tracking to show signal health before recording
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recordingProvider ??= context.read<RecordingProvider>();
      _recordingProvider?.startPassiveTracking();
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _weatherTimer?.cancel();
    _recordingProvider?.removeListener(_onRecordingChanged);
    _recordingProvider?.stopPassiveTracking();
    super.dispose();
  }

  void _initCompass() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return;
    _compassSub = FlutterCompass.events?.listen((e) {
      if (mounted && e.heading != null) {
        setState(() => _heading = e.heading!);
      }
    });
  }

  void _initSafetyListener() {
    _recordingProvider = context.read<RecordingProvider>();
    _safetyProvider = context.read<SafetyProvider>();
    _recordingProvider?.addListener(_onRecordingChanged);
  }

  void _onRecordingChanged() {
    final rec = _recordingProvider;
    final safety = _safetyProvider;
    if (!mounted || rec == null || safety == null) return;
    if (rec.points.isEmpty || !rec.isRecording) return;

    final lastPoint = rec.points.last;
    final pos = Position(
      latitude: lastPoint.latitude,
      longitude: lastPoint.longitude,
      timestamp: lastPoint.timestamp,
      accuracy: lastPoint.accuracy,
      altitude: lastPoint.altitude,
      heading: 0,
      speed: lastPoint.speed,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    rec.checkSafetyProximity(safety.incidents, pos);
  }

  Future<void> _fetchWeather() async {
    final rec = context.read<RecordingProvider>();
    if (rec.points.isEmpty) return;

    setState(() => _loadingWeather = true);
    final pos = rec.points.last;
    final data =
        await WeatherService.fetch(lat: pos.latitude, lon: pos.longitude);
    if (mounted) {
      setState(() {
        _weather = data;
        _loadingWeather = false;
      });
    }
  }

  void _showFinishDialog(RecordingProvider rec) {
    HapticFeedback.heavyImpact();
    rec.pause();

    String type = rec.activityType;
    String contextStr = rec.activityContext;
    String? teamId = rec.toSavedHike().teamId;
    final nameCtrl =
        TextEditingController(text: rec.customName ?? rec.targetTrail?.name);
    int peaks = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kColorBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FINISH & SAVE',
                  style: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                  'Great work! Classify and name this activity to sync with your dashboard.',
                  style:
                      GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'ACTIVITY NAME',
                  labelStyle: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Text('ACTIVITY TYPE',
                  style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeButton(
                      label: 'HIKE',
                      icon: Icons.hiking,
                      active: type == 'hike',
                      onTap: () => setLocalState(() => type = 'hike')),
                  const SizedBox(width: 8),
                  _TypeButton(
                      label: 'WALK',
                      icon: Icons.directions_walk,
                      active: type == 'walk',
                      onTap: () => setLocalState(() => type = 'walk')),
                  const SizedBox(width: 8),
                  _TypeButton(
                      label: 'RUN',
                      icon: Icons.directions_run,
                      active: type == 'run',
                      onTap: () => setLocalState(() => type = 'run')),
                ],
              ),
              const SizedBox(height: 20),
              Text('CONTEXT',
                  style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeButton(
                      label: 'PERSONAL',
                      icon: Icons.person,
                      active: contextStr == 'personal',
                      onTap: () =>
                          setLocalState(() => contextStr = 'personal')),
                  const SizedBox(width: 8),
                  _TypeButton(
                      label: 'TEAM',
                      icon: Icons.groups,
                      active: contextStr == 'team',
                      onTap: () => setLocalState(() => contextStr = 'team')),
                  const SizedBox(width: 8),
                  _TypeButton(
                      label: 'TRAINING',
                      icon: Icons.fitness_center,
                      active: contextStr == 'training',
                      onTap: () =>
                          setLocalState(() => contextStr = 'training')),
                ],
              ),
              if (contextStr == 'team') ...[
                const SizedBox(height: 20),
                Text('SELECT TEAM',
                    style: GoogleFonts.outfit(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Consumer<TeamProvider>(
                  builder: (_, tp, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: teamId,
                        dropdownColor: kColorBg,
                        isExpanded: true,
                        hint: Text('Choose a team',
                            style: GoogleFonts.outfit(
                                color: Colors.white24, fontSize: 14)),
                        items: tp.teams
                            .map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.name,
                                      style: GoogleFonts.outfit(
                                          color: Colors.white, fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (v) => setLocalState(() => teamId = v),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PEAKS RECORDED',
                            style: GoogleFonts.outfit(
                                color: Colors.white60,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: kColorOrange),
                                onPressed: () => setLocalState(
                                    () => peaks = (peaks - 1).clamp(0, 10))),
                            Text('$peaks',
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                                icon: const Icon(Icons.add_circle_outline,
                                    color: kColorOrange),
                                onPressed: () =>
                                    setLocalState(() => peaks = peaks + 1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        rec.clear();
                        Navigator.pop(ctx);
                        Navigator.of(context).pop();
                      },
                      child: Text('DISCARD',
                          style: GoogleFonts.outfit(
                              color: Colors.white30,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kColorOrange,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () async {
                        rec.setActivityMetadata(
                            type: type,
                            context: contextStr,
                            name: nameCtrl.text);
                        // Hacky way to inject peaks and teamId into the saved hike
                        // In a real refactor, these would be part of RecordingProvider state
                        await _saveActivity(rec, peaks: peaks, teamId: teamId);
                        rec.clear();
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        Navigator.of(context).pop();
                      },
                      child: Text('SAVE ACTIVITY',
                          style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showStartDialog(RecordingProvider rec) {
    String type = 'hike';
    String contextStr = 'personal';
    String? teamId;

    showModalBottomSheet(
      context: context,
      backgroundColor: kColorBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('START ACTIVITY',
                  style: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 20),
              Text('ACTIVITY TYPE',
                  style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TypeButton(
                      label: 'HIKE',
                      icon: Icons.hiking,
                      active: type == 'hike',
                      onTap: () => setLocalState(() => type = 'hike')),
                  const SizedBox(width: 8),
                  _TypeButton(
                      label: 'WALK',
                      icon: Icons.directions_walk,
                      active: type == 'walk',
                      onTap: () => setLocalState(() => type = 'walk')),
                  const SizedBox(width: 8),
                  _TypeButton(
                      label: 'RUN',
                      icon: Icons.directions_run,
                      active: type == 'run',
                      onTap: () => setLocalState(() => type = 'run')),
                ],
              ),
              const SizedBox(height: 24),
              Text('CONTEXT',
                  style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TypeButton(
                      label: 'PERSONAL',
                      icon: Icons.person,
                      active: contextStr == 'personal',
                      onTap: () =>
                          setLocalState(() => contextStr = 'personal')),
                  const SizedBox(width: 8),
                  _TypeButton(
                      label: 'TEAM',
                      icon: Icons.groups,
                      active: contextStr == 'team',
                      onTap: () => setLocalState(() => contextStr = 'team')),
                  const SizedBox(width: 8),
                  _TypeButton(
                      label: 'TRAINING',
                      icon: Icons.fitness_center,
                      active: contextStr == 'training',
                      onTap: () =>
                          setLocalState(() => contextStr = 'training')),
                ],
              ),
              if (contextStr == 'team') ...[
                const SizedBox(height: 20),
                Text('SELECT TEAM',
                    style: GoogleFonts.outfit(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Consumer<TeamProvider>(
                  builder: (_, tp, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: teamId,
                        dropdownColor: kColorBg,
                        isExpanded: true,
                        hint: Text('Choose a team',
                            style: GoogleFonts.outfit(
                                color: Colors.white24, fontSize: 14)),
                        items: tp.teams
                            .map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.name,
                                      style: GoogleFonts.outfit(
                                          color: Colors.white, fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (v) => setLocalState(() => teamId = v),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kColorOrange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  onPressed: () async {
                    rec.setActivityMetadata(type: type, context: contextStr);
                    // Pass teamId to rec if possible, or just keep it for save
                    final ok = await rec.start();
                    if (ok && ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text('BEGIN RECORDING',
                      style: GoogleFonts.outfit(
                          color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveActivity(RecordingProvider rec,
      {int peaks = 0, String? teamId}) async {
    if (rec.points.isEmpty) return;
    final auth = context.read<ap.AuthProvider>();

    // Create the SavedHike object with injected peaks/teamId
    final baseHike = rec.toSavedHike();
    final finalHike = SavedHike(
      id: baseHike.id,
      name: baseHike.name,
      startedAt: baseHike.startedAt,
      endedAt: baseHike.endedAt,
      points: baseHike.points,
      distanceKm: baseHike.distanceKm,
      durationSeconds: baseHike.durationSeconds,
      movingSeconds: baseHike.movingSeconds,
      averageSpeedKmh: baseHike.averageSpeedKmh,
      movingSpeedKmh: baseHike.movingSpeedKmh,
      maxSpeedKmh: baseHike.maxSpeedKmh,
      ascentM: baseHike.ascentM,
      descentM: baseHike.descentM,
      minElevationM: baseHike.minElevationM,
      maxElevationM: baseHike.maxElevationM,
      averageAccuracyM: baseHike.averageAccuracyM,
      bestAccuracyM: baseHike.bestAccuracyM,
      worstAccuracyM: baseHike.worstAccuracyM,
      acceptedFixes: baseHike.acceptedFixes,
      rejectedFixes: baseHike.rejectedFixes,
      poorAccuracyRejects: baseHike.poorAccuracyRejects,
      jumpRejects: baseHike.jumpRejects,
      staleRejects: baseHike.staleRejects,
      gapWarnings: baseHike.gapWarnings,
      activityType: baseHike.activityType,
      activityContext: baseHike.activityContext,
      benchmarkRouteId: baseHike.benchmarkRouteId,
      teamId: teamId ?? baseHike.teamId,
      peaksClimbed: peaks,
    );

    await context.read<HikeHistoryProvider>().add(finalHike, userId: auth.uid);

    // Mark as completed in My Trails if linked to a benchmark trail
    if (finalHike.benchmarkRouteId != null &&
        finalHike.benchmarkRouteId!.isNotEmpty) {
      if (mounted) {
        final appState = context.read<AppStateProvider>();
        if (!appState.isCompleted(finalHike.benchmarkRouteId!)) {
          await appState.toggleCompleted(finalHike.benchmarkRouteId!);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecordingProvider>();
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    if (rec.points.isNotEmpty && _weather == null && !_loadingWeather) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _weather == null && !_loadingWeather) {
          _fetchWeather();
        }
      });
    }

    // Calculate sunset countdown
    String sunsetCountdown = '--';
    if (rec.points.isNotEmpty) {
      final pos = rec.points.last;
      final sun =
          SunUtils.calculate(DateTime.now(), pos.latitude, pos.longitude);
      if (sun['sunset'] != null) {
        final diff = sun['sunset']!.difference(DateTime.now());
        sunsetCountdown = SunUtils.formatDuration(diff);
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full Screen Map ────────────────────────────────────────────────
          Positioned.fill(
            child: _LiveMap(
              rec: rec,
              mapCtrl: _mapCtrl,
              following: _following,
              mapMode: _mapMode,
              heading: _heading,
              weather: _weather,
              onUserInteract: () => setState(() => _following = false),
            ),
          ),

          // ── Bottom Gradient Fade ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Header / Situation Bar (Floating) ──────────────────────────────
          Positioned(
            top: topPad + 10,
            left: 16,
            right: 16,
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              opacity: 0.9,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle),
                      child:
                          const Icon(Icons.close, color: kColorCream, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('TRAIL NAVIGATION',
                                style: GoogleFonts.outfit(
                                    color: kColorOrange,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2)),
                            const Spacer(),
                            Text('SUNSET IN $sunsetCountdown',
                                style: GoogleFonts.outfit(
                                    color: Colors.white30,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            _GpsHealthBadge(
                              label: rec.gpsHealthLabel,
                              color: rec.gpsHealthColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                            rec.targetTrail?.name ??
                                (rec.points.isEmpty
                                    ? 'Waiting for GPS...'
                                    : 'Custom Route'),
                            style: GoogleFonts.outfit(
                                color: kColorCream,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SituationBadge(isOk: !rec.isOffTrail),
                ],
              ),
            ),
          ),

          // ── Off-Trail Warning ──────────────────────────────────────────────
          if (rec.isOffTrail)
            Positioned(
              top: topPad + 75,
              left: 16,
              right: 16,
              child: _OffTrailWarning(
                dist: rec.offTrailDist,
                bearing: rec.bearingToTrail,
                direction: rec.returnDirection,
                duration: rec.offTrailDuration,
              ),
            ),

          // ── Incident Proximity Alert ───────────────────────────────────────
          if (rec.nearbyIncident != null)
            Positioned(
              top: topPad + 75,
              left: 16,
              right: 16,
              child: _IncidentAlert(
                incident: rec.nearbyIncident!,
                onDismiss: () => rec.clearNearbyIncident(),
              ),
            ),

          // ── Floating Action Column (Map Tools) ────────────────────────────
          Positioned(
            right: 16,
            top: topPad + 85,
            child: Column(
              children: [
                _MapOverlayButton(
                  icon: _following ? Icons.gps_fixed : Icons.gps_not_fixed,
                  active: _following,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _following = true);
                    final currentPos = rec.currentPosition != null
                        ? LatLng(rec.currentPosition!.latitude,
                            rec.currentPosition!.longitude)
                        : (rec.points.isNotEmpty
                            ? rec.points.last.toLatLng
                            : null);
                    if (currentPos != null) {
                      _mapCtrl.move(currentPos, _mapCtrl.camera.zoom);
                    }
                  },
                ),
                const SizedBox(height: 10),
                if (_heading != null)
                  Transform.rotate(
                    angle: (_heading! * math.pi / 180),
                    child: _MapOverlayButton(
                      icon: Icons.navigation,
                      onTap: () => setState(() => _following = true),
                    ),
                  ),
                const SizedBox(height: 10),
                _MapOverlayButton(
                  icon:
                      _mapMode == 2 ? Icons.view_in_ar : Icons.layers_outlined,
                  active: _mapMode != 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _mapMode = (_mapMode + 1) % 3;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _MapOverlayButton(
                  icon:
                      rec.isGhostMode ? Icons.visibility_off : Icons.visibility,
                  active: rec.isGhostMode,
                  onTap: () => rec.toggleGhostMode(),
                ),
                const SizedBox(height: 10),
                _MapOverlayButton(
                  icon: rec.isBatterySaver
                      ? Icons.battery_saver
                      : Icons.battery_std,
                  active: rec.isBatterySaver,
                  onTap: () => rec.toggleBatterySaver(),
                ),
              ],
            ),
          ),

          // ── Stats Overlay (Bottom) ─────────────────────────────────────────
          Positioned(
            bottom: botPad + 90,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary Stats Row
                Row(
                  children: [
                    Expanded(
                        child: _CompactStat(
                      label: 'ALTITUDE',
                      value:
                          '${rec.points.isNotEmpty ? rec.points.last.altitude.toInt() : 0}',
                      unit: 'm',
                      icon: Icons.terrain,
                      color: const Color(0xFF4FC3F7),
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _CompactStat(
                      label: 'PACE',
                      value: rec.points.isNotEmpty
                          ? (rec.points.last.speed * 3.6).toStringAsFixed(1)
                          : '0.0',
                      unit: 'km/h',
                      icon: Icons.speed,
                      color: const Color(0xFFFFD54F),
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _CompactStat(
                      label: 'PROGRESS',
                      value: rec.distanceKm.toStringAsFixed(2),
                      unit: 'km',
                      icon: Icons.straighten,
                      color: const Color(0xFF81C784),
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                // Target Progress Card (if following a trail)
                if (rec.remainingDist > 0) _FloatingTargetCard(rec: rec),
                const SizedBox(height: 12),
                // GPS health card hidden as per user request
              ],
            ),
          ),

          // ── Bottom Control Bar ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, botPad + 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kColorPanel.withOpacity(0.98), kColorBg],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.1), width: 1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.6), blurRadius: 30)
                ],
              ),
              child: Row(
                children: [
                  if (rec.status == RecordingStatus.idle && rec.points.isEmpty)
                    Expanded(
                      child: _ActionButton(
                        label: 'START TRACKING',
                        icon: Icons.play_arrow_rounded,
                        color: kColorOrange,
                        onTap: () => _showStartDialog(rec),
                      ),
                    )
                  else if (rec.status != RecordingStatus.idle ||
                      rec.points.isNotEmpty) ...[
                    Expanded(
                      child: _ActionButton(
                        label: rec.isRecording ? 'PAUSE' : 'RESUME',
                        icon: rec.isRecording
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: kColorOrange,
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await HapticFeedback.mediumImpact();
                          if (rec.isRecording) {
                            rec.pause();
                          } else {
                            final ok = await rec.start();
                            if (!mounted || ok) return;
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Background location permission is required for reliable tracking.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'FINISH',
                        icon: Icons.stop_rounded,
                        color: Colors.redAccent,
                        onTap: () => _showFinishDialog(rec),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ──────────────────────────────────────────────────────

class _SituationBadge extends StatelessWidget {
  final bool isOk;
  const _SituationBadge({required this.isOk});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isOk
              ? Colors.green.withOpacity(0.15)
              : Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isOk ? Colors.green : Colors.red, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isOk ? Icons.check_circle : Icons.warning,
                color: isOk ? Colors.green : Colors.red, size: 12),
            const SizedBox(width: 6),
            Flexible(
              child: Text(isOk ? 'OK' : 'OFF-TRAIL',
                  style: GoogleFonts.outfit(
                      color: isOk ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5)),
            ),
          ],
        ),
      );
}

class _CompactStat extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  const _CompactStat(
      {required this.label,
      required this.value,
      required this.unit,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        opacity: 0.1,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.outfit(
                        color: Colors.white30,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1)),
                const SizedBox(width: 4),
                Text(unit,
                    style: GoogleFonts.outfit(
                        color: Colors.white24,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      );
}

class _FloatingTargetCard extends StatelessWidget {
  final RecordingProvider rec;
  const _FloatingTargetCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    final eta = rec.eta;
    final progress = rec.remainingDist > 0
        ? (rec.distanceKm / (rec.distanceKm + rec.remainingDist))
            .clamp(0.0, 1.0)
        : 0.0;

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      opacity: 0.9,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kColorOrange.withOpacity(0.3)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: kColorOrange, size: 16),
              const SizedBox(width: 6),
              Text('REMAINING: ${rec.remainingDist.toStringAsFixed(1)}km',
                  style: GoogleFonts.outfit(
                      color: kColorCream,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('ETA: ${eta != null ? SunUtils.formatDuration(eta) : '--'}',
                  style: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: kColorOrange.withOpacity(0.1),
              color: kColorOrange,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMap extends StatelessWidget {
  final RecordingProvider rec;
  final MapController mapCtrl;
  final bool following;
  final int mapMode; // 0=Outdoor, 1=Satellite, 2=3D
  final double? heading;
  final WeatherData? weather;
  final VoidCallback onUserInteract;

  const _LiveMap({
    required this.rec,
    required this.mapCtrl,
    required this.following,
    required this.mapMode,
    this.heading,
    this.weather,
    required this.onUserInteract,
  });

  @override
  Widget build(BuildContext context) {
    final points = rec.points;
    final currentPos = rec.currentPosition != null
        ? LatLng(rec.currentPosition!.latitude, rec.currentPosition!.longitude)
        : (points.isNotEmpty ? points.last.toLatLng : null);

    // Auto-follow logic
    if (following && currentPos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapCtrl.move(currentPos, mapCtrl.camera.zoom);
      });
    }

    if (mapMode == 2) {
      final safety = context.watch<SafetyProvider>();
      final data = context.watch<StaticDataProvider>();

      return TrailMap3DWidget(
        trails: data.allTrails,
        selectedTrail: rec.targetTrail,
        caves: data.caves,
        incidents: safety.incidents,
        gpsLat: currentPos?.latitude,
        gpsLon: currentPos?.longitude,
        bearing: heading,
        weatherCode: weather?.current.weatherCode,
        cloudCover: weather?.current.cloudCover,
        recordingPoints: rec.points,
      );
    }

    final tileStyleIndex = mapMode == 1 ? 3 : 0; // 3 is Satellite, 0 is Outdoor

    final style = kMapTileStyles[tileStyleIndex];
    return FlutterMap(
      mapController: mapCtrl,
      options: MapOptions(
        initialCenter:
            currentPos ?? LatLng(kWorldMapCenter.lat, kWorldMapCenter.lon),
        initialZoom: 15,
        interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.all),
        onPointerDown: (_, __) => onUserInteract(),
      ),
      children: [
        TileLayer(
          urlTemplate: style.url,
          userAgentPackageName: kTileUserAgent,
          tileProvider: OfflineMapService.tileProvider(),
          maxZoom: style.maxZoom,
        ),
        // Target Trail (The "Trail Ahead")
        if (rec.targetTrail != null) _TargetTrailLayer(trail: rec.targetTrail!),

        // Recorded Path with Speed-based Coloring
        SpeedPathLayer(points: rec.points),
        // User Marker
        MarkerLayer(
          markers: [
            if (currentPos != null)
              Marker(
                point: currentPos,
                width: 40,
                height: 40,
                child: _UserMarker(
                  heading: heading,
                  isStale: rec.isGpsStale,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TargetTrailLayer extends StatelessWidget {
  final dynamic trail; // Using dynamic here to avoid any type poisoning for now
  const _TargetTrailLayer({required this.trail});

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: trail.coords
          .map((c) => Marker(
                point: LatLng(c.lat, c.lon),
                width: 4,
                height: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TypeButton(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active
                  ? kColorOrange.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? kColorOrange : Colors.white10),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: active ? kColorOrange : Colors.white30, size: 20),
                const SizedBox(height: 6),
                Text(label,
                    style: GoogleFonts.outfit(
                        color: active ? kColorOrange : Colors.white30,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
}

class _UserMarker extends StatefulWidget {
  final double? heading;
  final bool isStale;
  const _UserMarker({this.heading, this.isStale = false});

  @override
  State<_UserMarker> createState() => _UserMarkerState();
}

class _UserMarkerState extends State<_UserMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 3.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    if (widget.isStale) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(_UserMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStale && !oldWidget.isStale) {
      _pulseController.repeat();
    } else if (!widget.isStale && oldWidget.isStale) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isStale)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Container(
                width: 14 * _pulseAnimation.value,
                height: 14 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(
                        (1.0 - (_pulseController.value)).clamp(0, 1.0)),
                    width: 1,
                  ),
                ),
              ),
            ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: widget.isStale ? Colors.grey : kColorOrange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: (widget.isStale ? Colors.grey : kColorOrange)
                        .withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2)
              ],
            ),
          ),
          if (widget.heading != null)
            Transform.rotate(
              angle: (widget.heading! * math.pi / 180),
              child: Column(
                children: [
                  Icon(Icons.navigation,
                      color: widget.isStale ? Colors.grey : kColorOrange,
                      size: 24),
                  const SizedBox(height: 16),
                ],
              ),
            ),
        ],
      );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: GoogleFonts.outfit(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1)),
            ],
          ),
        ),
      );
}

class _MapOverlayButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _MapOverlayButton(
      {required this.icon, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? kColorOrange : Colors.black.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(color: active ? Colors.white : Colors.white10),
          ),
          child:
              Icon(icon, color: active ? Colors.black : Colors.white, size: 20),
        ),
      );
}

class _OffTrailWarning extends StatelessWidget {
  final double dist;
  final double? bearing;
  final String direction;
  final Duration? duration;

  const _OffTrailWarning({
    required this.dist,
    this.bearing,
    this.direction = '',
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final durStr = duration == null
        ? ''
        : duration!.inMinutes >= 1
            ? '${duration!.inMinutes}m off-trail'
            : '${duration!.inSeconds}s off-trail';

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.red,
      opacity: 0.2,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          // Directional arrow points back to the nearest trail point.
          if (bearing != null)
            Transform.rotate(
              angle: bearing! * math.pi / 180,
              child: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.redAccent, size: 28),
            )
          else
            const Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OFF TRAIL',
                    style: GoogleFonts.outfit(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 11)),
                Text(
                  bearing != null
                      ? 'Trail ${dist.toInt()}m $direction · turn around'
                      : '${dist.toInt()}m away from path',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                if (durStr.isNotEmpty)
                  Text(durStr,
                      style: GoogleFonts.outfit(
                          color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentAlert extends StatelessWidget {
  final Incident incident;
  final VoidCallback onDismiss;
  const _IncidentAlert({required this.incident, required this.onDismiss});

  @override
  Widget build(BuildContext context) => GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.orange,
        opacity: 0.2,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            const Icon(Icons.report_problem,
                color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEARBY INCIDENT',
                      style: GoogleFonts.outfit(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 11)),
                  Text(incident.type.label.toUpperCase(),
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                onPressed: onDismiss),
          ],
        ),
      );
}

class _GpsHealthBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _GpsHealthBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
                color: color, fontSize: 8, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
