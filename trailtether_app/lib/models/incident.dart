import 'package:flutter/material.dart';

// ── Incident type ──────────────────────────────────────────────────────────

enum IncidentType {
  snakeBite,
  wildlifeEncounter,
  riverCrossing,
  securityThreat,
  medicalEmergency,
  stuckOrTrapped,
  lostOrDisoriented,
  weatherEvent,
  trailDamage,
  rockfall,
  waterSource,
  spring,
  pool,
  viewpoint,
  campSite,
  broadcast,
  hazardZone,
  other,
}

extension IncidentTypeX on IncidentType {
  String get key {
    switch (this) {
      case IncidentType.snakeBite:
        return 'snake_bite';
      case IncidentType.wildlifeEncounter:
        return 'wildlife_encounter';
      case IncidentType.riverCrossing:
        return 'river_crossing';
      case IncidentType.securityThreat:
        return 'security_threat';
      case IncidentType.medicalEmergency:
        return 'medical_emergency';
      case IncidentType.stuckOrTrapped:
        return 'stuck_trapped';
      case IncidentType.lostOrDisoriented:
        return 'lost_disoriented';
      case IncidentType.weatherEvent:
        return 'weather_event';
      case IncidentType.trailDamage:
        return 'trail_damage';
      case IncidentType.rockfall:
        return 'rockfall';
      case IncidentType.waterSource:
        return 'water_source';
      case IncidentType.spring:
        return 'spring';
      case IncidentType.pool:
        return 'pool';
      case IncidentType.viewpoint:
        return 'viewpoint';
      case IncidentType.campSite:
        return 'camp_site';
      case IncidentType.broadcast:
        return 'broadcast';
      case IncidentType.hazardZone:
        return 'hazard_zone';
      case IncidentType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case IncidentType.snakeBite:
        return 'Snake / Bite';
      case IncidentType.wildlifeEncounter:
        return 'Wildlife';
      case IncidentType.riverCrossing:
        return 'River Crossing';
      case IncidentType.securityThreat:
        return 'Security Threat';
      case IncidentType.medicalEmergency:
        return 'Medical Emergency';
      case IncidentType.stuckOrTrapped:
        return 'Stuck / Trapped';
      case IncidentType.lostOrDisoriented:
        return 'Lost / Disoriented';
      case IncidentType.weatherEvent:
        return 'Severe Weather';
      case IncidentType.trailDamage:
        return 'Trail Damage';
      case IncidentType.rockfall:
        return 'Rockfall';
      case IncidentType.waterSource:
        return 'Water Source';
      case IncidentType.spring:
        return 'Spring';
      case IncidentType.pool:
        return 'Pool / Swim';
      case IncidentType.viewpoint:
        return 'Viewpoint';
      case IncidentType.campSite:
        return 'Camp Site';
      case IncidentType.broadcast:
        return 'System Broadcast';
      case IncidentType.hazardZone:
        return 'Hazard Zone';
      case IncidentType.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case IncidentType.snakeBite:
        return '🐍';
      case IncidentType.wildlifeEncounter:
        return '🐾';
      case IncidentType.riverCrossing:
        return '🌊';
      case IncidentType.securityThreat:
        return '⚠️';
      case IncidentType.medicalEmergency:
        return '🏥';
      case IncidentType.stuckOrTrapped:
        return '🧗';
      case IncidentType.lostOrDisoriented:
        return '🗺️';
      case IncidentType.weatherEvent:
        return '⛈';
      case IncidentType.trailDamage:
        return '🚧';
      case IncidentType.rockfall:
        return '🪨';
      case IncidentType.waterSource:
        return '🚰';
      case IncidentType.spring:
        return '⛲';
      case IncidentType.pool:
        return '🏊';
      case IncidentType.viewpoint:
        return '📸';
      case IncidentType.campSite:
        return '⛺';
      case IncidentType.broadcast:
        return '📢';
      case IncidentType.hazardZone:
        return '🚫';
      case IncidentType.other:
        return '📍';
    }
  }

