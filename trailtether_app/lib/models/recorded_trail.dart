enum TrailSharing { private, team, public }

extension TrailSharingX on TrailSharing {
  String get key => switch (this) {
        TrailSharing.private => 'private',
        TrailSharing.team => 'team',
        TrailSharing.public => 'public',
      };

  static TrailSharing parse(String? raw) => switch (raw) {
        'public' => TrailSharing.public,
        'team' => TrailSharing.team,
        _ => TrailSharing.private,
      };

  String get label => switch (this) {
        TrailSharing.private => 'Private',
        TrailSharing.team => 'Team',
        TrailSharing.public => 'Community',
      };
}

/// Metadata-only view of a recorded trail. The track points live in the
/// `recorded-trails` Supabase Storage bucket as a `.gpx` file referenced by
/// [gpxPath]; download via `RecordedTrailService.downloadPoints`.
class RecordedTrail {
  final String id;
  final String hikeId;
  final String userId;
  final String? teamId;
  final String name;
  final String? description;
  final double distanceKm;
  final int ascentM;
  final int descentM;
  final int durationSeconds;
  final String activityType;
  final int pointCount;
  final double? minLat;
  final double? maxLat;
  final double? minLon;
  final double? maxLon;
  final String gpxPath;
  final String? thumbnailPath;
  final TrailSharing sharing;
  final int shareCount;
  final int downloadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ownerDisplayName; // joined from profiles when available

  const RecordedTrail({
    required this.id,
    required this.hikeId,
    required this.userId,
    required this.name,
    required this.distanceKm,
    required this.ascentM,
    required this.descentM,
    required this.durationSeconds,
    required this.activityType,
    required this.pointCount,
    required this.gpxPath,
    required this.sharing,
    required this.shareCount,
    required this.downloadCount,
    required this.createdAt,
    required this.updatedAt,
    this.teamId,
    this.description,
    this.minLat,
    this.maxLat,
    this.minLon,
    this.maxLon,
    this.thumbnailPath,
    this.ownerDisplayName,
  });

  factory RecordedTrail.fromMap(Map<String, dynamic> m) {
    return RecordedTrail(
      id: m['id'] as String,
      hikeId: m['hike_id'] as String,
      userId: m['user_id'] as String,
      teamId: m['team_id'] as String?,
      name: m['name'] as String,
      description: m['description'] as String?,
      distanceKm: (m['distance_km'] as num).toDouble(),
      ascentM: (m['ascent_m'] as num?)?.toInt() ?? 0,
      descentM: (m['descent_m'] as num?)?.toInt() ?? 0,
      durationSeconds: (m['duration_seconds'] as num?)?.toInt() ?? 0,
      activityType: (m['activity_type'] as String?) ?? 'hike',
      pointCount: (m['point_count'] as num?)?.toInt() ?? 0,
      minLat: (m['min_lat'] as num?)?.toDouble(),
      maxLat: (m['max_lat'] as num?)?.toDouble(),
      minLon: (m['min_lon'] as num?)?.toDouble(),
      maxLon: (m['max_lon'] as num?)?.toDouble(),
      gpxPath: m['gpx_path'] as String,
      thumbnailPath: m['thumbnail_path'] as String?,
      sharing: TrailSharingX.parse(m['sharing'] as String?),
      shareCount: (m['share_count'] as num?)?.toInt() ?? 0,
      downloadCount: (m['download_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(m['updated_at'] as String? ?? '') ?? DateTime.now(),
      ownerDisplayName: m['owner_display_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hike_id': hikeId,
        'user_id': userId,
        'team_id': teamId,
        'name': name,
        'description': description,
        'distance_km': distanceKm,
        'ascent_m': ascentM,
        'descent_m': descentM,
        'duration_seconds': durationSeconds,
        'activity_type': activityType,
        'point_count': pointCount,
        'min_lat': minLat,
        'max_lat': maxLat,
        'min_lon': minLon,
        'max_lon': maxLon,
        'gpx_path': gpxPath,
        'thumbnail_path': thumbnailPath,
        'sharing': sharing.key,
        'share_count': shareCount,
        'download_count': downloadCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'owner_display_name': ownerDisplayName,
      };

  RecordedTrail copyWith({
    String? name,
    String? description,
    TrailSharing? sharing,
    int? shareCount,
    int? downloadCount,
  }) =>
      RecordedTrail(
        id: id,
        hikeId: hikeId,
        userId: userId,
        teamId: teamId,
        name: name ?? this.name,
        description: description ?? this.description,
        distanceKm: distanceKm,
        ascentM: ascentM,
        descentM: descentM,
        durationSeconds: durationSeconds,
        activityType: activityType,
        pointCount: pointCount,
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        gpxPath: gpxPath,
        thumbnailPath: thumbnailPath,
        sharing: sharing ?? this.sharing,
        shareCount: shareCount ?? this.shareCount,
        downloadCount: downloadCount ?? this.downloadCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
        ownerDisplayName: ownerDisplayName,
      );
}
