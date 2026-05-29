import 'dart:math' as math;

class TrailCoord {
  final double lon;
  final double lat;
  final double elevation; // metres
  const TrailCoord(this.lon, this.lat, this.elevation);
}

class ElevationPoint {
  final double distanceKm;
  final double elevationM;
  const ElevationPoint(this.distanceKm, this.elevationM);
}

class Trail {
  final String id;
  final String name;
  final double distanceKm;
  final int elevationGainM;

  /// Total descent in metres, computed from smoothed 3D coords.
  final int elevationDescentM;
  final double estTimeHours;
  final String difficulty;
  final int minEle;
  final int maxEle;
  final String description;

  /// Whether the trail is visible in the public catalogue. Mirrors the
  /// `published` column and is admin-editable from the PC Trails screen.
  final bool published;

  final List<TrailCoord> coords;
  final List<ElevationPoint> profile;

  /// Pre-computed bounding box. Computed once at construction so callers
  /// don't pay an O(N) sweep over coords on every read.
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  Trail({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.elevationGainM,
    required this.elevationDescentM,
    required this.estTimeHours,
    required this.difficulty,
    required this.minEle,
    required this.maxEle,
    required this.description,
    required this.coords,
    required this.profile,
    this.published = true,
  })  : minLat = coords.isEmpty
            ? 0
            : coords.fold(coords.first.lat, (a, c) => math.min(a, c.lat)),
        maxLat = coords.isEmpty
            ? 0
            : coords.fold(coords.first.lat, (a, c) => math.max(a, c.lat)),
        minLon = coords.isEmpty
            ? 0
            : coords.fold(coords.first.lon, (a, c) => math.min(a, c.lon)),
        maxLon = coords.isEmpty
            ? 0
            : coords.fold(coords.first.lon, (a, c) => math.max(a, c.lon));

  // ── Computed properties ────────────────────────────────────────────

  /// True when this route visits or leads to a cave.
  bool get isCave => name.toLowerCase().contains('cave');

  /// The highest-altitude coordinate, used as the cave pin position when a
  /// route is associated with a cave or shelter.
  TrailCoord? get cavePin {
    if (coords.isEmpty) return null;
    return coords.reduce((a, b) => a.elevation > b.elevation ? a : b);
  }

  double get avgGradePct =>
      distanceKm > 0 ? elevationGainM / (distanceKm * 1000) * 100 : 0;

  /// Naismith-adjusted time in hours.
  /// paceFactor: 0.7 = fast, 1.0 = moderate, 1.3 = slow
  double naismithHours(double paceFactor) {
    const baseSpeedKmh = 5.0;
    const ascentPerHour = 600; // metres
    final walkHrs = distanceKm / baseSpeedKmh;
    final climbHrs = elevationGainM / ascentPerHour;
    return (walkHrs + climbHrs) * paceFactor;
  }

  String formattedTime(double paceFactor) {
    final hrs = naismithHours(paceFactor);
    final h = hrs.floor();
    final mins = ((hrs - h) * 60).round();
    if (h == 0) return '${mins}m';
    return mins > 0 ? '${h}h ${mins}m' : '${h}h';
  }

  TrailCoord? coordAtDistanceKm(double distanceKm) {
    if (coords.isEmpty) return null;
    if (coords.length == 1) return coords.first;

    final targetKm = distanceKm.clamp(0.0, this.distanceKm).toDouble();
    double travelledKm = 0;

    for (int i = 1; i < coords.length; i++) {
      final a = coords[i - 1];
      final b = coords[i];
      final segmentKm = _coordDistanceKm(a, b);
      if (segmentKm <= 0) continue;

      if (travelledKm + segmentKm >= targetKm) {
        final t = ((targetKm - travelledKm) / segmentKm).clamp(0.0, 1.0);
        return TrailCoord(
          a.lon + (b.lon - a.lon) * t,
          a.lat + (b.lat - a.lat) * t,
          a.elevation + (b.elevation - a.elevation) * t,
        );
      }

      travelledKm += segmentKm;
    }

    return coords.last;
  }

  // ── Factory ────────────────────────────────────────────────────────

