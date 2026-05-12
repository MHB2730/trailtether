import 'package:flutter_test/flutter_test.dart';
import 'package:trailtether_app/models/recording_point.dart';
import 'package:trailtether_app/models/incident.dart';
import 'package:trailtether_app/core/kalman_filter.dart';

void main() {
  group('RecordingPoint.fromJson', () {
    test('parses a valid fix', () {
      final p = RecordingPoint.fromJson({
        'lat': -29.5,
        'lon': 29.2,
        'alt': 1800,
        'ts': '2026-05-03T12:00:00.000Z',
        'spd': 1.4,
        'acc': 5.0,
      });
      expect(p.latitude, -29.5);
      expect(p.longitude, 29.2);
      expect(p.altitude, 1800);
      expect(p.speed, 1.4);
    });

    test('rejects out-of-range coordinates', () {
      expect(
        () => RecordingPoint.fromJson({'lat': 95.0, 'lon': 0.0}),
        throwsFormatException,
      );
      expect(
        () => RecordingPoint.fromJson({'lat': 0.0, 'lon': -200.0}),
        throwsFormatException,
      );
    });

    test('rejects NaN coordinates', () {
      expect(
        () => RecordingPoint.fromJson({'lat': double.nan, 'lon': 0.0}),
        throwsFormatException,
      );
    });

    test('falls back to now() for missing timestamp', () {
      final p = RecordingPoint.fromJson({'lat': 0.0, 'lon': 0.0});
      final delta = DateTime.now().difference(p.timestamp).abs();
      expect(delta.inSeconds < 5, isTrue);
    });
  });

  group('Incident.tryFromMap', () {
    test('returns null for missing coordinates', () {
      expect(Incident.tryFromMap({'id': 'x'}), isNull);
    });

    test('returns null for out-of-range coordinates', () {
      expect(
        Incident.tryFromMap({'id': 'x', 'lat': 99, 'lon': 0}),
        isNull,
      );
    });

    test('parses a valid row', () {
      final inc = Incident.tryFromMap({
        'id': 'abc',
        'lat': -29.5,
        'lon': 29.2,
        'type': 'rockfall',
        'severity': 'critical',
        'description': 'test',
        'incident_date': '2026-05-03T12:00:00.000Z',
        'reported_at': '2026-05-03T12:00:00.000Z',
      });
      expect(inc, isNotNull);
      expect(inc!.lat, -29.5);
      expect(inc.severity, IncidentSeverity.critical);
    });
  });

  group('KalmanFilter', () {
    test('passes through NaN/Infinity instead of poisoning state', () {
      final k = KalmanFilter();
      // Seed a valid fix
      k.process(-29.5, 29.2);
      // Bad fix should not corrupt state
      final (badLat, badLon) = k.process(double.nan, double.infinity);
      expect(badLat.isNaN, isTrue);
      expect(badLon.isInfinite, isTrue);
      // Next valid fix should still produce finite output
      final (lat, lon) = k.process(-29.51, 29.21);
      expect(lat.isFinite, isTrue);
      expect(lon.isFinite, isTrue);
    });

    test('reset clears state so new sessions start fresh', () {
      final k = KalmanFilter();
      k.process(-29.5, 29.2);
      k.reset();
      // First fix after reset returns the input unchanged
      final (lat, lon) = k.process(10.0, 20.0);
      expect(lat, 10.0);
      expect(lon, 20.0);
    });
  });
}
