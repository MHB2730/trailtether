import 'package:flutter/foundation.dart';
import '../core/runtime_config.dart';
import '../models/community.dart';
import '../services/community_service.dart';

class CommunityProvider extends ChangeNotifier {
  List<CommunityActivity> _activities = [];
  List<TeamLeaderboardStats> _leaderboard = [];
  List<UserLeaderboardStats> _userLeaderboard = [];
  bool _loading = false;

  List<CommunityActivity> get activities => _activities;
  List<TeamLeaderboardStats> get leaderboard => _leaderboard;
  List<UserLeaderboardStats> get userLeaderboard => _userLeaderboard;
  bool get loading => _loading;

  CommunityProvider() {
    if (kSupabaseAvailable) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (!kSupabaseAvailable) {
      _activities = [];
      _leaderboard = [];
      _userLeaderboard = [];
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      // Use parallel fetching but handle each result individually to prevent total failure
      final results = await Future.wait([
        CommunityService.fetchActivities().catchError((e) {
          debugPrint('CommunityProvider: activities fetch failed — $e');
          return <CommunityActivity>[];
        }),
        CommunityService.fetchLeaderboard().catchError((e) {
          debugPrint('CommunityProvider: leaderboard fetch failed — $e');
          return <TeamLeaderboardStats>[];
        }),
        CommunityService.fetchUserLeaderboard().catchError((e) {
          debugPrint('CommunityProvider: user leaderboard fetch failed — $e');
          return <UserLeaderboardStats>[];
        }),
      ]);

      _activities = results[0] as List<CommunityActivity>;
      _leaderboard = results[1] as List<TeamLeaderboardStats>;
      _userLeaderboard = results[2] as List<UserLeaderboardStats>;
    } catch (e) {
      debugPrint('CommunityProvider: critical refresh error — $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
