import 'dart:convert';
import 'recording_point.dart';

class SavedHike {
  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<RecordingPoint> points;
  final double distanceKm;
  final int durationSeconds;
  final int movingSeconds;
  final double averageSpeedKmh;
  final double movingSpeedKmh;
  final double maxSpeedKmh;
  final int ascentM;
  final int descentM;
  final double minElevationM;
  final double maxElevationM;
  final double averageAccuracyM;
  final double bestAccuracyM;
  final double worstAccuracyM;
  final int acceptedFixes;
  final int rejectedFixes;
  final int poorAccuracyRejects;
  final int jumpRejects;
  final int staleRejects;
  final int gapWarnings;
  final String activityType; // hike, walk, run
  final String activityContext; // personal, training, team
  final String? benchmarkRouteId;
  final String? teamId;
  final int peaksClimbed;

  const SavedHike({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.endedAt,
    required this.points,
    required this.distanceKm,
    required this.durationSeconds,
    required this.movingSeconds,
    required this.averageSpeedKmh,
    required this.movingSpeedKmh,
    required this.maxSpeedKmh,
    required this.ascentM,
    required this.descentM,
    required this.minElevationM,
    required this.maxElevationM,
    required this.averageAccuracyM,
    required this.bestAccuracyM,
    required this.worstAccuracyM,
    required this.acceptedFixes,
    required this.rejectedFixes,
    required this.poorAccuracyRejects,
    required this.jumpRejects,
    required this.staleRejects,
    required this.gapWarnings,
    this.activityType = 'hike',
    this.activityContext = 'personal',
    this.benchmarkRouteId,
    this.teamId,
    this.peaksClimbed = 0,
  });

  int get pointCount => points.length;
  int get stoppedSeconds => durationSeconds - movingSeconds;
  double get elevationRangeM => maxElevationM - minElevationM;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'points': points.map((p) => p.toJson()).toList(),
        'distance_km': distanceKm,
        'duration_seconds': durationSeconds,
        'moving_seconds': movingSeconds,
        'average_speed_kmh': averageSpeedKmh,
        'moving_speed_kmh': movingSpeedKmh,
        'max_speed_kmh': maxSpeedKmh,
        'ascent_m': ascentM,
        'descent_m': descentM,
        'min_elevation_m': minElevationM,
        'max_elevation_m': maxElevationM,
        'average_accuracy_m': averageAccuracyM,
        'best_accuracy_m': bestAccuracyM,
        'worst_accuracy_m': worstAccuracyM,
        'accepted_fixes': acceptedFixes,
        'rejected_fixes': rejectedFixes,
        'poor_accuracy_rejects': poorAccuracyRejects,
        'jump_rejects': jumpRejects,
        'stale_rejects': staleRejects,
        'gap_warnings': gapWarnings,
        'activity_type': activityType,
        'activity_context': activityContext,
        'benchmark_route_id': benchmarkRouteId,
        'team_id': teamId,
        'peaks_climbed': peaksClimbed,
      };

  factory SavedHike.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final startedAt =
        DateTime.tryParse(json['started_at'] as String? ?? '') ?? now;
    final endedAt = DateTime.tryParse(json['ended_at'] as String? ?? '') ?? now;
    final rawPoints = (json['points'] as List<dynamic>? ?? []);
    final points = <RecordingPoint>[];
    for (final p in rawPoints) {
      try {
        points.add(RecordingPoint.fromJson(p as Map<String, dynamic>));
      } catch (_) {
        // Skip malformed points rather than discarding the entire hike.
      }
    }
    return SavedHike(
        // id falls back to "" rather than throwing — caller can still render
        // the row; deleting/editing flows that genuinely need an id check it.
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? 'Hike',
        startedAt: startedAt,
        endedAt: endedAt,
        points: points,
        distanceKm: (json['distance_km'] as num? ?? 0).toDouble(),
        durationSeconds: json['duration_seconds'] as int? ?? 0,
        movingSeconds: json['moving_seconds'] as int? ?? 0,
        averageSpeedKmh: (json['average_speed_kmh'] as num? ?? 0).toDouble(),
        movingSpeedKmh: (json['moving_speed_kmh'] as num? ?? 0).toDouble(),
        maxSpeedKmh: (json['max_speed_kmh'] as num? ?? 0).toDouble(),
        ascentM: json['ascent_m'] as int? ?? 0,
        descentM: json['descent_m'] as int? ?? 0,
        minElevationM: (json['min_elevation_m'] as num? ?? 0).toDouble(),
        maxElevationM: (json['max_elevation_m'] as num? ?? 0).toDouble(),
        averageAccuracyM: (json['average_accuracy_m'] as num? ?? 0).toDouble(),
        bestAccuracyM: (json['best_accuracy_m'] as num? ?? 0).toDouble(),
        worstAccuracyM: (json['worst_accuracy_m'] as num? ?? 0).toDouble(),
        acceptedFixes: json['accepted_fixes'] as int? ?? 0,
        rejectedFixes: json['rejected_fixes'] as int? ?? 0,
        poorAccuracyRejects: json['poor_accuracy_rejects'] as int? ?? 0,
        jumpRejects: json['jump_rejects'] as int? ?? 0,
        staleRejects: json['stale_rejects'] as int? ?? 0,
        gapWarnings: json['gap_warnings'] as int? ?? 0,
        activityType: json['activity_type'] as String? ?? 'hike',
        activityContext: json['activity_context'] as String? ?? 'personal',
        benchmarkRouteId: json['benchmark_route_id'] as String?,
        teamId: json['team_id'] as String?,
        peaksClimbed: json['peaks_climbed'] as int? ?? 0,
      );
  }

  static String encodeList(List<SavedHike> hikes) =>
      jsonEncode(hikes.map((h) => h.toJson()).toList());

  static List<SavedHike> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((h) => SavedHike.fromJson(h as Map<String, dynamic>))
        .toList();
  }
}
