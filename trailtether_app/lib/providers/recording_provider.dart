import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'package:gpx/gpx.dart' as gpx;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording_point.dart';
import '../models/saved_hike.dart';
import '../models/trail.dart';
import '../models/incident.dart';
import '../services/location_service.dart';
import '../services/logger_service.dart';
import '../services/weather_alert_service.dart';
import '../services/offline_incident_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/utils.dart';
import 'package:flutter/services.dart';
import 'package:battery_plus/battery_plus.dart';

enum RecordingStatus { idle, recording, paused }

class RecordingProvider extends ChangeNotifier {
  /// Shared session id for the currently-recording hike. Static so other
  /// providers (notably TeamTrackingProvider) can stamp track-point inserts
  /// with the same hike_id this provider will use when persisting the
  /// SavedHike — without needing a constructor dependency on this class.
  /// Null while idle. Set in start(), cleared in clear().
  static String? currentHikeId;

  static const _draftKey = 'active_recording_draft_v2';
  static const _maxGoodAccuracyM = 30.0;
  static const _maxAdaptiveAccuracyM =
      100.0; // Increased for better acquisition in deep valleys
  static const _maxPlausibleHikingSpeedMps = 10.0;
  static const _gapWarning = Duration(seconds: 60);

  RecordingStatus _status = RecordingStatus.idle;
  final List<RecordingPoint> _points = [];
  late final UnmodifiableListView<RecordingPoint> _pointsView =
      UnmodifiableListView(_points);

  Trail? _targetTrail;
  List<LatLng> _targetPath = [];
  double _remainingDist = 0.0;
  bool _isOffTrail = false;
  double _offTrailDist = 0.0;
  /// Bearing in degrees (0–360, true north = 0) from current position to the
  /// nearest trail point. Null when on-trail or no target trail is set.
  double? _bearingToTrail;
  LatLng? _nearestTrailPoint;
  DateTime? _offTrailSince;

  String _activityType = 'hike';
  String _activityContext = 'personal';
  String? _customName;

  // Running totals to avoid ConcurrentModificationError and improve performance
  double _totalDistanceM = 0.0;
  double _totalGainM = 0.0;
  double? _lastElevation;

  StreamSubscription<Position>? _sub;
  Position? _currentPosition;
  final Set<String> _notifiedIncidentIds = {};
  Incident? _nearbyIncident;

  DateTime? _startTime;
  DateTime? _pauseTime;
  Duration _totalPausedTime = Duration.zero;
  int _acceptedFixes = 0;
  int _rejectedFixes = 0;
  int _poorAccuracyRejects = 0;
  int _jumpRejects = 0;
  int _staleRejects = 0;
  int _gapWarnings = 0;
  double? _lastAccuracy;
  DateTime? _lastFixTime;
  DateTime? _lastAcceptedTime;
  DateTime? _lastDraftSave;

  // Battery and Privacy
  final Battery _battery = Battery();
  bool _isGhostMode = false;
  bool _isBatterySaver = false;
  int _batteryLevel = 100;
  Timer? _batteryTimer;

  RecordingProvider() {
    _restoreDraft();
  }

  RecordingStatus get status => _status;
  List<RecordingPoint> get points => _pointsView;
  Trail? get targetTrail => _targetTrail;
  double get remainingDist => _remainingDist;
  bool get isOffTrail => _isOffTrail;
  double get offTrailDist => _offTrailDist;
  double? get bearingToTrail => _bearingToTrail;
  LatLng? get nearestTrailPoint => _nearestTrailPoint;
  Duration? get offTrailDuration =>
      _offTrailSince == null ? null : DateTime.now().difference(_offTrailSince!);

  /// Compass-style heading label ("N", "NE", "E", …) for the bearing back to
  /// the trail. Empty string when on-trail.
  String get returnDirection {
    final b = _bearingToTrail;
    if (b == null) return '';
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = ((b + 22.5) % 360 / 45).floor();
    return labels[idx];
  }
  Incident? get nearbyIncident => _nearbyIncident;
  int get acceptedFixes => _acceptedFixes;
  int get rejectedFixes => _rejectedFixes;
  int get poorAccuracyRejects => _poorAccuracyRejects;
  int get jumpRejects => _jumpRejects;
  int get staleRejects => _staleRejects;
  int get gapWarnings => _gapWarnings;
  double? get lastAccuracy => _lastAccuracy;
  DateTime? get lastFixTime => _lastFixTime;
  DateTime? get lastAcceptedTime => _lastAcceptedTime;