  factory Trail.fromJson(Map<String, dynamic> json) {
    // Required structural keys default to empty lists rather than throwing
    // so a single malformed row (missing coords / profile, or with stringly-
    // typed numbers) renders as a degenerate trail instead of disappearing
    // the whole row. The caller (TrailService.loadTrails) has a try/catch
    // for outright corrupt rows; this layer handles "mostly-good" rows.
    final rawCoords = (json['coords'] is List)
        ? json['coords'] as List<dynamic>
        : const <dynamic>[];
    final rawProfile =
        (json['profile'] is List) ? json['profile'] as List<dynamic> : null;

    final coords = <TrailCoord>[];
    for (final c in rawCoords) {
      if (c is! List || c.length < 2) continue;
      final rawLat = c[0];
      final rawLon = c[1];
      if (rawLat is! num || rawLon is! num) continue;
      final rawEle = c.length > 2 ? c[2] : 0;
      coords.add(TrailCoord(
        rawLat.toDouble(),
        rawLon.toDouble(),
        (rawEle is num) ? rawEle.toDouble() : 0.0,
      ));
    }

    // ── Route Path Smoothing ───────────────────────────────────────────
    // 1. Simplify (RDP) to remove redundant noise while keeping the shape
    var processedCoords = _simplifyRDP(coords, 1.5); // 1.5m tolerance

    // 2. Chaikin smoothing to round out sharp corners from jagged GPS hits
    if (processedCoords.length > 3 && processedCoords.length < 500) {
      processedCoords = _chaikinSmooth(processedCoords, 1);
    }

    // ── Shared smoothed elevation array ──────────────────────────────────
    // Use processedCoords for stats and profile
    final has3d = processedCoords.isNotEmpty &&
        processedCoords.any((c) => c.elevation != 0);

    // Cumulative Haversine distances (km) for each coord
    final cumDists = List<double>.filled(processedCoords.length, 0);
    if (processedCoords.length > 1) {
      const R = 6371.0;
      for (int i = 1; i < processedCoords.length; i++) {
        final dLat = _radJ(processedCoords[i].lat - processedCoords[i - 1].lat);
        final dLon = _radJ(processedCoords[i].lon - processedCoords[i - 1].lon);
        final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(_radJ(processedCoords[i - 1].lat)) *
                math.cos(_radJ(processedCoords[i].lat)) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);
        cumDists[i] = cumDists[i - 1] +
            R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      }
    }

    // 5-point moving-average smoothing to strip GPS elevation noise
    final smoothedEle = has3d
        ? List<double>.generate(processedCoords.length, (i) {
            final lo = math.max(0, i - 2);
            final hi = math.min(processedCoords.length - 1, i + 2);
            double sum = 0;
            for (int j = lo; j <= hi; j++) {
              sum += processedCoords[j].elevation;
            }
            return sum / (hi - lo + 1);
          })
        : <double>[];

    // ── Build elevation profile ───────────────────────────────────────────
    List<ElevationPoint> profile;
    if (rawProfile != null && rawProfile.isNotEmpty) {
      profile = <ElevationPoint>[];
      for (final p in rawProfile) {
        if (p is! List || p.length < 2) continue;
        final rawDist = p[0];
        final rawElev = p[1];
        if (rawDist is! num || rawElev is! num) continue;
        profile.add(ElevationPoint(rawDist.toDouble(), rawElev.toDouble()));
      }
    } else if (has3d) {
      // Downsample to ≤ 200 points, always including the last point.
      // Indices reference processedCoords, not raw coords — length differs
      // after RDP simplification + Chaikin smoothing.
      profile = [];
      const int maxPts = 200;
      final step = math.max(1, processedCoords.length ~/ maxPts);
      for (int i = 0; i < processedCoords.length; i += step) {
        profile.add(ElevationPoint(cumDists[i], smoothedEle[i]));
      }
      final last = processedCoords.length - 1;
      if (profile.isEmpty || profile.last.distanceKm < cumDists[last] - 0.001) {
        profile.add(ElevationPoint(cumDists[last], smoothedEle[last]));
      }
    } else {
      profile = [];
    }

