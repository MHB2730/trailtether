// Pins the Phase 2 defensive-coding behaviour. Each test sends an
// intentionally malformed Supabase / asset payload through the model
// factory and asserts it returns a usable object instead of throwing.
// If any of these regress, the team lists / leaderboard / trail map will
// start dropping rows again — these tests catch that at PR time.

import 'package:flutter_test/flutter_test.dart';
import 'package:trailtether_app/models/accommodation.dart';
import 'package:trailtether_app/models/gpx_track.dart';
import 'package:trailtether_app/models/team.dart';
import 'package:trailtether_app/models/trail.dart';

void main() {
  group('Accommodation.fromJson', () {
    test('survives a missing gps array', () {
      final a = Accommodation.fromJson({
        'name': 'Camp X',
        'type': 'lodge',
        'region': 'Southern',
      });
      expect(a.name, 'Camp X');
      expect(a.lat, 0);
      expect(a.lon, 0);
    });

    test('survives a short or wrongly-typed gps array', () {
      final a = Accommodation.fromJson({
        'name': 'Sparse',
        'gps': ['oops'],
      });
      expect(a.lat, 0);
      expect(a.lon, 0);
    });

    test('reads a valid gps array correctly', () {
      final a = Accommodation.fromJson({
        'name': 'OK',
        'type': 'lodge',
        'region': 'Central',
        'gps': [-29.04, 29.42],
      });
      expect(a.lat, closeTo(-29.04, 1e-6));
      expect(a.lon, closeTo(29.42, 1e-6));
    });
  });

  group('Trail.fromJson', () {
    test('returns a degenerate trail when coords missing', () {
      final t = Trail.fromJson({
        'id': 'x',
        'name': 'Empty',
      });
      expect(t.id, 'x');
      expect(t.coords, isEmpty);
      expect(t.distanceKm, 0.0);
      expect(t.elevationGainM, 0);
    });

    test('skips malformed coord pairs but keeps good ones', () {
      // Coords are intentionally non-colinear (each point bends off the
      // line between its neighbours by ~5 km) so RDP simplification
      // doesn't prune them as redundant.
      final t = Trail.fromJson({
        'id': 'x',
        'name': 'Mixed',
        'distanceKm': 1.5,
        'minEle': 100,
        'maxEle': 200,
        'elevationGainM': 50,
        'estTimeHours': 1.0,
        'coords': [
          [-29.0, 29.0, 1500],
          ['oops'], // ← bad, dropped
          [-29.05, 29.15, 1550], // ← bends off the straight line
          'definitely not a list', // ← bad, dropped
          [-29.2, 29.2], // ← OK (elevation defaults to 0)
        ],
      });
      // After RDP / Chaikin smoothing we keep ≥2 valid coords; the 2 bad
      // entries are dropped before smoothing even runs.
      expect(t.coords.length, greaterThanOrEqualTo(2));
      expect(t.coords.length, lessThanOrEqualTo(3));
    });

    test('defaults distance to 0 when not a number', () {
      final t = Trail.fromJson({
        'id': 'x',
        'name': 'Stringly',
        'distanceKm': 'oops',
      });
      expect(t.distanceKm, 0.0);
    });
  });

  group('UserGpxTrack.fromJson', () {
    test('drops malformed point pairs', () {
      final track = UserGpxTrack.fromJson({
        'id': '1',
        'filename': 'x.gpx',
        'points': [
          [-29.0, 29.0],
          ['oops'],
          [-29.1, 29.1],
        ],
        'elevations': [1500, 'bad', 1600],
      });
      expect(track.points.length, 2);
      expect(track.elevations.length, 2);
    });

    test('survives a missing points key entirely', () {
      final track = UserGpxTrack.fromJson({
        'id': '1',
        'filename': 'x.gpx',
      });
      expect(track.points, isEmpty);
      expect(track.elevations, isEmpty);
      expect(track.distanceKm, 0.0);
    });
  });

  group('Team.fromMap', () {
    test('skips malformed member entries but keeps the team', () {
      final team = Team.fromMap({
        'id': 'team-1',
        'name': 'Test',
        'created_by': 'u1',
        'members': [
          {'uid': 'u1', 'display_name': 'Alice'},
          'not a map', // ← dropped
          {'uid': 'u2', 'display_name': 'Bob'},
        ],
        'member_uids': ['u1', 'u2'],
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(team.id, 'team-1');
      expect(team.members.length, 2);
    });

    test('survives a totally missing members key', () {
      final team = Team.fromMap({
        'id': 'team-2',
        'name': 'Empty',
        'created_by': 'u1',
      });
      expect(team.members, isEmpty);
    });
  });
}
