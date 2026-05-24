import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/team.dart';
import '../core/constants.dart';

SupabaseClient get _db => Supabase.instance.client;

class TeamService {
  // Ã¢â€â‚¬Ã¢â€â‚¬ Fetch Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  /// All teams the given [uid] belongs to, newest first.
  static Future<List<Team>> fetchTeamsForUser(String uid) async {
    final data = await _db
        .from(kColTeams)
        .select()
        .filter('member_uids', 'cs', '{$uid}')
        .order('created_at', ascending: false);
    return (data as List<dynamic>)
        .map((m) => Team.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Create / delete Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  static Future<String> createTeam({
    required String name,
    required String description,
    required TeamMember creator,
  }) async {
    final code = _generateInviteCode();
    final row = await _db
        .from(kColTeams)
        .insert({
          'name': name,
          'description': description,
          'created_by': creator.uid,
          'members': [creator.toMap()],
          'member_uids': [creator.uid],
          'invite_code': code,
        })
        .select()
        .single();
    return row['id'] as String;
  }

  static Future<void> deleteTeam(String teamId) =>
      _db.from(kColTeams).delete().eq('id', teamId);

  // Ã¢â€â‚¬Ã¢â€â‚¬ Members Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  /// Add a member to a team. Server-side RPC enforces:
  ///  • only the team creator may add members (other than via invite code)
  ///  • atomic update without TOCTOU
  ///  • idempotent (no duplicate uids)
  static Future<void> addMember(String teamId, TeamMember member) async {
    await _db.rpc('team_add_member', params: {
      'p_team_id': teamId,
      'p_member': member.toMap(),
    });
  }

  /// Remove a member. Server-side RPC enforces:
  ///  • the team creator may remove anyone (except themselves)
  ///  • members may remove only themselves (leave the team)
  static Future<void> removeMember(String teamId, TeamMember member) async {
    await _db.rpc('team_remove_member', params: {
      'p_team_id': teamId,
      'p_member_uid': member.uid,
    });
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Invite code Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  static Future<Team?> getTeamByInviteCode(String code) async {
    final queryCode = _formatInviteCode(code);

    final data = await _db
        .from(kColTeams)
        .select()
        .eq('invite_code', queryCode)
        .limit(1);
    final rows = data as List<dynamic>;
    if (rows.isEmpty) return null;
    return Team.fromMap(rows.first as Map<String, dynamic>);
  }

  static Future<String> joinTeamByCode(String code, TeamMember member) async {
    final currentUserId = _db.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('You must be signed in to join a team.');
    }
    if (member.uid != currentUserId) {
      throw Exception('Invite join user mismatch. Please sign in again.');
    }

    final teamId = await _db.rpc(
      'join_team_by_invite_code',
      params: {
        'p_invite_code': _formatInviteCode(code),
        'p_member': member.toMap(),
      },
    );

    if (teamId == null) {
      throw Exception('Team not found. Check the invite code.');
    }
    return teamId.toString();
  }

  static Future<void> regenerateInviteCode(String teamId) async {
    await _db
        .from(kColTeams)
        .update({'invite_code': _generateInviteCode()}).eq('id', teamId);
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Hike plans Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  static Future<List<HikePlan>> fetchPlansForTeam(String teamId) async {
    final data = await _db
        .from(kColHikePlans)
        .select()
        .eq('team_id', teamId)
        .order('hike_date', ascending: true);
    return (data as List<dynamic>)
        .map((m) => HikePlan.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createPlan(HikePlan plan) async {
    try {
      await _db.from(kColHikePlans).insert(plan.toInsertMap());
    } catch (e) {
      debugPrint('TeamService: createPlan failed - $e');
      throw Exception(
          'Failed to sync hike plan to cloud. Please check your connection.');
    }
  }

  static Future<void> deletePlan(String planId) =>
      _db.from(kColHikePlans).delete().eq('id', planId);

  static Future<void> updatePlan(String planId, HikePlan plan) async {
    await _db.from(kColHikePlans).update({
      'trail_id': plan.trailId,
      'trail_name': plan.trailName,
      'hike_date': plan.hikeDate.toIso8601String(),
      'meeting_point': plan.meetingPoint,
      'notes': plan.notes,
    }).eq('id', planId);
  }

  static Future<void> updateHikeStatus(String planId, String status) async {
    await _db.from(kColHikePlans).update({'status': status}).eq('id', planId);
  }

  // ── Team Tracking ──

  /// Reports current user location to the team tracking table.
  ///
  /// [batteryPct] / [connectivity] are passed straight to the new columns
  /// added in the `add_battery_and_connectivity_to_team_member_locations`
  /// migration. Both stay null when the caller can't read them (e.g.
  /// emulator), so the team-member sheet falls back gracefully.
  static Future<void> reportLocation({
    required String uid,
    required String displayName,
    required double lat,
    required double lon,
    double heading = 0,
    double speed = 0,
    double altitude = 0,
    String? teamId,
    String? hikeId,
    String? status,
    int? batteryPct,
    String? connectivity,
  }) async {
    // Pin the upsert to the `uid` unique constraint. Without this, Supabase
    // upsert falls back to the table's primary key (`id`, auto-generated) and
    // every call becomes an INSERT — that was the original silent leak.
    await _db.from('team_member_locations').upsert({
      'uid': uid,
      'display_name': displayName,
      'lat': lat,
      'lon': lon,
      'heading': heading,
      'speed': speed,
      'altitude': altitude,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'team_id': teamId,
      'hike_id': hikeId,
      'status': status,
      'battery_pct': batteryPct,
      'connectivity': connectivity,
    }, onConflict: 'uid');
  }

  /// Fetches last known locations of all members in a team.
  static Future<List<TeamMemberLocation>> fetchTeamLocations(
      String teamId) async {
    final data =
        await _db.from('team_member_locations').select().eq('team_id', teamId);
    return (data as List<dynamic>)
        .map((m) => TeamMemberLocation.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Append a single GPS fix to the historical track-points log.
  /// `team_member_locations` is upsert-on-uid (latest-only), so it can't
  /// be used to reconstruct the path a hiker walked while offline. The
  /// track-points table is append-only — every fix is preserved with its
  /// original timestamp so the PC can draw a polyline.
  static Future<void> insertTrackPoint({
    required String uid,
    required double lat,
    required double lon,
    String? teamId,
    String? hikeId,
    double? altitude,
    double? heading,
    double? speed,
    String? status,
    int? batteryPct,
    String? connectivity,
    required DateTime timestamp,
    bool syncedOffline = false,
  }) async {
    await _db.from('team_member_track_points').insert({
      'uid': uid,
      'team_id': teamId,
      'hike_id': hikeId,
      'lat': lat,
      'lon': lon,
      'altitude': altitude,
      'heading': heading,
      'speed': speed,
      'status': status,
      'battery_pct': batteryPct,
      'connectivity': connectivity,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'synced_offline': syncedOffline,
    });
  }

  /// Bulk-insert a batch of historical track points, used when draining
  /// the offline queue. Single network round-trip vs N. Each row is
  /// expected to already carry its original `timestamp` + a truthy
  /// `synced_offline` so the PC can render the backfilled segment with
  /// a different colour if it wants to.
  static Future<void> bulkInsertTrackPoints(
      List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _db.from('team_member_track_points').insert(rows);
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Helpers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final part1 =
        List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    final part2 =
        List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    return '$part1-$part2';
  }

  static String _formatInviteCode(String code) {
    final cleaned = code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.length == 8) {
      return '${cleaned.substring(0, 4)}-${cleaned.substring(4)}';
    }
    return cleaned;
  }
}
