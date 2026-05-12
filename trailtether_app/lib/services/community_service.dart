import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community.dart';
import 'logger_service.dart';

SupabaseClient get _db => Supabase.instance.client;

class CommunityService {
  static Future<List<CommunityActivity>> fetchActivities() async {
    final data = await _db
        .from('community_activities')
        .select()
        .order('timestamp', ascending: false)
        .limit(40);
    return (data as List<dynamic>)
        .map((m) => CommunityActivity.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  static Future<List<TeamLeaderboardStats>> fetchLeaderboard() async {
    try {
      final data = await _db.from('v_community_leaderboard').select().limit(20);
      return (data as List<dynamic>)
          .map((m) => TeamLeaderboardStats(
                teamId: m['team_id'] as String,
                teamName: m['team_name'] as String,
                totalKm: (m['total_km'] as num).toDouble(),
                totalAscent: (m['total_ascent'] as num).toInt(),
                peaksClimbed: m['peaks_climbed'] as int,
                memberCount: m['member_count'] as int,
              ))
          .toList();
    } catch (e, stack) {
      LoggerService.error(
          'COMMUNITY', 'Failed to fetch team leaderboard: $e', stack);
      return [];
    }
  }

  static Future<List<UserLeaderboardStats>> fetchUserLeaderboard() async {
    try {
      final data = await _db.from('v_user_leaderboard').select().limit(25);

      return (data as List<dynamic>).map((m) {
        return UserLeaderboardStats(
          userId: m['user_id'] as String,
          displayName: m['display_name'] as String? ?? 'Hiker',
          photoUrl: m['photo_url'] as String?,
          totalKm: (m['total_km'] as num).toDouble(),
          totalAscent: (m['total_ascent'] as num).toInt(),
          peaksClimbed: (m['peaks_climbed'] as num).toInt(),
        );
      }).toList();
    } catch (e, stack) {
      LoggerService.error(
          'COMMUNITY', 'Failed to fetch user leaderboard: $e', stack);
      return [];
    }
  }
}
