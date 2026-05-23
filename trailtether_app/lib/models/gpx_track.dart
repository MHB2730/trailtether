import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class UserGpxTrack {
  final String id;
  final String filename; // original file name (read-only)
  final String displayName; // user-chosen trail name
  final String authorName; // person who recorded/submits the route
  final String description; // optional trail description
  final String difficulty; // 'Easy' | 'Moderate' | 'Hard' | 'Extreme' | ''
  final List<LatLng> points;
  final List<double> elevations; // parallel to points
  final double distanceKm;
  final int elevationGainM;
  final Color color;
  final bool sharedToCloud;
  final String? cloudPath; // Supabase Storage path if uploaded

  /// Pre-computed bounding box, so map hit-testing doesn't re-sweep points.
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  UserGpxTrack({
    required this.id,
    required this.filename,
    this.displayName = '',
    this.authorName = '',
    this.description = '',
    this.difficulty = '',
    required this.points,
    required this.elevations,
    required this.distanceKm,
    required this.elevationGainM,
    required this.color,
    this.sharedToCloud = false,
    this.cloudPath,
  })  : minLat = points.isEmpty
            ? 0
            : points.fold(
                points.first.latitude, (a, p) => math.min(a, p.latitude)),
        maxLat = points.isEmpty
            ? 0
            : points.fold(
                points.first.latitude, (a, p) => math.max(a, p.latitude)),
        minLon = points.isEmpty
            ? 0
            : points.fold(
                points.first.longitude, (a, p) => math.min(a, p.longitude)),
        maxLon = points.isEmpty
            ? 0
            : points.fold(
                points.first.longitude, (a, p) => math.max(a, p.longitude));

  /// The name shown in the UI — prefers displayName, falls back to filename.
  String get label => displayName.isNotEmpty ? displayName : filename;

  UserGpxTrack copyWith({
    String? id,
    String? displayName,
    String? authorName,
    String? description,
    String? difficulty,
    bool? sharedToCloud,
    String? cloudPath,
  }) =>
      UserGpxTrack(
        id: id ?? this.id,
        filename: filename,
        displayName: displayName ?? this.displayName,
        authorName: authorName ?? this.authorName,
        description: description ?? this.description,
        difficulty: difficulty ?? this.difficulty,
        points: points,
        elevations: elevations,
        distanceKm: distanceKm,
        elevationGainM: elevationGainM,
        color: color,
        sharedToCloud: sharedToCloud ?? this.sharedToCloud,
        cloudPath: cloudPath ?? this.cloudPath,
      );

  // ── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'displayName': displayName,
        'authorName': authorName,
        'description': description,
        'difficulty': difficulty,
        'points': points.map((p) => [p.latitude, p.longitude]).toList(),
        'elevations': elevations,
        'distanceKm': distanceKm,
        'elevationGainM': elevationGainM,
        'color': color.value,
        'sharedToCloud': sharedToCloud,
        if (cloudPath != null) 'cloudPath': cloudPath,
      };

  factory UserGpxTrack.fromJson(Map<String, dynamic> j) {
    // Defensive point + elevation parse. A pair that's not a 2-element list of
    // nums is dropped rather than throwing, so one corrupt waypoint can't
    // crash GPX import / restore for the whole track.
    final rawPts = <LatLng>[];
    final rawPointsList = j['points'];
    if (rawPointsList is List) {
      for (final p in rawPointsList) {
        if (p is! List || p.length < 2) continue;
        final lat = p[0];
        final lon = p[1];
        if (lat is! num || lon is! num) continue;
        rawPts.add(LatLng(lat.toDouble(), lon.toDouble()));
      }
    }

    final rawEle = <double>[];
    final rawEleList = j['elevations'];
    if (rawEleList is List) {
      for (final e in rawEleList) {
        if (e is num) rawEle.add(e.toDouble());
      }
    }

    return UserGpxTrack(
      id: j['id']?.toString() ?? '',
      filename: j['filename']?.toString() ?? 'track.gpx',
      displayName: j['displayName']?.toString() ?? '',
      authorName: j['authorName']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      difficulty: j['difficulty']?.toString() ?? '',
      points: rawPts,
      elevations: rawEle,
      distanceKm: (j['distanceKm'] is num)
          ? (j['distanceKm'] as num).toDouble()
          : 0.0,
      elevationGainM: (j['elevationGainM'] is num)
          ? (j['elevationGainM'] as num).toInt()
          : 0,
      color: Color((j['color'] is int) ? j['color'] as int : 0xFFFF9800),
      sharedToCloud: j['sharedToCloud'] == true,
      cloudPath: j['cloudPath']?.toString(),
    );
  }

  static String encodeList(List<UserGpxTrack> tracks) =>
      jsonEncode(tracks.map((t) => t.toJson()).toList());

  static List<UserGpxTrack> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((m) => UserGpxTrack.fromJson(m as Map<String, dynamic>))
        .toList();
  }
}