    // ── Elevation stats — always computed from smoothed 3D coords ────────
    // Threshold of 1.0 m filters residual noise after smoothing.
    int coordGain = 0; // gain derived from smoothed 3D coords (0 if no 3D data)
    int elevDescent = 0;
    int minEleVal =
        (json['minEle'] is num) ? (json['minEle'] as num).toInt() : 0;
    int maxEleVal =
        (json['maxEle'] is num) ? (json['maxEle'] as num).toInt() : 0;

    if (has3d) {
      double gain = 0;
      double descent = 0;
      double lo = smoothedEle.first;
      double hi = smoothedEle.first;
      for (int i = 1; i < smoothedEle.length; i++) {
        final diff = smoothedEle[i] - smoothedEle[i - 1];
        if (diff > 1.0) {
          gain += diff;
        }
        if (diff < -1.0) {
          descent += diff.abs();
        }
        if (smoothedEle[i] < lo) {
          lo = smoothedEle[i];
        }
        if (smoothedEle[i] > hi) {
          hi = smoothedEle[i];
        }
      }
      coordGain = gain.round();
      elevDescent = descent.round();
      minEleVal = lo.round();
      maxEleVal = hi.round();
    }

    // A stored elevation gain (admin override / catalogue figure) is
    // authoritative so PC Trails edits actually persist; only derive from the
    // coords when the row carries no stored figure. Previously every edit was
    // silently overwritten by the coord-derived value on reload.
    final storedGain = (json['elevationGainM'] is num)
        ? (json['elevationGainM'] as num).toInt()
        : null;
    final int elevGain =
        (storedGain != null && storedGain > 0) ? storedGain : coordGain;
    if (!has3d) {
      elevDescent = elevGain; // best estimate when there's no coord data
    }

    // ── Compute difficulty from objective metrics ─────────────────────────
    // Two independent factors; the harder of the two wins.
    //
    // Grade level  — average gradient (captures steepness)
    //   < 12 %  → Easy
    //   12–20 % → Moderate
    //   20–30 % → Hard
    //   ≥ 30 %  → Extreme
    //
    // Effort level — total work (gain × distance)
    //   gain < 350 m  AND dist < 6 km   → Easy
    //   gain < 800 m  AND dist < 15 km  → Moderate
    //   gain < 1800 m AND dist < 32 km  → Hard
    //   else                             → Extreme
    //
    // Special case: if gain < 50 m the route is essentially flat → Easy.
    final distKm = (json['distanceKm'] is num)
        ? (json['distanceKm'] as num).toDouble()
        : 0.0;
    final estTime = (json['estTimeHours'] is num)
        ? (json['estTimeHours'] as num).toDouble()
        : 0.0;
    // Stored difficulty (admin-set in PC Trails) wins; fall back to deriving
    // it from the metrics only when the row carries no valid label. Without
    // this, difficulty edits never stuck because the value was always
    // recomputed on reload.
    final storedDifficulty = json['difficulty']?.toString();
    final difficulty = (storedDifficulty != null &&
            _kDifficultyLabels.contains(storedDifficulty))
        ? storedDifficulty
        : _computeDifficulty(distKm, elevGain);

