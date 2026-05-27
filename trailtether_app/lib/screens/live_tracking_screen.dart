// Trailtether 3.0 — Live tracking screen, reskinned to TT tokens.
//
// Full-screen flutter_map (or 3D widget) with an ember-stroked recorded
// polyline, glass overlays for the situation bar, stat tiles, off-trail
// and incident alerts, plus a ember finish button. Logic for passive
// tracking, broadcasting, weather poll, safety proximity, ghost mode,
// battery saver, finish / save flow is preserved one-to-one.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../core/sun_utils.dart';
import '../models/incident.dart';
import '../models/weather.dart';
import '../providers/recording_provider.dart';
import '../providers/safety_provider.dart';
import '../providers/static_data_provider.dart';
import '../providers/team_provider.dart';
import '../providers/units_provider.dart';
import '../services/offline_map_service.dart';
import '../services/weather_service.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/finish_hike_sheet.dart';
import '../widgets/map/speed_path_layer.dart';
import '../widgets/map/trail_map_3d_selector.dart';

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
  int _mapMode = 1;

  @override
  void initState() {
    super.initState();
    _initCompass();
    _fetchWeather();
    _initSafetyListener();
    _weatherTimer =
        Timer.periodic(const Duration(minutes: 30), (_) => _fetchWeather());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recordingProvider ??= context.read<RecordingProvider>();
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _weatherTimer?.cancel();
    _recordingProvider?.removeListener(_onRecordingChanged);
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
    // Delegates to the shared FinishHikeSheet (single source of truth for
    // the Save/Discard/Resume UX, used by both this route and the Map tab's
    // recording sheet). On Save or Discard we pop this LiveTrackingScreen
    // route — Keep Recording leaves the screen in place.
    FinishHikeSheet.show(
      context,
      rec,
      onSaved: () {
        if (mounted) Navigator.of(context).pop();
      },
      onDiscarded: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  void _showStartDialog(RecordingProvider rec) {
    String type = 'hike';
    String contextStr = 'personal';
    String? teamId;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rXl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Container(
          decoration: const BoxDecoration(
            color: TT.bg2,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(TT.rXl)),
            border: Border(top: BorderSide(color: TT.line2)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: TT.line3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('START ACTIVITY',
                  style: TT.label(
                      size: 12, color: TT.ember, letterSpacing: 1.4)),
              const SizedBox(height: 18),
              Text('ACTIVITY TYPE',
                  style: TT.label(
                      size: 10.5,
                      color: TT.text3,
                      letterSpacing: 1.4)),
              const SizedBox(height: 10),
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
              const SizedBox(height: 22),
              Text('CONTEXT',
                  style: TT.label(
                      size: 10.5,
                      color: TT.text3,
                      letterSpacing: 1.4)),
              const SizedBox(height: 10),
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
                      onTap: () =>
                          setLocalState(() => contextStr = 'team')),
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
                const SizedBox(height: 18),
                Text('SELECT TEAM',
                    style: TT.label(
                        size: 10.5,
                        color: TT.text3,
                        letterSpacing: 1.4)),
                const SizedBox(height: 10),
                Consumer<TeamProvider>(
                  builder: (_, tp, __) => _TeamDropdown(
                    value: teamId,
                    teams: tp.teams,
                    onChanged: (v) => setLocalState(() => teamId = v),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _PrimaryButton(
                label: 'BEGIN RECORDING',
                onTap: () async {
                  rec.setActivityMetadata(type: type, context: contextStr);
                  final ok = await rec.start();
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                },
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecordingProvider>();
    final units = context.watch<UnitsProvider>();
    // Floor the inset so floating controls don't crash into the very
    // top of the screen under immersiveSticky (status bar hidden ⇒
    // padding.top reads 0). 24 dp keeps them out of the swipe-down
    // gesture zone.
    final topPad =
        MediaQuery.of(context).padding.top > 0
            ? MediaQuery.of(context).padding.top
            : 24.0;
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
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          // ── Full screen map ────────────────────────────────────────────
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

          // ── Bottom gradient fade ───────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 320,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                  ),
                ),
              ),
            ),
          ),

          // ── Situation bar (top) ────────────────────────────────────────
          Positioned(
            top: topPad + 10,
            left: 14,
            right: 14,
            child: _SituationBar(
              onBack: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              trailName: rec.targetTrail?.name ??
                  (rec.points.isEmpty
                      ? 'Waiting for GPS…'
                      : 'Custom Route'),
              sunsetLabel: sunsetCountdown,
              gpsLabel: rec.gpsHealthLabel,
              gpsColor: rec.gpsHealthColor,
              isOk: !rec.isOffTrail,
            ),
          ),

          // ── Off-trail warning ──────────────────────────────────────────
          if (rec.isOffTrail)
            Positioned(
              top: topPad + 86,
              left: 14,
              right: 14,
              child: _OffTrailBanner(
                dist: rec.offTrailDist,
                bearing: rec.bearingToTrail,
                direction: rec.returnDirection,
                duration: rec.offTrailDuration,
              ),
            ),

          // ── Incident alert ─────────────────────────────────────────────
          if (rec.nearbyIncident != null)
            Positioned(
              top: topPad + 86,
              left: 14,
              right: 14,
              child: _IncidentBanner(
                incident: rec.nearbyIncident!,
                onDismiss: () => rec.clearNearbyIncident(),
              ),
            ),

          // ── Map tool column (right) ────────────────────────────────────
          Positioned(
            right: 14,
            top: topPad + 96,
            child: Column(
              children: [
                _MapButton(
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
                    child: _MapButton(
                      icon: Icons.navigation,
                      onTap: () => setState(() => _following = true),
                    ),
                  ),
                const SizedBox(height: 10),
                _MapButton(
                  icon: _mapMode == 2
                      ? Icons.view_in_ar
                      : Icons.layers_outlined,
                  active: _mapMode != 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _mapMode = (_mapMode + 1) % 3;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _MapButton(
                  icon: rec.isGhostMode
                      ? Icons.visibility_off
                      : Icons.visibility,
                  active: rec.isGhostMode,
                  onTap: () => rec.toggleGhostMode(),
                ),
                const SizedBox(height: 10),
                _MapButton(
                  icon: rec.isBatterySaver
                      ? Icons.battery_saver
                      : Icons.battery_std,
                  active: rec.isBatterySaver,
                  onTap: () => rec.toggleBatterySaver(),
                ),
              ],
            ),
          ),

          // ── Stat overlays (bottom) ─────────────────────────────────────
          Positioned(
            bottom: botPad + 96,
            left: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _LiveStat(
                        label: 'ALTITUDE',
                        value: rec.points.isNotEmpty
                            ? units.elevationFromM(rec.points.last.altitude).toInt().toString()
                            : '0',
                        unit: units.elevationUnit,
                        icon: Icons.terrain,
                        accent: TT.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LiveStat(
                        label: 'PACE',
                        value: rec.points.isNotEmpty
                            ? units.formatSpeed(rec.points.last.speed * 3.6, withUnit: false)
                            : '0.0',
                        unit: units.speedUnit,
                        icon: Icons.speed,
                        accent: TT.amber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LiveStat(
                        label: 'DISTANCE',
                        value: units.formatDistance(rec.distanceKm, decimals: 2, withUnit: false),
                        unit: units.distanceUnit,
                        icon: Icons.straighten,
                        accent: TT.green,
                      ),
                    ),
                  ],
                ),
                if (rec.remainingDist > 0) ...[
                  const SizedBox(height: 10),
                  _TargetCard(rec: rec),
                ],
              ],
            ),
          ),

          // ── Control bar ────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 18, 16, botPad + 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE6131820), Color(0xFF07090C)],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(TT.rXl)),
                border: const Border(top: BorderSide(color: TT.line2)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30),
                ],
              ),
              child: Row(
                children: [
                  if (rec.status == RecordingStatus.idle && rec.points.isEmpty)
                    Expanded(
                      child: _PrimaryButton(
                        label: 'START TRACKING',
                        icon: Icons.play_arrow_rounded,
                        onTap: () => _showStartDialog(rec),
                      ),
                    )
                  else if (rec.status != RecordingStatus.idle ||
                      rec.points.isNotEmpty) ...[
                    Expanded(
                      child: _PrimaryButton(
                        label: rec.isRecording ? 'PAUSE' : 'RESUME',
                        icon: rec.isRecording
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await HapticFeedback.mediumImpact();
                          if (rec.isRecording) {
                            rec.pause();
                          } else {
                            final ok = await rec.start();
                            if (!mounted || ok) return;
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: TT.surf,
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  'Background location permission is required for reliable tracking.',
                                  style: TT.body(size: 13, color: TT.text),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DangerButton(
                        label: 'FINISH',
                        icon: Icons.stop_rounded,
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

// ── Situation bar ─────────────────────────────────────────────────────────

class _SituationBar extends StatelessWidget {
  final VoidCallback onBack;
  final String trailName;
  final String sunsetLabel;
  final String gpsLabel;
  final Color gpsColor;
  final bool isOk;
  const _SituationBar({
    required this.onBack,
    required this.trailName,
    required this.sunsetLabel,
    required this.gpsLabel,
    required this.gpsColor,
    required this.isOk,
  });

  @override
  Widget build(BuildContext context) {
    return TTGlass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: TT.rLg,
      child: Row(
        children: [
          TTIconBtn(
              icon: Icons.chevron_left, size: 36, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('TRAIL NAVIGATION',
                        style: TT.label(
                            size: 10,
                            color: TT.ember,
                            letterSpacing: 1.4)),
                    const Spacer(),
                    Text('SUNSET $sunsetLabel',
                        style: TT.mono(size: 9.5, color: TT.text3)),
                    const SizedBox(width: 8),
                    _GpsBadge(label: gpsLabel, color: gpsColor),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  trailName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TT.body(
                      size: 14.5, w: FontWeight.w800, color: TT.text),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TTPill(
            label: isOk ? 'ON TRAIL' : 'OFF TRAIL',
            variant: isOk ? TTPillVariant.neutral : TTPillVariant.danger,
            leadingIcon: isOk ? Icons.check_circle : Icons.warning,
          ),
        ],
      ),
    );
  }
}

class _GpsBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _GpsBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TT.mono(size: 9, color: color, letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }
}

// ── Live stat tile (glass) ────────────────────────────────────────────────

class _LiveStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color accent;
  const _LiveStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return TTGlass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      radius: TT.rLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: accent),
              const SizedBox(width: 6),
              Text(label,
                  style: TT.label(
                      size: 9.5, color: TT.text3, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TT.numStyle(
                      size: 22, color: TT.text, w: FontWeight.w800)),
              const SizedBox(width: 4),
              Text(unit,
                  style: TT.mono(size: 11, color: TT.text3)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Target progress card ──────────────────────────────────────────────────

class _TargetCard extends StatelessWidget {
  final RecordingProvider rec;
  const _TargetCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    final eta = rec.eta;
    final progress = rec.remainingDist > 0
        ? (rec.distanceKm / (rec.distanceKm + rec.remainingDist))
            .clamp(0.0, 1.0)
        : 0.0;
    return TTGlass(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: TT.rLg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: TT.ember, size: 14),
              const SizedBox(width: 6),
              Text(
                  'REMAINING ${rec.remainingDist.toStringAsFixed(1)} KM',
                  style: TT.label(
                      size: 10, color: TT.text, letterSpacing: 1.4)),
              const Spacer(),
              Text(
                  'ETA ${eta != null ? SunUtils.formatDuration(eta) : '--'}',
                  style: TT.mono(size: 10.5, color: TT.ember)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: TT.emberSoft,
              color: TT.ember,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map button (right column) ─────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _MapButton({
    required this.icon,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? TT.ember : const Color(0xB80D1116),
          shape: BoxShape.circle,
          border: Border.all(
              color: active ? TT.ember : TT.line2, width: 1),
          boxShadow: active ? TT.shadowEmber : null,
        ),
        child: Icon(icon,
            color: active ? TT.emberInk : TT.text, size: 18),
      ),
    );
  }
}

// ── Off-trail banner ──────────────────────────────────────────────────────

class _OffTrailBanner extends StatelessWidget {
  final double dist;
  final double? bearing;
  final String direction;
  final Duration? duration;

  const _OffTrailBanner({
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x33E63D2E),
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.red, width: 1),
        boxShadow: [
          BoxShadow(
              color: TT.red.withOpacity(0.30),
              blurRadius: 18,
              spreadRadius: -4),
        ],
      ),
      child: Row(
        children: [
          if (bearing != null)
            Transform.rotate(
              angle: bearing! * math.pi / 180,
              child: const Icon(Icons.arrow_upward_rounded,
                  color: TT.red, size: 26),
            )
          else
            const Icon(Icons.warning_amber_rounded,
                color: TT.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OFF TRAIL',
                    style: TT.label(
                        size: 11, color: TT.red, letterSpacing: 1.4)),
                const SizedBox(height: 2),
                Text(
                  bearing != null
                      ? 'Trail ${dist.toInt()}m $direction · turn around'
                      : '${dist.toInt()}m away from path',
                  style: TT.body(
                      size: 13, w: FontWeight.w700, color: TT.text),
                ),
                if (durStr.isNotEmpty)
                  Text(durStr,
                      style: TT.mono(size: 10.5, color: TT.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Incident banner ───────────────────────────────────────────────────────

class _IncidentBanner extends StatelessWidget {
  final Incident incident;
  final VoidCallback onDismiss;
  const _IncidentBanner({required this.incident, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x33F2A93B),
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.amber, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.report_problem,
              color: TT.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEARBY INCIDENT',
                    style: TT.label(
                        size: 11, color: TT.amber, letterSpacing: 1.4)),
                const SizedBox(height: 2),
                Text(
                  incident.type.label.toUpperCase(),
                  style: TT.body(
                      size: 13, w: FontWeight.w700, color: TT.text),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, color: TT.text2, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map widget ────────────────────────────────────────────────────────────

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
        ? LatLng(rec.currentPosition!.latitude,
            rec.currentPosition!.longitude)
        : (points.isNotEmpty ? points.last.toLatLng : null);

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

    final tileStyleIndex = mapMode == 1 ? 3 : 0; // 3=Satellite, 0=Outdoor
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
          retinaMode: kHighDensity(context),
        ),
        if (rec.targetTrail != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: rec.targetTrail!.coords
                    .map((c) => LatLng(c.lat, c.lon))
                    .toList(),
                color: TT.ember.withOpacity(0.55),
                strokeWidth: 2.5,
              ),
            ],
          ),
        SpeedPathLayer(points: rec.points),
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

class _UserMarker extends StatefulWidget {
  final double? heading;
  final bool isStale;
  const _UserMarker({this.heading, this.isStale = false});

  @override
  State<_UserMarker> createState() => _UserMarkerState();
}

class _UserMarkerState extends State<_UserMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final Animation<double> _pulseAnimation = Tween<double>(
    begin: 1.0,
    end: 3.5,
  ).animate(
    CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isStale) _pulseController.repeat();
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
  Widget build(BuildContext context) {
    final base = widget.isStale ? TT.text3 : TT.ember;
    return Stack(
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
                  color: TT.text.withOpacity(
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
            color: base,
            shape: BoxShape.circle,
            border: Border.all(color: TT.text, width: 2),
            boxShadow: [
              BoxShadow(
                  color: base.withOpacity(0.6),
                  blurRadius: 10,
                  spreadRadius: 2),
            ],
          ),
        ),
        if (widget.heading != null)
          Transform.rotate(
            angle: (widget.heading! * math.pi / 180),
            child: Column(
              children: [
                Icon(Icons.navigation, color: base, size: 22),
                const SizedBox(height: 16),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Buttons / fields used by the sheets ───────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TT.ember,
          borderRadius: BorderRadius.circular(TT.rMd),
          boxShadow: TT.shadowEmber,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: TT.emberInk, size: 20),
              const SizedBox(width: 10),
            ],
            Text(label,
                style: TT.body(
                  size: 13,
                  w: FontWeight.w900,
                  color: TT.emberInk,
                ).copyWith(letterSpacing: 0.16 * 13)),
          ],
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DangerButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x1AE63D2E),
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(color: TT.red, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: TT.red, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TT.body(
                  size: 13,
                  w: FontWeight.w900,
                  color: TT.red,
                ).copyWith(letterSpacing: 0.16 * 13)),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? TT.emberDim : const Color(0x08FFFFFF),
              borderRadius: BorderRadius.circular(TT.rMd),
              border: Border.all(
                  color: active ? const Color(0x52FF6A2C) : TT.line2),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: active ? TT.ember : TT.text3, size: 18),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TT.body(
                      size: 10.5,
                      w: FontWeight.w800,
                      color: active ? TT.ember : TT.text3),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TeamDropdown extends StatelessWidget {
  final String? value;
  final List teams;
  final ValueChanged<String?> onChanged;
  const _TeamDropdown({
    required this.value,
    required this.teams,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.line2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: TT.bg2,
          borderRadius: BorderRadius.circular(TT.rMd),
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Choose a team',
                style: TT.body(size: 14, color: TT.text3)),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.expand_more, color: TT.text2),
          ),
          items: teams
              .map<DropdownMenuItem<String>>(
                (t) => DropdownMenuItem<String>(
                  value: t.id as String,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      t.name as String,
                      style: TT.body(size: 14, color: TT.text),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// Keep TTCountUp imported so future stat additions can use it without
// re-adding the import.
// ignore: unused_element
typedef _KeepCountUpImport = TTCountUp;
