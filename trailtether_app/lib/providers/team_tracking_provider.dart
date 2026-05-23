import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/runtime_config.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../services/location_service.dart';
import '../providers/team_provider.dart';
import 'recording_provider.dart';
import '../services/logger_service.dart';
import '../services/background_tracking_service.dart';

class TeamTrackingProvider extends ChangeNotifier {
  TeamTrackingProvider() {
    LoggerService.log('TRACKING', 'TeamTrackingProvider initialized');
  }

  RecordingProvider? _recordingProvider;
  TeamProvider? _teamProvider;

  // Battery + connectivity readers. Both are cheap to instantiate but reads
  // are async, so we cache the most recent value and refresh on each report
  // tick rather than blocking the broadcast on a fresh read every time.
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  int? _lastBatteryPct;
  String? _lastConnectivity;

  /// Reads battery + connectivity in parallel, with a tight 1.5s ceiling so
  /// a slow OS call never delays the GPS broadcast. Falls back to the last
  /// known value when the read times out, returns null when nothing is yet
  /// known.
  Future<({int? battery, String? connectivity})> _readDeviceVitals() async {
    Future<int?> readBattery() async {
      try {
        final v = await _battery.batteryLevel.timeout(
          const Duration(milliseconds: 1500),
        );
        return v.clamp(0, 100);
      } catch (_) {
        return _lastBatteryPct;
      }
    }

    Future<String?> readConnectivity() async {
      try {
        final result = await _connectivity.checkConnectivity().timeout(
              const Duration(milliseconds: 1500),
            );
        // connectivity_plus 6.x returns a List<ConnectivityResult>. Pick the
        // strongest active link so a phone on both wifi + mobile reports as
        // wifi (the cheaper, usually-stronger link).
        if (result.contains(ConnectivityResult.wifi)) return 'wifi';
        if (result.contains(ConnectivityResult.ethernet)) return 'wifi';
        if (result.contains(ConnectivityResult.mobile)) return 'mobile';
        return 'none';
      } catch (_) {
        return _lastConnectivity;
      }
    }

    final results = await Future.wait([readBattery(), readConnectivity()]);
    final battery = results[0] as int?;
    final conn = results[1] as String?;
    if (battery != null) _lastBatteryPct = battery;
    if (conn != null) _lastConnectivity = conn;
    return (battery: battery, connectivity: conn);
  }

  /// Whether the user has explicitly opened the Live Tracking screen and
  /// expects their position to be visible to the command centre / team.
  /// Toggled by [LiveTrackingScreen] in initState / dispose. Without this,
  /// the only triggers for broadcasting are `isRecording` or a selected
  /// team, which meant tapping LIVE TRACK on the home tab silently did
  /// nothing.
  bool _liveSharingEnabled = false;
  bool get liveSharingEnabled => _liveSharingEnabled;

  bool get _shouldTrack {
    final isRecording = _recordingProvider?.isRecording ?? false;
    return isRecording ||
        _teamProvider?.selectedTeam != null ||
        _liveSharingEnabled;
  }

  void setLiveSharing(bool enabled) {
    if (_liveSharingEnabled == enabled) return;
    _liveSharingEnabled = enabled;
    LoggerService.log('TRACKING', 'live sharing -> $enabled');
    if (enabled) {
      if (!_isTracking) _startTracking();
    } else if (!_shouldTrack) {
      _stopTracking();
    }
    _safeNotify();
  }

  set recordingProvider(RecordingProvider p) {
    final bool wasRecording = _recordingProvider?.isRecording ?? false;
    final bool isRecording = p.isRecording;
    final bool posChanged =
        _recordingProvider?.currentPosition != p.currentPosition;

    _recordingProvider = p;

    if (_shouldTrack) {
      if (!_isTracking) {
        _startTracking();
      } else if ((isRecording || _liveSharingEnabled) && posChanged) {
        // Feed live data immediately but throttle to avoid DB spam (max once per 3s)
        final now = DateTime.now();
        if (_lastReportAt == null ||
            now.difference(_lastReportAt!).inSeconds >= 3) {
          _reportNow();
        }
      }
    } else if (wasRecording &&
        !isRecording &&
        (_activeHike == null || _activeHike!.status != 'active')) {
      _stopTracking();
    }
  }

  set teamProvider(TeamProvider p) {
    if (_teamProvider != p) {
      _teamProvider = p;
      if (_shouldTrack && !_isTracking) {
        _startTracking();
      } else if (!_shouldTrack) {
        _stopTracking();
      }
      // If team changes, force an immediate report if active
      if (_isTracking) _reportNow();
    }
  }

  User? get _currentUser {
    if (!kSupabaseAvailable) return null;
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  String? get _uid => _currentUser?.id;

  String get _displayName {
    final user = _currentUser;
    if (user == null) return 'Hiker';
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    for (final key in ['display_name', 'displayName', 'full_name', 'name']) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return user.email ?? 'Hiker';
  }

  HikePlan? _activeHike;
  HikePlan? get activeHike => _activeHike;

  Timer? _reportTimer;
  List<TeamMemberLocation> _teamLocations = [];
  List<TeamMemberLocation> get teamLocations => _teamLocations;

  bool _isTracking = false;
  bool get isTracking => _isTracking;
  DateTime? _lastReportAt;
  DateTime? get lastReportAt => _lastReportAt;
  bool _disposed = false;
  bool _reporting = false;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void setActiveHike(HikePlan? hike) {
    _activeHike = hike;
    if (hike != null && hike.status == 'active') {
      _startTracking();
    } else {
      _stopTracking();
    }
    notifyListeners();
  }

  void _startTracking() {
    if (_isTracking) return;
    _isTracking = true;

    // Immediate report so the PC command centre sees us appear within ~1s of going live.
    _reportNow();

    // Adaptive cadence: 5s while recording (real-time command-centre feel), 20s otherwise.
    // The setRecordingProvider hook also forces a push every time position changes meaningfully.
    _reportTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _adaptiveReport());

    BackgroundTrackingService.start();
  }