    return Trail(
      // id / name are required to render the row at all; we still default
      // rather than throw so a row with a missing key shows up as a
      // recognisable placeholder instead of breaking the surrounding list.
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed trail',
      distanceKm: distKm,
      elevationGainM: elevGain,
      elevationDescentM: elevDescent,
      estTimeHours: estTime,
      difficulty: difficulty,
      minEle: minEleVal,
      maxEle: maxEleVal,
      description: json['description']?.toString() ?? '',
      published: (json['published'] is bool) ? json['published'] as bool : true,
      coords: processedCoords,
      profile: profile,
    );
  }

  // ── Difficulty formula ─────────────────────────────────────────────────

  /// Valid stored difficulty labels (matches the `trails.difficulty` CHECK
  /// constraint). A row carrying one of these is treated as authoritative.
  static const _kDifficultyLabels = {
    'Easy',
    'Moderate',
    'Challenging',
    'Hard',
    'Extreme',
  };

  /// Computes a difficulty label from objective GPS-derived metrics.
  /// Two independent factors are scored and the harder of the two wins,
  /// so a short but brutally steep pass and a long grinding distance hike
  /// are both graded appropriately.
  static String _computeDifficulty(double distKm, int gainM) {
    // Nearly flat → always Easy regardless of distance
    if (gainM < 50) {
      return 'Easy';
    }

    // Average gradient
    final avgGrade = distKm > 0 ? gainM / (distKm * 1000) * 100 : 0.0;

    final int gradeLevel;
    if (avgGrade < 12) {
      gradeLevel = 0; // Easy
    } else if (avgGrade < 20) {
      gradeLevel = 1; // Moderate
    } else if (avgGrade < 30) {
      gradeLevel = 2; // Hard
    } else {
      gradeLevel = 3; // Extreme
    }

    final int effortLevel;
    if (gainM < 350 && distKm < 6) {
      effortLevel = 0; // Easy
    } else if (gainM < 800 && distKm < 15) {
      effortLevel = 1; // Moderate
    } else if (gainM < 1800 && distKm < 32) {
      effortLevel = 2; // Hard
    } else {
      effortLevel = 3; // Extreme
    }

    switch (math.max(gradeLevel, effortLevel)) {
      case 0:
        return 'Easy';
      case 1:
        return 'Moderate';
      case 2:
        return 'Hard';
      default:
        return 'Extreme';
    }
  }

  static double _radJ(double d) => d * math.pi / 180;

  static double _coordDistanceKm(TrailCoord a, TrailCoord b) {
    const r = 6371.0;
    final dLat = _radJ(b.lat - a.lat);
    final dLon = _radJ(b.lon - a.lon);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radJ(a.lat)) *
            math.cos(_radJ(b.lat)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  // ── Path Algorithms ──────────────────────────────────────────────────

  /// Ramer-Douglas-Peucker simplification to reduce point count while
  /// preserving the visual path within [epsilon] metres.
  static List<TrailCoord> _simplifyRDP(
      List<TrailCoord> points, double epsilon) {
    if (points.length <= 2) return points;

    int index = -1;
    double maxDist = 0;

    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDistance(points[i], points.first, points.last);
      if (d > maxDist) {
        index = i;
        maxDist = d;
      }
    }

    if (maxDist > epsilon) {
      final left = _simplifyRDP(points.sublist(0, index + 1), epsilon);
      final right = _simplifyRDP(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points.first, points.last];
    }
  }

  /// Distance from a point to a line segment in metres.
  static double _perpendicularDistance(
      TrailCoord p, TrailCoord a, TrailCoord b) {
    // Convert to approximately local Cartesian for distance math
    final dx = b.lon - a.lon;
    final dy = b.lat - a.lat;

    if (dx == 0 && dy == 0) {
      return _coordDistanceKm(p, a) * 1000.0;
    }

    final t =
        ((p.lon - a.lon) * dx + (p.lat - a.lat) * dy) / (dx * dx + dy * dy);
    final clampedT = t.clamp(0.0, 1.0);

    final nearestLon = a.lon + clampedT * dx;
    final nearestLat = a.lat + clampedT * dy;

    return _coordDistanceKm(
          p,
          TrailCoord(nearestLon, nearestLat, p.elevation),
        ) *
        1000.0;
  }

  /// Chaikin's algorithm for corner smoothing.
  /// Iteratively cuts corners to make the path feel "organic".
  static List<TrailCoord> _chaikinSmooth(
      List<TrailCoord> points, int iterations) {
    if (points.length < 3) return points;

    List<TrailCoord> result = points;
    for (int i = 0; i < iterations; i++) {
      final List<TrailCoord> next = [];
      next.add(result.first);

      for (int j = 0; j < result.length - 1; j++) {
        final p0 = result[j];
        final p1 = result[j + 1];

        // Create two new points at 25% and 75% along the segment
        next.add(TrailCoord(
          p0.lon + (p1.lon - p0.lon) * 0.25,
          p0.lat + (p1.lat - p0.lat) * 0.25,
          p0.elevation + (p1.elevation - p0.elevation) * 0.25,
        ));
        next.add(TrailCoord(
          p0.lon + (p1.lon - p0.lon) * 0.75,
          p0.lat + (p1.lat - p0.lat) * 0.75,
          p0.elevation + (p1.elevation - p0.elevation) * 0.75,
        ));
      }

      next.add(result.last);
      result = next;
    }
    return result;
  }
}
