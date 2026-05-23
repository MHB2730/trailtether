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
      // Drop only the rows we can't read at all (no team_id); keep every other
      // row with safe defaults so one sparse row from the SQL view doesn't
      // blank the entire leaderboard.
      final out = <TeamLeaderboardStats>[];
      for (final m in (data as List<dynamic>)) {
        if (m is! Map<String, dynamic>) continue;
        final id = m['team_id']?.toString();
        if (id == null || id.isEmpty) continue;
        out.add(TeamLeaderboardStats(
          teamId: id,
          teamName: m['team_name']?.toString() ?? 'Team',
          totalKm: _asDouble(m['total_km']),
          totalAscent: _asInt(m['total_ascent']),
          peaksClimbed: _asInt(m['peaks_climbed']),
          memberCount: _asInt(m['member_count']),
        ));
      }
      return out;
    } catch (e, stack) {
      LoggerService.error(
          'COMMUNITY', 'Failed to fetch team leaderboard: $e', stack);
      return [];
    }
  }

  static Future<List<UserLeaderboardStats>> fetchUserLeaderboard() async {
    try {
      final data = await _db.from('v_user_leaderboard').select().limit(25);

      final out = <UserLeaderboardStats>[];
      for (final m in (data as List<dynamic>)) {
        if (m is! Map<String, dynamic>) continue;
        final id = m['user_id']?.toString();
        if (id == null || id.isEmpty) continue;
        out.add(UserLeaderboardStats(
          userId: id,
          displayName: m['display_name']?.toString() ?? 'Hiker',
          photoUrl: m['photo_url']?.toString(),
          totalKm: _asDouble(m['total_km']),
          totalAscent: _asInt(m['total_ascent']),
          peaksClimbed: _asInt(m['peaks_climbed']),
        ));
      }
      return out;
    } catch (e, stack) {
      LoggerService.error(
          'COMMUNITY', 'Failed to fetch user leaderboard: $e', stack);
      return [];
    }
  }

  // Numeric column reads that survive null, missing, and stringly-typed
  // values. Supabase's PostgREST will hand back ints / doubles for typed
  // columns, but a view's `coalesce(sum(...), 0)` can occasionally show up
  // as a string when the underlying type is `numeric`.
  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