  String get activityType => _activityType;
  String get activityContext => _activityContext;
  String? get customName => _customName;
  Position? get currentPosition => _currentPosition;

  bool get isGhostMode => _isGhostMode;
  bool get isBatterySaver => _isBatterySaver;
  int get batteryLevel => _batteryLevel;

  bool get isGpsStale =>
      timeSinceLastAccepted != null && timeSinceLastAccepted! > _gapWarning;

  void setActivityMetadata({String? type, String? context, String? name}) {
    if (type != null) _activityType = type;
    if (context != null) _activityContext = context;
    if (name != null) _customName = name;
    notifyListeners();
  }

  void toggleGhostMode() {
    _isGhostMode = !_isGhostMode;
    LoggerService.log('PRIVACY', 'Ghost Mode set to $_isGhostMode');
    unawaited(_persistDraft());
    notifyListeners();
  }

  void toggleBatterySaver() {
    _isBatterySaver = !_isBatterySaver;
    _updateLocationSettings();
    unawaited(_persistDraft());
    notifyListeners();
  }

  Future<void> _updateBatteryStatus() async {
    try {
      final level = await _battery.batteryLevel;
      _batteryLevel = level;

      // Auto-enable battery saver if below 15%
      if (level < 15 && !_isBatterySaver) {
        _isBatterySaver = true;
        _updateLocationSettings();
        LoggerService.log(
            'BATTERY', 'Low battery ($level%). Auto-enabling Battery Saver.');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error getting battery level: $e');
    }
  }

  void _updateLocationSettings() {
    if (_status != RecordingStatus.recording) return;

    // Cancel and restart stream with new settings
    _sub?.cancel();

    final settings = _isBatterySaver
        ? LocationService.batterySaverSettings
        : LocationService.recordingLocationSettings;

    _sub = LocationService.smooth(Geolocator.getPositionStream(
      locationSettings: settings,
    )).listen(_onPosition, onError: (Object error, StackTrace stack) {
      LoggerService.error('TRACKING', error, stack);
    });
  }

  Duration? get timeSinceLastAccepted {
    if (_lastAcceptedTime == null) return null;
    return DateTime.now().difference(_lastAcceptedTime!);
  }

  String get gpsHealthLabel {
    final accuracy = _lastAccuracy ?? _currentPosition?.accuracy;
    final lastFix = _lastFixTime ?? _currentPosition?.timestamp;
    if (lastFix == null && accuracy == null) return 'WAITING';
    final timeSinceFix =
        lastFix != null ? DateTime.now().difference(lastFix) : Duration.zero;

    if (timeSinceFix > _gapWarning) {
      return 'LOST';
    }
    if (accuracy == null) return 'UNKNOWN';
    if (accuracy <= 10.0) return 'EXCELLENT';
    if (accuracy <= _maxGoodAccuracyM) return 'GOOD';
    if (accuracy <= _maxAdaptiveAccuracyM) return 'WEAK';
    return 'POOR';
  }

  Color get gpsHealthColor {
    final label = gpsHealthLabel;
    switch (label) {
      case 'EXCELLENT':
        return Colors.greenAccent;
      case 'GOOD':
        return Colors.green;
      case 'WEAK':
        return Colors.orange;
      case 'POOR':
        return Colors.redAccent;
      case 'LOST':
      case 'WAITING':
      default:
        return Colors.white24;
    }
  }

  void clearNearbyIncident() {
    _nearbyIncident = null;
    notifyListeners();
  }

  void setTargetTrail(Trail? t) {
    _targetTrail = t;
    _targetPath = t?.coords.map((c) => LatLng(c.lat, c.lon)).toList() ?? [];
    _updateRemaining();
    notifyListeners();
  }

  void setTargetPath(List<LatLng> path) {
    _targetTrail = null;
    _targetPath = path;
    _updateRemaining();
    notifyListeners();
  }

  int _lastNearestIdx = 0;

  List<double>? _segmentDistances;
  void _updateRemaining() {
    if (_targetPath.isEmpty || _points.isEmpty) {
      _remainingDist = 0.0;
      _isOffTrail = false;
      _offTrailDist = 0.0;
      _bearingToTrail = null;
      _nearestTrailPoint = null;
      _offTrailSince = null;
      _lastNearestIdx = 0;
      _segmentDistances = null;
      return;
    }

    final current = _points.last.toLatLng;
    final coords = _targetPath;

    // Pre-calculate segment distances if not already done
    if (_segmentDistances == null ||
        _segmentDistances!.length != coords.length - 1) {
      _segmentDistances = List.generate(coords.length - 1, (i) {
        return Geolocator.distanceBetween(
          coords[i].latitude,
          coords[i].longitude,
          coords[i + 1].latitude,
          coords[i + 1].longitude,
        );
      });
    }

    // 1. Find nearest index on trail with sliding window optimization
    // We only search +/- 50 points around the last nearest index to save CPU.
    int startSearch = (_lastNearestIdx - 50).clamp(0, coords.length - 1);
    int endSearch =
        (_lastNearestIdx + 50).clamp(startSearch, coords.length - 1);

    // If the gap is huge or we haven't started, search everything once.
    if (_lastNearestIdx == 0) {
      startSearch = 0;
      endSearch = coords.length - 1;
    }

    int nearestIdx = startSearch;
    double minDist = double.infinity;

    for (int i = startSearch; i <= endSearch; i++) {
      final d = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        coords[i].latitude,
        coords[i].longitude,
      );
      if (d < minDist) {
        minDist = d;
        nearestIdx = i;
      }
    }

    // If we are at the edge of our window, we might need a wider search
    if (nearestIdx == startSearch || nearestIdx == endSearch) {
      // Only do full search if we are actually moving significantly
      if (minDist > 100) {
        for (int i = 0; i < coords.length; i++) {
          final d = Geolocator.distanceBetween(current.latitude,
              current.longitude, coords[i].latitude, coords[i].longitude);
          if (d < minDist) {
            minDist = d;
            nearestIdx = i;
          }
        }
      }
    }

    _lastNearestIdx = nearestIdx;

    // 2. Sum distance from nearestIdx to end using cached segments
    double totalRemaining = 0;
    for (int i = nearestIdx; i < _segmentDistances!.length; i++) {
      totalRemaining += _segmentDistances![i];
    }

    _remainingDist = totalRemaining / 1000.0;

    // 3. Off-trail check with adaptive threshold.
    //    Base threshold 40m + 1.5× current GPS accuracy so poor signal in deep
    //    valleys doesn't constantly trip a false off-trail alarm. Cap at 120m.
    final accuracySlack = ((_lastAccuracy ?? 0) * 1.5).clamp(0, 80);
    final threshold = (40.0 + accuracySlack).clamp(40.0, 120.0);
    _offTrailDist = minDist;
    final wasOffTrail = _isOffTrail;
    _isOffTrail = minDist > threshold;

    if (_isOffTrail) {
      // Bearing from current position to the nearest trail point — feeds the
      // "guide me back" arrow on the live tracking screen.
      _nearestTrailPoint = coords[nearestIdx];
      _bearingToTrail = Geolocator.bearingBetween(
        current.latitude,
        current.longitude,
        coords[nearestIdx].latitude,
        coords[nearestIdx].longitude,
      );
      // Normalise to 0–360 (bearingBetween returns -180..180).
      if (_bearingToTrail! < 0) _bearingToTrail = _bearingToTrail! + 360;
      _offTrailSince ??= DateTime.now();

      // After 5 minutes off-trail, push an incident so the command centre sees it.
      final dur = DateTime.now().difference(_offTrailSince!);
      if (!wasOffTrail || (dur.inMinutes >= 5 && dur.inMinutes % 5 == 0)) {
        _maybePublishOffTrailAlert(current, threshold);
      }
    } else {
      _bearingToTrail = null;
      _nearestTrailPoint = null;
      _offTrailSince = null;
    }
  }

