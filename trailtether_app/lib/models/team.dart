import 'dart:convert';
import 'package:flutter/foundation.dart';

class TeamMember {
  final String uid;
  final String email;
  final String username;
  final String displayName;
  final String photoUrl;

  const TeamMember({
    required this.uid,
    required this.email,
    this.username = '',
    required this.displayName,
    required this.photoUrl,
  });

  factory TeamMember.fromMap(Map<String, dynamic> m) => TeamMember(
        uid: m['uid'] as String? ?? '',
        email: m['email'] as String? ?? '',
        username: m['username'] as String? ?? '',
        displayName: m['displayName'] as String? ??
            m['display_name'] as String? ??
            m['email'] as String? ??
            'Hiker',
        photoUrl: m['photoUrl'] as String? ??
            m['photo_url'] as String? ??
            m['avatar_url'] as String? ??
            '',
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'username': username,
        'displayName': displayName,
        'photoUrl': photoUrl,
      };
}

class Team {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final List<TeamMember> members;
  final List<String> memberUids;
  final DateTime createdAt;
  final String inviteCode;
  final double totalDistanceKm;
  final double totalAscent;
  final int peaksClimbed;
  final int memberCount;

  const Team({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.members,
    required this.memberUids,
    required this.createdAt,
    this.inviteCode = '',
    this.totalDistanceKm = 0.0,
    this.totalAscent = 0.0,
    this.peaksClimbed = 0,
    this.memberCount = 0,
  });