  Color get color {
    switch (this) {
      case IncidentType.snakeBite:
        return const Color(0xFFFFB300);
      case IncidentType.wildlifeEncounter:
        return const Color(0xFFFF7043);
      case IncidentType.riverCrossing:
        return const Color(0xFF29B6F6);
      case IncidentType.securityThreat:
        return const Color(0xFFE53935);
      case IncidentType.medicalEmergency:
        return const Color(0xFFE53935);
      case IncidentType.stuckOrTrapped:
        return const Color(0xFFE8541A);
      case IncidentType.lostOrDisoriented:
        return const Color(0xFFE8541A);
      case IncidentType.weatherEvent:
        return const Color(0xFF78909C);
      case IncidentType.trailDamage:
        return const Color(0xFFE8541A);
      case IncidentType.rockfall:
        return const Color(0xFF8D6E63);
      case IncidentType.waterSource:
        return const Color(0xFF4FC3F7);
      case IncidentType.spring:
        return const Color(0xFF4DD0E1);
      case IncidentType.pool:
        return const Color(0xFF4DB6AC);
      case IncidentType.viewpoint:
        return const Color(0xFF9575CD);
      case IncidentType.campSite:
        return const Color(0xFFAED581);
      case IncidentType.broadcast:
        return const Color(0xFFFF5722);
      case IncidentType.hazardZone:
        return Colors.red;
      case IncidentType.other:
        return const Color(0xFFE8DFC8);
    }
  }

  static IncidentType fromKey(String key) {
    return IncidentType.values.firstWhere(
      (t) => t.key == key,
      orElse: () => IncidentType.other,
    );
  }
}

// ── Incident severity ──────────────────────────────────────────────────────

enum IncidentSeverity { low, moderate, serious, critical }

extension IncidentSeverityX on IncidentSeverity {
  String get key {
    switch (this) {
      case IncidentSeverity.low:
        return 'low';
      case IncidentSeverity.moderate:
        return 'moderate';
      case IncidentSeverity.serious:
        return 'serious';
      case IncidentSeverity.critical:
        return 'critical';
    }
  }

  String get label {
    switch (this) {
      case IncidentSeverity.low:
        return 'Low';
      case IncidentSeverity.moderate:
        return 'Moderate';
      case IncidentSeverity.serious:
        return 'Serious';
      case IncidentSeverity.critical:
        return 'Critical';
    }
  }

  Color get color {
    switch (this) {
      case IncidentSeverity.low:
        return const Color(0xFF4CAF50);
      case IncidentSeverity.moderate:
        return const Color(0xFFFFC107);
      case IncidentSeverity.serious:
        return const Color(0xFFE8541A);
      case IncidentSeverity.critical:
        return const Color(0xFFE53935);
    }
  }

  static IncidentSeverity fromKey(String key) {
    return IncidentSeverity.values.firstWhere(
      (s) => s.key == key,
      orElse: () => IncidentSeverity.moderate,
    );
  }
}

// ── Incident model ─────────────────────────────────────────────────────────

class Incident {
  final String id;
  final double lat;
  final double lon;
  final IncidentType type;
  final IncidentSeverity severity;
  final String description;
  final DateTime incidentDate;
  final DateTime reportedAt;
  final String deviceId;
  final String createdBy; // Supabase user id of reporter
  final String? trailId;
  final String? trailName;
  final bool isEmergency;
  final String status; // 'open', 'assigned', 'resolved', 'flagged'
  final String? assignedToUid;
  final String? assignedToName;
  final String? incidentTeamId;
  final int flagCount;
  final List<String> verifiedUids;
  final bool isVerified;
  final int verificationCount;

  const Incident({
    required this.id,
    required this.lat,
    required this.lon,
    required this.type,
    required this.severity,
    required this.description,
    required this.incidentDate,
    required this.reportedAt,
    required this.deviceId,
    this.createdBy = '',
    this.trailId,
    this.trailName,
    this.isEmergency = false,
    this.status = 'open',
    this.assignedToUid,
    this.assignedToName,
    this.incidentTeamId,
    this.flagCount = 0,
    this.verifiedUids = const [],
    this.isVerified = false,
    this.verificationCount = 0,
  });