  DateTime? _lastOffTrailAlertAt;
  void _maybePublishOffTrailAlert(LatLng current, double thresholdM) {
    final now = DateTime.now();
    if (_lastOffTrailAlertAt != null &&
        now.difference(_lastOffTrailAlertAt!).inMinutes < 5) {
      return;
    }
    _lastOffTrailAlertAt = now;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final off = _offTrailDist.round();
    final incidentPayload = {
      // Reuse the existing `lost_disoriented` type for off-trail drift since it
      // best matches the semantic — hiker has deviated from the planned route.
      'type': 'lost_disoriented',
      'severity': 'warning',
      'description':
          'Hiker drifted ${off}m off planned trail. Direction back: $returnDirection.',
      'lat': current.latitude,
      'lon': current.longitude,
      'created_by': uid,
      'reported_by_name': 'Off-trail sentinel',
      'is_emergency': false,
      'status': 'open',
    };
    unawaited(Supabase.instance.client.from('incidents').insert(incidentPayload).then((_) {
      LoggerService.log('OFF_TRAIL',
          'Published off-trail alert: ${off}m, threshold ${thresholdM.toStringAsFixed(0)}m');
    }).catchError((e) {
      LoggerService.error('OFF_TRAIL', 'alert insert failed; queueing offline: $e');
      unawaited(OfflineIncidentQueue.enqueue(incidentPayload));
    }));
  }

