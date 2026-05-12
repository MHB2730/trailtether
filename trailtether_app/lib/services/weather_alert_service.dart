import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weather.dart';
import 'logger_service.dart';
import 'notification_service.dart';
import 'weather_aggregator_service.dart';

/// Predicts incoming bad weather for the active hiker and pushes notifications
/// with enough lead time for the hiker to find shelter.
///
/// Design:
///  - One-shot tick every 10 minutes by default (configurable).
///  - Examines the next 6 hours from the multi-source aggregator.
///  - If a "bad" hourly slice appears with ≥45 minutes of lead time, fires a
///    notification — but only once per (location, severity-band) until the
///    window resets, so the hiker isn't spammed.
///  - Mirrors the alert into the [incidents] table as a `weatherEvent` so the
///    PC command centre sees it on the same live feed as everything else.
class WeatherAlertService {
  WeatherAlertService._();
  static final WeatherAlertService instance = WeatherAlertService._();

  Timer? _timer;
  bool _running = false;

  /// Last alert key fired per uid — prevents duplicate notifications for the
  /// same forecast slice.
  final Map<String, String> _lastAlertKey = {};

  /// Start a recurring scan for the given location provider. The provider
  /// should return the hiker's current `(lat, lon)` or null when no live
  /// tracking is happening.
  void start({
    required Future<({double lat, double lon})?> Function() locationProvider,
    required String uid,
    Duration interval = const Duration(minutes: 10),
  }) {
    if (_running) return;
    _running = true;
    LoggerService.log('WEATHER_ALERT',
        'Started proactive weather monitoring (every ${interval.inMinutes}m)');

    // Run once immediately for instant feedback, then on a fixed cadence.
    _scan(locationProvider, uid);
    _timer = Timer.periodic(interval, (_) => _scan(locationProvider, uid));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    LoggerService.log('WEATHER_ALERT', 'Stopped weather monitoring');
  }

  Future<void> _scan(
    Future<({double lat, double lon})?> Function() locationProvider,
    String uid,
  ) async {
    try {
      final loc = await locationProvider();
      if (loc == null) {
        return; // Hiker isn't live — nothing to monitor.
      }

      final data = await WeatherAggregatorService.fetch(
        lat: loc.lat,
        lon: loc.lon,
      );
      if (data == null) return;

      final threat = _findIncomingThreat(data);
      if (threat == null) {
        // All clear — clear any stale alert key so a future event re-alerts.
        _lastAlertKey.remove(uid);
        return;
      }

      final alertKey =
          '${threat.severity}|${threat.atHour.toIso8601String()}';
      if (_lastAlertKey[uid] == alertKey) {
        // Same threat we already alerted on. Stay quiet.
        return;
      }
      _lastAlertKey[uid] = alertKey;

      await _fireAlert(uid: uid, threat: threat, lat: loc.lat, lon: loc.lon);
    } catch (e, stack) {
      LoggerService.error('WEATHER_ALERT', 'scan failed: $e', stack);
    }
  }

  _Threat? _findIncomingThreat(WeatherData data) {
    final now = DateTime.now();
    // Look at upcoming hourly slices for the next 6 hours.
    for (final h in data.hourly) {
      final lead = h.time.difference(now);
      if (lead.isNegative) continue;
      if (lead.inHours > 6) break;

      final severity = _classifyHour(h);
      if (severity == _Severity.none) continue;

      // Only alert if there's at least 45 minutes lead time. Less than that and
      // it's already arriving — no useful warning we can give.
      if (lead.inMinutes < 45) continue;

      return _Threat(
        atHour: h.time,
        leadTime: lead,
        severity: severity,
        slice: h,
      );
    }
    return null;
  }

  _Severity _classifyHour(HourlySlice h) {
    // Thunderstorm / hail (WMO 95-99) is always severe.
    if (h.weatherCode >= 95) return _Severity.severe;

    // Heavy rain or strong winds = severe.
    if (h.windSpeed > 55 || h.precipitation > 8 || h.precipProbability > 80) {
      return _Severity.severe;
    }

    // Moderate rain + reduced visibility = caution.
    if (h.windSpeed > 35 ||
        h.precipitation > 3 ||
        h.precipProbability > 55 ||
        h.visibility < 1000) {
      return _Severity.caution;
    }

    return _Severity.none;
  }

  Future<void> _fireAlert({
    required String uid,
    required _Threat threat,
    required double lat,
    required double lon,
  }) async {
    final leadStr = threat.leadTime.inMinutes >= 60
        ? '${(threat.leadTime.inMinutes / 60).toStringAsFixed(1)}h'
        : '${threat.leadTime.inMinutes}m';
    final code = threat.slice.weatherCode;
    final desc = weatherDescription(code);

    final title = threat.severity == _Severity.severe
        ? '⛔ Severe weather in $leadStr'
        : '⚠️ Weather warning — $leadStr out';
    final body = threat.severity == _Severity.severe
        ? '$desc expected. Find shelter now. '
            'Wind ${threat.slice.windSpeed.round()}km/h, '
            'rain ${threat.slice.precipitation.toStringAsFixed(1)}mm.'
        : '$desc moving in. Plan a turnaround point. '
            'Wind ${threat.slice.windSpeed.round()}km/h, '
            'precip ${threat.slice.precipProbability}%.';

    // Local notification to the hiker.
    await NotificationService.instance.showNotification(
      id: 90000 + threat.atHour.hour,
      title: title,
      body: body,
      sound: threat.severity == _Severity.severe ? 'emergency' : 'notification',
      isEmergency: threat.severity == _Severity.severe,
    );

    // Mirror to incidents so the PC command centre + other team members see it.
    try {
      await Supabase.instance.client.from('incidents').insert({
        'type': 'weather_event',
        'severity':
            threat.severity == _Severity.severe ? 'critical' : 'warning',
        'description': '$title — $body',
        'lat': lat,
        'lon': lon,
        'created_by': uid,
        'reported_by_name': 'Weather sentinel',
        'is_emergency': threat.severity == _Severity.severe,
        'status': 'open',
      });
    } catch (e) {
      // Don't let DB errors block the notification — that already fired.
      debugPrint('weather incident insert failed: $e');
    }

    LoggerService.log('WEATHER_ALERT',
        'Fired ${threat.severity.name} alert for $uid: $desc at ${threat.atHour}');
  }
}

class _Threat {
  final DateTime atHour;
  final Duration leadTime;
  final _Severity severity;
  final HourlySlice slice;

  const _Threat({
    required this.atHour,
    required this.leadTime,
    required this.severity,
    required this.slice,
  });
}

enum _Severity { none, caution, severe }