  DateTime? _lastMovedAt;
  double? _lastReportedLat;
  double? _lastReportedLon;

  Future<void> _adaptiveReport() async {
    final pos = _recordingProvider?.currentPosition;
    final now = DateTime.now();

    // If we have a position, compute movement since last report.
    if (pos != null && _lastReportedLat != null && _lastReportedLon != null) {
      final dLat = (pos.latitude - _lastReportedLat!) * 111320.0;
      final dLon = (pos.longitude - _lastReportedLon!) *
          111320.0 *
          0.6; // rough cos(lat) at mid-latitudes
      final movedMeters = (dLat * dLat + dLon * dLon);
      if (movedMeters > 25) {
        // moved >5m
        _lastMovedAt = now;
      }
    } else if (pos != null) {
      _lastMovedAt = now;
    }

    // If recording: push every tick (5s). If idle and hasn't moved in 60s: throttle to 1-in-4 (20s).
    final isRecording = _recordingProvider?.isRecording ?? false;
    final stationary = _lastMovedAt == null ||
        now.difference(_lastMovedAt!).inSeconds > 60;
    if (!isRecording && stationary) {
      if (_lastReportAt != null &&
          now.difference(_lastReportAt!).inSeconds < 20) {
        return;
      }
    }

    await _reportNow();
    if (pos != null) {
      _lastReportedLat = pos.latitude;
      _lastReportedLon = pos.longitude;
    }
  }

  void _stopTracking() {
    _isTracking = false;
    _reportTimer?.cancel();
    _reportTimer = null;
    BackgroundTrackingService.stop();
  }

  Future<void> _reportNow() async {
    // Drop overlapping calls — a slow network can stack ticks.
    if (_reporting || _disposed) return;
    _reporting = true;

    try {
      // Report if any of:
      //   - active hike plan with teamId
      //   - selected team
      //   - actively recording (admin console sees all active hikers)
      //   - live sharing toggled on (user opened the Live Tracking screen)
      final bool isRecording = _recordingProvider?.isRecording ?? false;
      final String? teamId =
          _activeHike?.teamId ?? _teamProvider?.selectedTeam?.id;
      if (teamId == null && !isRecording && !_liveSharingEnabled) return;

      final uid = _uid;
      if (uid == null || uid.isEmpty) {
        LoggerService.log('TRACKING',
            'TeamTrackingProvider: no signed-in user. Skipping report.');
        return;
      }

      // Ghost Mode: Stop broadcasting to Supabase, but tracking logic stays active
      if (_recordingProvider?.isGhostMode ?? false) {
        LoggerService.log('TRACKING',
            'TeamTrackingProvider: Ghost Mode active. Skipping report.');
        return;
      }

      final pos = _recordingProvider?.currentPosition ??
          await LocationService.currentPosition();
      if (pos != null) {
        final vitals = await _readDeviceVitals();
        await TeamService.reportLocation(
          uid: uid,
          displayName: _displayName,
          lat: pos.latitude,
          lon: pos.longitude,
          heading: pos.heading,
          speed: pos.speed,
          altitude: pos.altitude,
          teamId: teamId,
          hikeId: _activeHike?.id,
          status: isRecording ? 'recording' : 'active',
          batteryPct: vitals.battery,
          connectivity: vitals.connectivity,
        );
        _lastReportAt = DateTime.now();
        LoggerService.log('TRACKING',
            'Location reported successfully for $_displayName at ${pos.latitude}, ${pos.longitude}');
        _safeNotify();
      } else {
        LoggerService.log('TRACKING', 'Skipping report: GPS position is null');
      }
    } catch (e, stack) {
      LoggerService.error('TRACKING', 'reportLocation failed: $e', stack);
    } finally {
      _reporting = false;
    }
  }

  Future<void> checkIn(String status) async {
    if (_activeHike == null) return;
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      LoggerService.log('TRACKING',
          'TeamTrackingProvider: no signed-in user. Skipping check-in.');
      return;
    }

    try {
      final pos = await LocationService.currentPosition();
      if (pos == null) {
        LoggerService.log('TRACKING',
            'TeamTrackingProvider: GPS unavailable, skipping check-in to avoid sending null island.');
        return;
      }

      final vitals = await _readDeviceVitals();
      await TeamService.reportLocation(
        uid: uid,
        displayName: _displayName,
        lat: pos.latitude,
        lon: pos.longitude,
        heading: pos.heading,
        speed: pos.speed,
        altitude: pos.altitude,
        teamId: _activeHike!.teamId,
        hikeId: _activeHike!.id,
        status: status,
        batteryPct: vitals.battery,
        connectivity: vitals.connectivity,
      );

      if (status == 'arrived') {
        await TeamService.updateHikeStatus(_activeHike!.id, 'completed');
        _activeHike = null;
        _stopTracking();
      }

      _safeNotify();
    } catch (e, stack) {
      LoggerService.error('TRACKING', 'checkIn failed: $e', stack);
    }
  }

  Future<void> refreshTeamLocations(String teamId) async {
    if (!kSupabaseAvailable) return;
    try {
      _teamLocations = await TeamService.fetchTeamLocations(teamId);
      _safeNotify();
    } catch (e, stack) {
      LoggerService.error('TRACKING', 'refreshTeamLocations failed: $e', stack);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _reportTimer?.cancel();
    super.dispose();
  }
}