  Duration? get eta {
    if (_remainingDist <= 0 || averageSpeedKmh <= 0.1) return null;
    final hours = _remainingDist / averageSpeedKmh;
    return Duration(seconds: (hours * 3600).toInt());
  }

  bool get isRecording => _status == RecordingStatus.recording;
  bool get isPaused => _status == RecordingStatus.paused;

  Duration get duration {
    if (_startTime == null) return Duration.zero;
    final now =
        _status == RecordingStatus.paused ? _pauseTime! : DateTime.now();
    return now.difference(_startTime!) - _totalPausedTime;
  }

  double get distanceKm => _totalDistanceM / 1000.0;

  double get averageSpeedKmh {
    final d = duration.inSeconds;
    if (d <= 0) return 0.0;
    return (distanceKm / (d / 3600.0));
  }

  int get totalGainM => _totalGainM.toInt();

  double get ascentRatio {
    final d = distanceKm;
    if (d <= 0.05) return 0.0;
    return totalGainM / d; // m per km
  }

  Future<bool> start() async {
    final ok = await LocationService.requestPermission(background: true);
    if (!ok) return false;

    _status = RecordingStatus.recording;
    final isFreshSession = _startTime == null;
    _startTime ??= DateTime.now();

    // Allocate a real UUID for this session. Preserved across pause/resume
    // (we only generate one the first time start() is called this session).
    // Used as both the SavedHike.id when persisting and team_member_track_points.hike_id
    // when TeamTrackingProvider pings location.
    if (isFreshSession || currentHikeId == null) {
      currentHikeId = const Uuid().v4();
    }

    if (_pauseTime != null) {
      _totalPausedTime += DateTime.now().difference(_pauseTime!);
      _pauseTime = null;
    }

    // Drop carried-over jitter from any previous session so the first fixes
    // of this hike aren't biased toward stale coordinates.
    if (isFreshSession) LocationService.resetSmoothing();

    LoggerService.log(
      'TRACKING',
      'Recording started. Existing points=${_points.length}, '
          'accepted=$_acceptedFixes, rejected=$_rejectedFixes',
    );

    // Force an immediate high-accuracy fix to kickstart the hardware
    unawaited(Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).then((pos) {
      _currentPosition = pos;
      notifyListeners();
      _onPosition(pos);
    }).catchError((e) {
      LoggerService.error('GPS_KICKSTART', e);
      return null;
    }));

    unawaited(_persistDraft());

    _batteryTimer = Timer.periodic(
        const Duration(minutes: 5), (_) => _updateBatteryStatus());
    await _updateBatteryStatus();

    _sub = LocationService.smooth(Geolocator.getPositionStream(
      locationSettings: _isBatterySaver
          ? LocationService.batterySaverSettings
          : LocationService.recordingLocationSettings,
    )).listen(_onPosition, onError: (Object error, StackTrace stack) {
      LoggerService.error('TRACKING', error, stack);
    });