  factory Team.fromMap(Map<String, dynamic> d) {
    final rawMembers = (d['members'] as List<dynamic>? ?? [])
        .map((m) => TeamMember.fromMap(m as Map<String, dynamic>))
        .toList();
    final rawUids = (d['member_uids'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return Team(
      id: d['id'] as String? ?? '',
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      createdBy: d['created_by'] as String? ?? '',
      members: rawMembers,
      memberUids: rawUids,
      createdAt: _parseDate(d['created_at']),
      inviteCode: d['invite_code'] as String? ?? '',
      totalDistanceKm: (d['total_distance_km'] as num? ?? 0.0).toDouble(),
      totalAscent: (d['total_ascent'] as num? ?? 0.0).toDouble(),
      peaksClimbed: (d['peaks_climbed'] as num? ?? 0).toInt(),
      memberCount: (d['member_count'] as num? ?? 0).toInt(),
    );
  }

  bool hasMember(String uid) => memberUids.contains(uid);

  static DateTime _parseDate(dynamic raw) {
    if (raw is String) return DateTime.parse(raw).toLocal();
    return DateTime.now();
  }
}

class GearItem {
  final String id;
  final String name;
  final String
      category; // 'Essential', 'Safety', 'Nutrition', 'Group', 'Clothing'
  final bool isMandatory;
  final Map<String, bool> memberStatuses; // uid -> isPacked

  const GearItem({
    required this.id,
    required this.name,
    this.category = 'Essential',
    this.isMandatory = true,
    this.memberStatuses = const {},
  });

  bool isPackedBy(String uid) => memberStatuses[uid] ?? false;

  factory GearItem.fromMap(Map<String, dynamic> m) {
    // Handle migration from old simple format if needed
    final name = m['name'] as String? ?? '';
    final id = m['id'] as String? ?? name.toLowerCase().replaceAll(' ', '_');

    return GearItem(
      id: id,
      name: name,
      category: m['category'] as String? ?? 'Essential',
      isMandatory: m['isMandatory'] as bool? ?? true,
      memberStatuses: Map<String, bool>.from(m['memberStatuses'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'isMandatory': isMandatory,
        'memberStatuses': memberStatuses,
      };
}

class HikePlanExtras {
  final String userNotes;
  final String time;
  final String gpxId;
  final String weather;
  final DateTime? endDate;
  final List<String> emergencyContacts;
  final List<GearItem> gearList;
  final List<String> invitedMembers;
  final Map<String, String>
      rsvp; // uid -> status ('going', 'not_going', 'maybe')

  const HikePlanExtras({
    this.userNotes = '',
    this.time = '',
    this.gpxId = '',
    this.weather = '',
    this.endDate,
    this.emergencyContacts = const [],
    this.gearList = const [],
    this.invitedMembers = const [],
    this.rsvp = const {},
  });

  factory HikePlanExtras.fromJsonString(String jsonStr) {
    if (jsonStr.isEmpty) return const HikePlanExtras();
    try {
      final Map<String, dynamic> map = json.decode(jsonStr);
      if (!map.containsKey('_is_json_extras')) {
        return HikePlanExtras(userNotes: jsonStr);
      }
      return HikePlanExtras(
        userNotes: map['user_notes'] as String? ?? '',
        time: map['time'] as String? ?? '',
        gpxId: map['gpx_id'] as String? ?? '',
        weather: map['weather'] as String? ?? '',
        endDate:
            map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
        emergencyContacts: (map['emergency_contacts'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        gearList: (map['gear_list'] as List<dynamic>? ?? [])
            .map((e) => GearItem.fromMap(e as Map<String, dynamic>))
            .toList(),
        invitedMembers: (map['invited_members'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        rsvp: Map<String, String>.from(map['rsvp'] as Map? ?? {}),
      );
    } catch (_) {
      return HikePlanExtras(userNotes: jsonStr);
    }
  }

  String toJsonString() {
    return json.encode({
      '_is_json_extras': true,
      'user_notes': userNotes,
      'time': time,
      'gpx_id': gpxId,
      'weather': weather,
      'end_date': endDate?.toIso8601String(),
      'emergency_contacts': emergencyContacts,
      'gear_list': gearList.map((e) => e.toMap()).toList(),
      'invited_members': invitedMembers,
      'rsvp': rsvp,
    });
  }

  HikePlanExtras copyWith({
    String? userNotes,
    String? time,
    String? gpxId,
    String? weather,
    DateTime? endDate,
    List<String>? emergencyContacts,
    List<GearItem>? gearList,
    List<String>? invitedMembers,
    Map<String, String>? rsvp,
  }) {
    return HikePlanExtras(
      userNotes: userNotes ?? this.userNotes,
      time: time ?? this.time,
      gpxId: gpxId ?? this.gpxId,
      weather: weather ?? this.weather,
      endDate: endDate ?? this.endDate,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      gearList: gearList ?? this.gearList,
      invitedMembers: invitedMembers ?? this.invitedMembers,
      rsvp: rsvp ?? this.rsvp,
    );
  }
}

class HikePlan {
  final String id;
  final String teamId;
  final String trailId;
  final String trailName;
  final DateTime hikeDate;
  final String meetingPoint;
  final String notes;
  final String createdBy;
  final DateTime createdAt;
  final String status; // 'planned', 'active', 'completed'

  const HikePlan({
    required this.id,
    required this.teamId,
    required this.trailId,
    required this.trailName,
    required this.hikeDate,
    required this.meetingPoint,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    this.status = 'planned',
  });

  HikePlanExtras get extras => HikePlanExtras.fromJsonString(notes);

  factory HikePlan.fromMap(Map<String, dynamic> d) => HikePlan(
        id: d['id'] as String? ?? '',
        teamId: d['team_id'] as String? ?? '',
        trailId: d['trail_id'] as String? ?? '',
        trailName: d['trail_name'] as String? ?? '',
        hikeDate: _parseDate(d['hike_date']),
        meetingPoint: d['meeting_point'] as String? ?? '',
        notes: d['notes'] as String? ?? '',
        createdBy: d['created_by'] as String? ?? '',
        createdAt: _parseDate(d['created_at']),
        status: d['status'] as String? ?? 'planned',
      );

  Map<String, dynamic> toInsertMap() => {
        'team_id': teamId,
        'trail_id': trailId,
        'trail_name': trailName,
        'hike_date': hikeDate.toIso8601String(),
        'meeting_point': meetingPoint,
        'notes': notes,
        'created_by': createdBy,
        'status': status,
      };

  static DateTime _parseDate(dynamic raw) {
    if (raw is String) return DateTime.parse(raw).toLocal();
    return DateTime.now();
  }
}

class TeamMemberLocation {
  final String uid;
  final String displayName;
  final double lat;
  final double lon;
  final double heading;
  final double speed;
  final double altitude;
  final DateTime timestamp;
  final String? hikeId;
  final String? teamId;
  final String? status; // 'started', 'arrived', 'ok', 'help', 'recording'

  const TeamMemberLocation({
    required this.uid,
    required this.displayName,
    required this.lat,
    required this.lon,
    this.heading = 0,
    this.speed = 0,
    this.altitude = 0,
    required this.timestamp,
    this.hikeId,
    this.teamId,
    this.status,
  });

  factory TeamMemberLocation.fromMap(Map<String, dynamic> m) {
    try {
      return TeamMemberLocation(
        uid: m['uid']?.toString() ?? '',
        displayName: m['display_name']?.toString() ?? 'Hiker',
        lat: (m['lat'] as num?)?.toDouble() ?? 0.0,
        lon: (m['lon'] as num?)?.toDouble() ?? 0.0,
        heading: (m['heading'] as num?)?.toDouble() ?? 0.0,
        speed: (m['speed'] as num?)?.toDouble() ?? 0.0,
        altitude: (m['altitude'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.parse(
                m['timestamp'] as String? ??
                m['updated_at'] as String? ??
                DateTime.now().toIso8601String())
            .toLocal(),
        hikeId: m['hike_id']?.toString(),
        teamId: m['team_id']?.toString(),
        status: m['status']?.toString(),
      );
    } catch (e) {
      debugPrint('TeamMemberLocation.fromMap error: $e');
      return TeamMemberLocation(
        uid: 'error',
        displayName: 'Error',
        lat: 0,
        lon: 0,
        timestamp: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'display_name': displayName,
        'lat': lat,
        'lon': lon,
        'heading': heading,
        'speed': speed,
        'altitude': altitude,
        'timestamp': timestamp.toIso8601String(),
        'hike_id': hikeId,
        'team_id': teamId,
        'status': status,
      };

  /// Seconds since the last position update.
  int get ageSeconds => DateTime.now().difference(timestamp).inSeconds;

  /// Heard from in the last 30s — green dot on the command centre.
  bool get isLive => ageSeconds <= 30;

  /// Heard recently but not live — yellow dot.
  bool get isRecent => ageSeconds > 30 && ageSeconds <= 5 * 60;

  /// Lost signal — red dot.
  bool get isStale => ageSeconds > 5 * 60;
}
