import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../core/runtime_config.dart';
import '../models/incident.dart';
import '../services/incident_service.dart';
import '../services/notification_service.dart';

/// Central source for all safety-related data (Incidents, SOS status).
/// Consolidates IncidentProvider and provides a shared stream for alerts.
class SafetyProvider extends ChangeNotifier {
  List<Incident> _incidents = [];
  StreamSubscription<List<Incident>>? _sub;
  bool _loading = false;
  String? _error;

  /// Most recently reported user location — used by proximity alerts so a hiker
  /// gets pinged when an incident lands within [kProximityRadiusKm] of them.
  double? _userLat;
  double? _userLon;

  /// Hard radius cap for "this is relevant to me" alerts. Tunable per build.
  static const double kProximityRadiusKm = 5.0;

  List<Incident> get incidents => List.unmodifiable(_incidents);
  bool get loading => _loading;
  String? get error => _error;

  /// Update the user's current location so proximity-based alerting can work.
  /// Called from the recording provider whenever a fresh GPS fix arrives.
  void setUserLocation(double? lat, double? lon) {
    _userLat = lat;
    _userLon = lon;
  }

  /// Incidents within [radiusKm] of [lat]/[lon], sorted nearest-first.
  List<({Incident incident, double distanceKm})> nearMe({
    required double lat,
    required double lon,
    double radiusKm = kProximityRadiusKm,
  }) {
    final out = <({Incident incident, double distanceKm})>[];
    for (final inc in _incidents) {
      final d = _haversineKm(lat, lon, inc.lat, inc.lon);
      if (d <= radiusKm) out.add((incident: inc, distanceKm: d));
    }
    out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return out;
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  SafetyProvider() {
    if (kSupabaseAvailable) _listen();
  }

  void _listen() {
    _loading = true;
    notifyListeners();

    _sub?.cancel();
    _sub = IncidentService.allIncidents().listen(
      (list) {
        try {
          // Filter out dummy error incidents and resolved incidents
          final activeIncidents = list.where((i) {
            return i.id != 'error' &&
                i.status != 'resolved' &&
                i.status != 'flagged';
          }).toList();

          // Detect new emergency incidents for real-time alerting.
          // For non-emergency hazards, only alert if they're within
          // [kProximityRadiusKm] of the user — "global" hazards 500 km away
          // are not useful and create alert fatigue.
          if (_incidents.isNotEmpty) {
            final newOnes = activeIncidents.where((incident) {
              return !_incidents.any((old) => old.id == incident.id);
            });

            for (final inc in newOnes) {
              if (inc.isEmergency) {
                _showEmergencyAlert(inc);
                continue;
              }
              if (_userLat != null && _userLon != null) {
                final d = _haversineKm(_userLat!, _userLon!, inc.lat, inc.lon);
                if (d <= kProximityRadiusKm) {
                  _showProximityAlert(inc, d);
                }
              }
            }
          }

          _incidents = activeIncidents;
          _loading = false;
          _error = null;
          notifyListeners();
        } catch (e, stack) {
          debugPrint('SafetyProvider listener error: $e\n$stack');
        }
      },
      onError: (e) {
        _loading = false;
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void _showEmergencyAlert(Incident incident) {
    final isBroadcast = incident.type == IncidentType.broadcast;
    NotificationService.instance.showNotification(
      id: incident.id.hashCode,
      title: isBroadcast ? '📢 SYSTEM BROADCAST' : '⚠️ EMERGENCY ALERT',
      body: isBroadcast
          ? incident.description
          : 'Someone reported a ${incident.type.label} at ${incident.lat.toStringAsFixed(4)}, ${incident.lon.toStringAsFixed(4)}',
      sound: isBroadcast ? 'notification' : 'emergency',
      isEmergency: true,
    );
  }

  void _showProximityAlert(Incident incident, double distanceKm) {
    final distStr = distanceKm < 1
        ? '${(distanceKm * 1000).round()}m'
        : '${distanceKm.toStringAsFixed(1)}km';
    NotificationService.instance.showNotification(
      id: incident.id.hashCode,
      title: '⚠️ Hazard nearby — $distStr away',
      body: '${incident.type.label}: ${incident.description}',
      sound: 'notification',
      isEmergency: false,
    );
  }

  void refresh() {
    if (kSupabaseAvailable) _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
