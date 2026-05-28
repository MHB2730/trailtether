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
import '../services/offline_track_queue.dart';
import '../services/offline_incident_queue.dart';

class TeamTrackingProvider extends ChangeNotifier {
  TeamTrackingProvider() {
    LoggerService.log('TRACKING', 'TeamTrackingProvider initialized');
    _startConnectivityWatch();
  }

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _draining = false;

  void _startConnectivityWatch() {
    try {
      _connectivitySub =
          _connectivity.onConnectivityChanged.listen((results) async {
        final online = results.any((r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet);
        if (!online) return;
        // Drain whatever queued up during the outage.
        await _drainOfflineQueue();
      });
    } catch (e, stack) {
      LoggerService.error(
          'TRACKING', '_startConnectivityWatch failed: $e', stack);
    }
  }

  Future<void> _drainOfflineQueue() async {
    if (_draining || _disposed) return;
    _draining = true;
    try {
      await _drainOfflineIncidentsQueue();
      final fixes = await OfflineTrackQueue.drainAll();
      if (fixes.isEmpty) return;
      LoggerService.log(
          'TRACKING', 'Draining ${fixes.length} offline fixes to Supabase');
      final rows = fixes.map((f) {
        final copy = Map<String, dynamic>.from(f);
        copy.remove('_display_name');
        copy['synced_offline'] = true;
        return copy;
      }).toList();
      try {
        await TeamService.bulkInsertTrackPoints(rows);
      } catch (e, stack) {
        LoggerService.error(
            'TRACKING', 'bulkInsertTrackPoints failed; re-queueing: $e', stack);
        await OfflineTrackQueue.reenqueue(fixes);
        return;
      }
      try {
        final newest = fixes.last;
        await TeamService.reportLocation(
          uid: newest['uid'] as String,
          displayName:
              (newest['_display_name'] as String?) ?? _displayName,
          lat: (newest['lat'] as num).toDouble(),
          lon: (newest['lon'] as num).toDouble(),
          heading: (newest['heading'] as num?)?.toDouble() ?? 0,
          speed: (newest['speed'] as num?)?.toDouble() ?? 0,
          altitude: (newest['altitude'] as num?)?.toDouble() ?? 0,
          teamId: newest['team_id'] as String?,
          hikeId: newest['hike_id'] as String?,
          status: newest['status'] as String?,
          batteryPct: newest['battery_pct'] as int?,
          connectivity: newest['connectivity'] as String?,
        );
      } catch (e) {
        LoggerService.log('TRACKING',
            'latest-position upsert after drain failed (non-fatal): $e');
      }
      LoggerService.log('TRACKING', 'Offline drain complete');
    } finally {
      _draining = false;
    }
  }

  Future<void> _drainOfflineIncidentsQueue() async {
    if (_disposed) return;
    try {
      final incidents = await OfflineIncidentQueue.drainAll();
      if (incidents.isEmpty) return;
      LoggerService.log(
          'OFF_TRAIL', 'Draining ${incidents.length} offline incident alerts to Supabase');
      try {
        await Supabase.instance.client.from('incidents').insert(incidents);
        LoggerService.log('OFF_TRAIL', 'Offline incidents drain complete');
      } catch (e, stack) {
        LoggerService.error(
            'OFF_TRAIL', 'Failed to insert drained incidents; re-queueing: $e', stack);
        await OfflineIncidentQueue.reenqueue(incidents);
      }
    } catch (e, stack) {
      LoggerService.error('OFF_TRAIL', '_drainOfflineIncidentsQueue failed: $e', stack);
    }
  }

  RecordingProvider? _recordingProvider;
  TeamProvider? _teamProvider;

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  int? _lastBatteryPct;
  String? _lastConnectivity;

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

  set recordingProvider(RecordingProvider p) {
    final bool wasRecording = _recordingProvider?.isRecording ?? false;
    final bool isRecording = p.isRecording;
    final bool posChanged =
        _recordingProvider?.currentPosition != p.currentPosition;
    final bool justStartedRecording = !wasRecording && isRecording;

    _recordingProvider = p;

    if (isRecording) {
      if (!_isTracking) {
        _startTracking();
      } else if (justStartedRecording) {
        _reportNow();
      } else if (posChanged) {
        // Throttle DB writes to max once per 3s while moving.
        final now = DateTime.now();
        if (_lastReportAt == null ||
            now.difference(_lastReportAt!).inSeconds >= 3) {
          _reportNow();
        }
      }
    } else if (wasRecording && !isRecording) {
      _stopTracking();
    }
  }

  set teamProvider(TeamProvider p) {
    if (_teamProvider != p) {
      _teamProvider = p;
      _watchTeamLocations(p.selectedTeam?.id);
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

  /// Effective hike id to stamp on team_member_track_points + reportLocation.
  /// Prefers the explicit HikePlan id when a team hike is active, falls back
  /// to RecordingProvider's session uuid so solo recordings also tag their
  /// fixes with a hike_id (the janitor's session-grouping is much more robust
  /// when hike_id isn't NULL).
  String? get _effectiveHikeId =>
      _activeHike?.id ?? RecordingProvider.currentHikeId;

  List<TeamMemberLocation> _teamLocations = [];
  List<TeamMemberLocation> get teamLocations => _teamLocations;

  bool _isTracking = false;
  bool get isTracking => _isTracking;
  DateTime? _lastReportAt;
  DateTime? get lastReportAt => _lastReportAt;
  bool _disposed = false;
  bool _reporting = false;
  bool _launchReported = false;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void setActiveHike(HikePlan? hike) {
    _activeHike = hike;
    notifyListeners();
  }

  /// One-shot location push fired when the app first loads. Grabs a single
  /// GPS fix and writes one row to `team_member_locations` so the PC sees
  /// where the hiker is right now — then immediately returns. No streams,
  /// no timers, no background service. Subsequent updates only happen
  /// while a hike is actively recording.
  Future<void> reportOnceOnLaunch() async {
    if (_launchReported || _disposed) return;
    _launchReported = true;
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    try {
      final pos = await LocationService.currentPosition();
      if (pos == null) {
        LoggerService.log('TRACKING',
            'reportOnceOnLaunch: no GPS fix available, skipping');
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
        teamId: _teamProvider?.selectedTeam?.id,
        status: 'active',
        batteryPct: vitals.battery,
        connectivity: vitals.connectivity,
      );
      _lastReportAt = DateTime.now();
      LoggerService.log(
          'TRACKING', 'One-shot launch location reported for $_displayName');
      _safeNotify();
    } catch (e, stack) {
      LoggerService.error('TRACKING', 'reportOnceOnLaunch failed: $e', stack);
    }
  }

  void _startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    _reportNow();
  }

  void _stopTracking() {
    _isTracking = false;
  }

  Future<void> _reportNow() async {
    if (_reporting || _disposed) return;
    _reporting = true;

    try {
      final bool isRecording = _recordingProvider?.isRecording ?? false;
      if (!isRecording) return;

      final uid = _uid;
      if (uid == null || uid.isEmpty) {
        LoggerService.log('TRACKING',
            'TeamTrackingProvider: no signed-in user. Skipping report.');
        return;
      }

      if (_recordingProvider?.isGhostMode ?? false) {
        LoggerService.log('TRACKING',
            'TeamTrackingProvider: Ghost Mode active. Skipping report.');
        return;
      }

      final pos = _recordingProvider?.currentPosition;
      if (pos == null) {
        LoggerService.log('TRACKING', 'Skipping report: GPS position is null');
        return;
      }

      final String? teamId =
          _activeHike?.teamId ?? _teamProvider?.selectedTeam?.id;
      final vitals = await _readDeviceVitals();
      final fixTimestamp = DateTime.now();
      final trackPointRow = <String, dynamic>{
        'uid': uid,
        'team_id': teamId,
        'hike_id': _effectiveHikeId,
        'lat': pos.latitude,
        'lon': pos.longitude,
        'altitude': pos.altitude,
        'heading': pos.heading,
        'speed': pos.speed,
        'status': 'recording',
        'battery_pct': vitals.battery,
        'connectivity': vitals.connectivity,
        'timestamp': fixTimestamp.toUtc().toIso8601String(),
        'synced_offline': false,
        '_display_name': _displayName,
      };

      try {
        await TeamService.reportLocation(
          uid: uid,
          displayName: _displayName,
          lat: pos.latitude,
          lon: pos.longitude,
          heading: pos.heading,
          speed: pos.speed,
          altitude: pos.altitude,
          teamId: teamId,
          hikeId: _effectiveHikeId,
          status: 'recording',
          batteryPct: vitals.battery,
          connectivity: vitals.connectivity,
        );
        try {
          await TeamService.insertTrackPoint(
            uid: uid,
            lat: pos.latitude,
            lon: pos.longitude,
            teamId: teamId,
            hikeId: _effectiveHikeId,
            altitude: pos.altitude,
            heading: pos.heading,
            speed: pos.speed,
            status: 'recording',
            batteryPct: vitals.battery,
            connectivity: vitals.connectivity,
            timestamp: fixTimestamp,
            syncedOffline: false,
          );
        } catch (e) {
          LoggerService.log(
              'TRACKING', 'track point append failed (non-fatal): $e');
        }
        _lastReportAt = DateTime.now();
        LoggerService.log('TRACKING',
            'Location reported successfully for $_displayName at ${pos.latitude}, ${pos.longitude}');
        _safeNotify();
      } catch (e, stack) {
        LoggerService.error(
            'TRACKING', 'reportLocation failed; queueing offline: $e', stack);
        await OfflineTrackQueue.enqueue(trackPointRow);
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

  // Watches `team_member_locations` for OTHER hikers in the selected team
  // (incoming data, not our outgoing GPS). Realtime stream + initial fetch
  // only — no polling timer.
  String? _watchingTeamId;
  StreamSubscription<List<Map<String, dynamic>>>? _teamLocSub;

  void _watchTeamLocations(String? teamId) {
    if (teamId == _watchingTeamId) return;
    _watchingTeamId = teamId;
    _teamLocSub?.cancel();
    _teamLocSub = null;
    if (teamId == null || !kSupabaseAvailable) {
      _teamLocations = const [];
      _safeNotify();
      return;
    }
    refreshTeamLocations(teamId);
    try {
      _teamLocSub = Supabase.instance.client
          .from('team_member_locations')
          .stream(primaryKey: ['uid'])
          .eq('team_id', teamId)
          .listen((rows) {
        if (_disposed) return;
        _teamLocations = rows
            .map((m) => TeamMemberLocation.fromMap(m))
            .toList();
        _safeNotify();
      });
    } catch (e, stack) {
      LoggerService.error('TRACKING',
          'team_member_locations stream subscribe failed: $e', stack);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _teamLocSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