    // Kick off proactive weather monitoring for this hiker's live location.
    // The alert service uses the multi-source aggregator and pushes
    // notifications + an incident row if bad weather is incoming.
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      WeatherAlertService.instance.start(
        uid: uid,
        locationProvider: () async {
          final p = _currentPosition;
          if (p == null) return null;
          return (lat: p.latitude, lon: p.longitude);
        },
      );
    }

    notifyListeners();
    return true;
  }

  void _onPosition(Position pos) {
    if (_status != RecordingStatus.recording) return;

    _lastFixTime = pos.timestamp;
    _lastAccuracy = pos.accuracy;

    if (!_isFreshFix(pos)) {
      _rejectFix('stale', pos);
      return;
    }

    final newPoint = RecordingPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude,
      timestamp: pos.timestamp,
      speed: pos.speed,
      accuracy: pos.accuracy,
    );

    double distanceFromPrev = 0.0;
    double impliedSpeed = 0.0;

    if (_points.isNotEmpty) {
      final prev = _points.last;
      distanceFromPrev = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );
      final dt = newPoint.timestamp.difference(prev.timestamp);
      if (dt > Duration.zero) {
        impliedSpeed = distanceFromPrev / dt.inMilliseconds * 1000.0;
      }

      if (dt > _gapWarning) {
        _gapWarnings++;
        LoggerService.log(
          'GPS_GAP',
          'gap=${dt.inSeconds}s previous=${prev.timestamp.toIso8601String()} '
              'current=${newPoint.timestamp.toIso8601String()} '
              'distance=${distanceFromPrev.toStringAsFixed(1)}m',
        );
      }

      if (impliedSpeed > _maxPlausibleHikingSpeedMps) {
        _rejectFix(
          'jump',
          pos,
          distanceFromPrev: distanceFromPrev,
          impliedSpeed: impliedSpeed,
        );
        return;
      }
    }

    if (!_isAccurateEnough(pos, distanceFromPrev, impliedSpeed)) {
      _rejectFix(
        'poor_accuracy',
        pos,
        distanceFromPrev: distanceFromPrev,
        impliedSpeed: impliedSpeed,
      );
      return;
    }

    // Update running totals
    if (_points.isNotEmpty) {
      final prev = _points.last;
      _totalDistanceM += distanceFromPrev;

      // Elevation gain (3m threshold to filter noise)
      _lastElevation ??= prev.altitude;
      final diff = newPoint.altitude - _lastElevation!;
      if (diff > 3.0) {
        _totalGainM += diff;
        _lastElevation = newPoint.altitude;
      } else if (diff < -3.0) {
        _lastElevation = newPoint.altitude;
      }
    } else {
      _lastElevation = newPoint.altitude;
    }

    _acceptedFixes++;
    _lastAcceptedTime = newPoint.timestamp;
    _points.add(newPoint);
    LoggerService.log(
      'GPS_ACCEPT',
      'accuracy=${newPoint.accuracy.toStringAsFixed(1)}m '
          'lat=${newPoint.latitude.toStringAsFixed(6)} '
          'lon=${newPoint.longitude.toStringAsFixed(6)} '
          'speed=${newPoint.speed.toStringAsFixed(2)}m/s '
          'delta=${distanceFromPrev.toStringAsFixed(1)}m '
          'implied_speed=${impliedSpeed.toStringAsFixed(2)}m/s '
          'count=${_points.length} '
          'time=${newPoint.timestamp.toIso8601String()}',
    );
    _updateRemaining();

    // NOTE: checkSafetyProximity should be called from the UI layer
    // where SafetyProvider is available, passing current incidents.

    // Persist draft every 30s or every 50 points to avoid jitter
    final now = DateTime.now();
    if (_lastDraftSave == null ||
        now.difference(_lastDraftSave!) > const Duration(seconds: 30) ||
        _points.length % 50 == 0) {
      _lastDraftSave = now;
      unawaited(_persistDraft());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool _isFreshFix(Position pos) {
    if (_points.isEmpty) return true;
    return !pos.timestamp.isBefore(_points.last.timestamp);
  }

  bool _isAccurateEnough(
    Position pos,
    double distanceFromPrev,
    double impliedSpeed,
  ) {
    if (pos.accuracy <= _maxGoodAccuracyM) return true;
    if (pos.accuracy > _maxAdaptiveAccuracyM) return false;
    if (_points.isEmpty) return true;

    final plausibleDistance = distanceFromPrev <= pos.accuracy + 25.0;
    final plausibleSpeed = impliedSpeed <= 2.5;
    return plausibleDistance || plausibleSpeed;
  }

  void _rejectFix(
    String reason,
    Position pos, {
    double distanceFromPrev = 0.0,
    double impliedSpeed = 0.0,
  }) {
    _rejectedFixes++;
    switch (reason) {
      case 'stale':
        _staleRejects++;
        break;
      case 'jump':
        _jumpRejects++;
        break;
      default:
        _poorAccuracyRejects++;
    }

    LoggerService.log(
      'GPS_REJECT',
      'reason=$reason accuracy=${pos.accuracy.toStringAsFixed(1)}m '
          'lat=${pos.latitude.toStringAsFixed(6)} '
          'lon=${pos.longitude.toStringAsFixed(6)} '
          'speed=${pos.speed.toStringAsFixed(2)}m/s '
          'delta=${distanceFromPrev.toStringAsFixed(1)}m '
          'implied_speed=${impliedSpeed.toStringAsFixed(2)}m/s '
          'time=${pos.timestamp.toIso8601String()}',
    );
    notifyListeners();
  }

  void checkSafetyProximity(List<Incident> currentIncidents, Position pos) {
    if (currentIncidents.isEmpty) return;

    for (final inc in currentIncidents) {
      if (_notifiedIncidentIds.contains(inc.id)) continue;

      final dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        inc.lat,
        inc.lon,
      );

      if (dist <= 50.0) {
        _notifiedIncidentIds.add(inc.id);
        _nearbyIncident = inc;
        unawaited(HapticFeedback.vibrate());
      }
    }
  }

  void pause() {
    if (_status != RecordingStatus.recording) return;
    _status = RecordingStatus.paused;
    _pauseTime = DateTime.now();
    _sub?.cancel();
    LoggerService.log(
      'TRACKING',
      'Recording paused. points=${_points.length}, '
          'accepted=$_acceptedFixes, rejected=$_rejectedFixes',
    );
    unawaited(_persistDraft());
    notifyListeners();
  }

  void stop() {
    _status = RecordingStatus.idle;
    _sub?.cancel();
    _sub = null;
    _batteryTimer?.cancel();
    _batteryTimer = null;
    _notifiedIncidentIds.clear();
    _nearbyIncident = null;
    WeatherAlertService.instance.stop();
    LoggerService.log(
      'TRACKING',
      'Recording stopped. points=${_points.length}, '
          'accepted=$_acceptedFixes, rejected=$_rejectedFixes, '
          'distance=${distanceKm.toStringAsFixed(2)}km',
    );
    unawaited(_persistDraft());
    notifyListeners();
  }

  void clear() {
    stop();
    _points.clear();
    _startTime = null;
    _pauseTime = null;
    _totalPausedTime = Duration.zero;
    _totalDistanceM = 0.0;
    _totalGainM = 0.0;
    _lastElevation = null;
    _acceptedFixes = 0;
    _rejectedFixes = 0;
    _poorAccuracyRejects = 0;
    _jumpRejects = 0;
    _staleRejects = 0;
    _gapWarnings = 0;
    _lastAccuracy = null;
    currentHikeId = null;
    _lastFixTime = null;
    _lastAcceptedTime = null;
    _updateRemaining();
    unawaited(_clearDraft());
    notifyListeners();
  }

  Future<void> exportGpx({bool simplify = true}) async {
    if (_points.isEmpty) return;

    final gpxObj = gpx.Gpx();
    gpxObj.creator = 'Trailtether';

    final track = gpx.Trk();
    track.name = _targetTrail?.name ?? 'Trailtether Hike ${DateTime.now()}';

    final segment = gpx.Trkseg();

    final coords = _points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final elevations = _points.map((p) => p.altitude).toList();
    final (exportCoords, exportElevations) = simplify
        ? TrailUtils.simplifyPointsWithElevations(
            coords,
            elevations,
            epsilon: 0.00002, // roughly 2 m in lat/lon degrees
          )
        : (coords, elevations);

    int searchStart = 0;
    segment.trkpts = List.generate(exportCoords.length, (index) {
      final point = exportCoords[index];
      var originalIndex = searchStart;

      while (originalIndex < coords.length &&
          (coords[originalIndex].latitude != point.latitude ||
              coords[originalIndex].longitude != point.longitude)) {
        originalIndex++;
      }

      if (originalIndex >= _points.length) {
        originalIndex = _points.length - 1;
      } else {
        searchStart = originalIndex;
      }

      final original = _points[originalIndex];
      return gpx.Wpt(
        lat: point.latitude,
        lon: point.longitude,
        ele: exportElevations[index],
        time: original.timestamp,
      );
    });

    track.trksegs = [segment];
    gpxObj.trks = [track];

    final gpxString = gpx.GpxWriter().asString(gpxObj, pretty: true);

    final tempDir = await getTemporaryDirectory();
    // Sanitize filename (remove illegal chars like : / \ for Windows/Android safety)
    final safeName = (gpxObj.trks.first.name ?? 'recording')
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(' ', '_');

    final suffix = simplify ? '' : '_raw';
    final file = File('${tempDir.path}/$safeName$suffix.gpx');
    await file.writeAsString(gpxString);
    final diagnosticFile =
        File('${tempDir.path}/$safeName$suffix.diagnostics.json');
    await diagnosticFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_diagnosticsJson(
        mode: simplify ? 'optimized' : 'raw',
        exportedPoints: segment.trkpts.length,
      )),
    );

    LoggerService.log(
      'GPX_EXPORT',
      'mode=${simplify ? 'optimized' : 'raw'} '
          'source_points=${_points.length} '
          'exported_points=${segment.trkpts.length} '
          'path=${file.path}',
    );

    await Share.shareXFiles(
      [XFile(file.path), XFile(diagnosticFile.path)],
      text: 'My hike on Trailtether',
    );
  }

  SavedHike toSavedHike() {
    final safeStart = _startTime ?? _points.first.timestamp;
    final safeEnd = _points.isEmpty ? DateTime.now() : _points.last.timestamp;
    final movingSeconds = _movingSeconds();
    final durationSeconds = duration.inSeconds > 0
        ? duration.inSeconds
        : safeEnd.difference(safeStart).inSeconds;
    final ascentDescent = _ascentDescent();
    final elevations = _points.map((p) => p.altitude).toList();
    final accuracies = _points.map((p) => p.accuracy).where((a) => a > 0);

    return SavedHike(
      // Real UUID, generated once per recording session. Was previously a
      // microsecondsSinceEpoch string which failed RecordedTrailService's
      // insert into recorded_trails (hike_id column is `uuid`, not text);
      // RLS swallowed the error so the table stayed empty even when users
      // tapped SAVE ACTIVITY. Fall back to a fresh uuid if start() was
      // somehow skipped — defensive, shouldn't happen in normal flow.
      id: currentHikeId ?? const Uuid().v4(),
      name: _customName ??
          _targetTrail?.name ??
          'Hike ${_formatDateForName(safeStart)}',
      startedAt: safeStart,
      endedAt: safeEnd,
      points: List.of(_points),
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      movingSeconds: movingSeconds,
      averageSpeedKmh: averageSpeedKmh,
      movingSpeedKmh:
          movingSeconds <= 0 ? 0.0 : distanceKm / (movingSeconds / 3600.0),
      maxSpeedKmh: _maxSpeedKmh(),
      ascentM: ascentDescent.$1.round(),
      descentM: ascentDescent.$2.round(),
      minElevationM: elevations.minOrNull ?? 0.0,
      maxElevationM: elevations.maxOrNull ?? 0.0,
      averageAccuracyM: accuracies.isEmpty
          ? 0.0
          : accuracies.reduce((a, b) => a + b) / accuracies.length,
      bestAccuracyM: accuracies.minOrNull ?? 0.0,
      worstAccuracyM: accuracies.maxOrNull ?? 0.0,
      acceptedFixes: _acceptedFixes,
      rejectedFixes: _rejectedFixes,
      poorAccuracyRejects: _poorAccuracyRejects,
      jumpRejects: _jumpRejects,
      staleRejects: _staleRejects,
      gapWarnings: _gapWarnings,
      activityType: _activityType,
      activityContext: _activityContext,
      benchmarkRouteId: _targetTrail?.id,
    );
  }

  int _movingSeconds() {
    if (_points.length < 2) return 0;
    var moving = Duration.zero;
    for (int i = 1; i < _points.length; i++) {
      final prev = _points[i - 1];
      final current = _points[i];
      final dt = current.timestamp.difference(prev.timestamp);
      if (dt <= Duration.zero) continue;
      final dist = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      );
      final speed = dist / dt.inMilliseconds * 1000.0;
      if (speed >= 0.25) moving += dt;
    }
    return moving.inSeconds;
  }

  double _maxSpeedKmh() {
    if (_points.length < 2) return 0.0;
    var maxSpeed = 0.0;
    for (int i = 1; i < _points.length; i++) {
      final prev = _points[i - 1];
      final current = _points[i];
      final dt = current.timestamp.difference(prev.timestamp);
      if (dt <= Duration.zero) continue;
      final dist = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      );
      final speedKmh = (dist / dt.inMilliseconds * 1000.0) * 3.6;
      if (speedKmh > maxSpeed) maxSpeed = speedKmh;
    }
    return maxSpeed;
  }

  (double, double) _ascentDescent() {
    if (_points.length < 2) return (0.0, 0.0);
    var ascent = 0.0;
    var descent = 0.0;
    var baseline = _points.first.altitude;

    for (final point in _points.skip(1)) {
      final diff = point.altitude - baseline;
      if (diff > 3.0) {
        ascent += diff;
        baseline = point.altitude;
      } else if (diff < -3.0) {
        descent += diff.abs();
        baseline = point.altitude;
      }
    }
    return (ascent, descent);
  }

  String _formatDateForName(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> _diagnosticsJson({
    required String mode,
    required int exportedPoints,
  }) =>
      {
        'mode': mode,
        'source_points': _points.length,
        'exported_points': exportedPoints,
        'accepted_fixes': _acceptedFixes,
        'rejected_fixes': _rejectedFixes,
        'poor_accuracy_rejects': _poorAccuracyRejects,
        'jump_rejects': _jumpRejects,
        'stale_rejects': _staleRejects,
        'gap_warnings': _gapWarnings,
        'last_accuracy_m': _lastAccuracy,
        'last_fix_time': _lastFixTime?.toIso8601String(),
        'last_accepted_time': _lastAcceptedTime?.toIso8601String(),
        'distance_km': distanceKm,
        'duration_seconds': duration.inSeconds,
      };

  Future<void> _persistDraft() async {
    if (_points.isEmpty && _status == RecordingStatus.idle) {
      await _clearDraft();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey,
      jsonEncode({
        'points': _points.map((p) => p.toJson()).toList(),
        'status': _status.name,
        'start_time': _startTime?.toIso8601String(),
        'pause_time': _pauseTime?.toIso8601String(),
        'total_paused_seconds': _totalPausedTime.inSeconds,
        'accepted': _acceptedFixes,
        'rejected': _rejectedFixes,
        'poor_accuracy_rejects': _poorAccuracyRejects,
        'jump_rejects': _jumpRejects,
        'stale_rejects': _staleRejects,
        'gap_warnings': _gapWarnings,
        'last_accuracy': _lastAccuracy,
        'last_fix_time': _lastFixTime?.toIso8601String(),
        'last_accepted_time': _lastAcceptedTime?.toIso8601String(),
        'is_ghost_mode': _isGhostMode,
        'is_battery_saver': _isBatterySaver,
      }),
    );
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final restoredPoints = (data['points'] as List<dynamic>? ?? [])
          .map((p) => RecordingPoint.fromJson(p as Map<String, dynamic>))
          .toList();
      if (restoredPoints.isEmpty) return;

      _points
        ..clear()
        ..addAll(restoredPoints);
      _status = RecordingStatus.paused;
      _startTime =
          _parseDate(data['start_time']) ?? restoredPoints.first.timestamp;
      _pauseTime = DateTime.now();
      _totalPausedTime = Duration(seconds: data['total_paused_seconds'] ?? 0);
      _acceptedFixes = data['accepted'] ?? restoredPoints.length;
      _rejectedFixes = data['rejected'] ?? 0;
      _poorAccuracyRejects = data['poor_accuracy_rejects'] ?? 0;
      _jumpRejects = data['jump_rejects'] ?? 0;
      _staleRejects = data['stale_rejects'] ?? 0;
      _gapWarnings = data['gap_warnings'] ?? 0;
      _lastAccuracy = (data['last_accuracy'] as num?)?.toDouble();
      _lastFixTime = _parseDate(data['last_fix_time']);
      _lastAcceptedTime = _parseDate(data['last_accepted_time']) ??
          restoredPoints.last.timestamp;
      _isGhostMode = data['is_ghost_mode'] ?? false;
      _isBatterySaver = data['is_battery_saver'] ?? false;
      _recalculateTotals();
      _updateRemaining();
      LoggerService.log(
        'TRACKING',
        'Restored draft recording. points=${_points.length}, '
            'accepted=$_acceptedFixes, rejected=$_rejectedFixes',
      );
      notifyListeners();
    } catch (e, stack) {
      LoggerService.error(
          'TRACKING', 'Failed to restore recording draft: $e', stack);
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  void _recalculateTotals() {
    _totalDistanceM = 0.0;
    _totalGainM = 0.0;
    _lastElevation = null;

    for (int i = 0; i < _points.length; i++) {
      final point = _points[i];
      if (i == 0) {
        _lastElevation = point.altitude;
        continue;
      }

      final prev = _points[i - 1];
      _totalDistanceM += Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        point.latitude,
        point.longitude,
      );

      final diff = point.altitude - (_lastElevation ?? prev.altitude);
      if (diff > 3.0) {
        _totalGainM += diff;
        _lastElevation = point.altitude;
      } else if (diff < -3.0) {
        _lastElevation = point.altitude;
      }
    }
  }
}