  /// Parses a row into an Incident. Throws [FormatException] on missing or
  /// out-of-range lat/lon — callers should filter rather than rendering
  /// invalid incidents on the map at (0, 0).
  factory Incident.fromMap(Map<String, dynamic> d) {
    final lat = (d['lat'] as num?)?.toDouble();
    final lon = (d['lon'] as num?)?.toDouble();
    if (lat == null ||
        lon == null ||
        lat.isNaN ||
        lon.isNaN ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      throw FormatException(
          'Incident row missing or invalid coordinates (lat=$lat, lon=$lon)');
    }
    return Incident(
      id: d['id']?.toString() ?? '',
      lat: lat,
      lon: lon,
      type: IncidentTypeX.fromKey(d['type'] as String? ?? 'other'),
      severity:
          IncidentSeverityX.fromKey(d['severity'] as String? ?? 'moderate'),
      description: d['description'] as String? ?? '',
      incidentDate: _parseDate(d['incident_date']),
      reportedAt: _parseDate(d['reported_at']),
      deviceId: d['device_id'] as String? ?? '',
      createdBy: d['created_by'] as String? ?? '',
      trailId: d['trail_id'] as String?,
      trailName: d['trail_name'] as String?,
      isEmergency: d['is_emergency'] as bool? ?? false,
      status: d['status'] as String? ?? 'open',
      assignedToUid: d['assigned_to_uid'] as String?,
      assignedToName: d['assigned_to_name'] as String?,
      incidentTeamId: d['team_id'] as String?,
      flagCount: (d['flag_count'] as num?)?.toInt() ?? 0,
      verifiedUids: (d['verified_uids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isVerified: d['is_verified'] as bool? ?? false,
      verificationCount: (d['verification_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Try-parse variant: returns null on malformed rows. Use in streams where
  /// you want to skip bad data without breaking the whole batch.
  static Incident? tryFromMap(Map<String, dynamic> d) {
    try {
      return Incident.fromMap(d);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toInsertMap() => {
        'lat': lat,
        'lon': lon,
        'type': type.key,
        'severity': severity.key,
        'description': description,
        'incident_date': incidentDate.toIso8601String(),
        'device_id': deviceId,
        'created_by': createdBy.isEmpty ? null : createdBy,
        'is_emergency': isEmergency,
        'status': status,
        if (assignedToUid != null) 'assigned_to_uid': assignedToUid,
        if (assignedToName != null) 'assigned_to_name': assignedToName,
        if (incidentTeamId != null) 'team_id': incidentTeamId,
        if (trailId != null) 'trail_id': trailId,
        if (trailName != null) 'trail_name': trailName,
        'flag_count': flagCount,
        'verified_uids': verifiedUids,
      };

  Map<String, dynamic> toUpdateMap() => {
        'type': type.key,
        'severity': severity.key,
        'description': description,
        'incident_date': incidentDate.toIso8601String(),
        'status': status,
        'assigned_to_uid': assignedToUid,
        'assigned_to_name': assignedToName,
        'team_id': incidentTeamId,
        'flag_count': flagCount,
        'verified_uids': verifiedUids,
      };

  Incident copyWith({
    IncidentType? type,
    IncidentSeverity? severity,
    String? description,
    String? trailName,
    bool? isEmergency,
    String? status,
    String? assignedToUid,
    String? assignedToName,
    int? flagCount,
    List<String>? verifiedUids,
  }) =>
      Incident(
        id: id,
        lat: lat,
        lon: lon,
        type: type ?? this.type,
        severity: severity ?? this.severity,
        description: description ?? this.description,
        incidentDate: incidentDate,
        reportedAt: reportedAt,
        deviceId: deviceId,
        createdBy: createdBy,
        trailId: trailId,
        trailName: trailName ?? this.trailName,
        isEmergency: isEmergency ?? this.isEmergency,
        status: status ?? this.status,
        assignedToUid: assignedToUid ?? this.assignedToUid,
        assignedToName: assignedToName ?? this.assignedToName,
        flagCount: flagCount ?? this.flagCount,
        verifiedUids: verifiedUids ?? this.verifiedUids,
      );

  /// Formatted incident date (e.g. "25 Apr 2026 14:30")
  String get formattedDate {
    final d = incidentDate;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// Age string: "2h ago", "3 days ago", etc.
  String get ageString {
    final diff = DateTime.now().difference(reportedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formattedDate;
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is String) return DateTime.parse(raw).toLocal();
    return DateTime.now();
  }
}
