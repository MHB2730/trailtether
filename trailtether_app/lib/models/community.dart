enum ActivityType { hikeCompleted, teamCreated, achievementUnlocked, checkIn }

class CommunityActivity {
  final String id;
  final ActivityType type;
  final String teamId;
  final String teamName;
  final String userName;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const CommunityActivity({
    required this.id,
    required this.type,
    required this.teamId,
    required this.teamName,
    required this.userName,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.metadata = const {},
  });

  factory CommunityActivity.fromMap(Map<String, dynamic> m) =>
      CommunityActivity(
        id: m['id'] as String? ?? '',
        type: ActivityType.values.firstWhere(
            (e) =>
                e.name == m['type'] ||
                (e.name == 'checkIn' && m['type'] == 'check_in'),
            orElse: () => ActivityType.hikeCompleted),
        teamId: m['team_id'] as String? ?? '',
        teamName: m['team_name'] as String? ?? 'Team',
        userName: m['user_name'] as String? ?? 'Hiker',
        title: m['title'] as String? ?? '',
        subtitle: m['subtitle'] as String? ?? '',
        timestamp: DateTime.parse(
                m['timestamp'] as String? ?? DateTime.now().toIso8601String())
            .toLocal(),
        metadata: m['metadata'] as Map<String, dynamic>? ?? {},
      );
}

class TeamLeaderboardStats {
  final String teamId;
  final String teamName;
  final double totalKm;
  final int totalAscent;
  final int peaksClimbed;
  final int memberCount;

  const TeamLeaderboardStats({
    required this.teamId,
    required this.teamName,
    required this.totalKm,
    required this.totalAscent,
    required this.peaksClimbed,
    required this.memberCount,
  });
}

class UserLeaderboardStats {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final double totalKm;
  final int totalAscent;
  final int peaksClimbed;

  const UserLeaderboardStats({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.totalKm,
    required this.totalAscent,
    required this.peaksClimbed,
  });
}
